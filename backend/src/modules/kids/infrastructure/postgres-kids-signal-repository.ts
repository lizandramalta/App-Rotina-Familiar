import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  KidsSignalRecord,
  KidsSignalRepositoryPort,
} from '../application/kids-signal-repository-port.js';

interface SignalRow {
  id: string;
  family_id: string;
  task_id: string;
  task_title: string;
  signaled_by_id: string;
  child_name: string;
  created_at: Date;
  photo_media_id: string | null;
  discarded_at: Date | null;
  decision: KidsSignalRecord['decision'];
  assignees: { id: string; name: string }[];
}

function record(row: SignalRow): KidsSignalRecord {
  return {
    id: row.id,
    familyId: row.family_id,
    taskId: row.task_id,
    taskTitle: row.task_title,
    signaledById: row.signaled_by_id,
    childName: row.child_name,
    signaledAt: row.created_at,
    photoMediaId: row.photo_media_id,
    discardedAt: row.discarded_at,
    decision: row.decision,
    assignees: row.assignees,
  };
}

const signalSelect = `select signal.id, signal.family_id, signal.task_id,
       task.title as task_title, signal.signaled_by_id,
       case when child.removed_at is null then coalesce(child.display_name, '') else 'Membro removido' end as child_name, signal.created_at,
       signal.photo_media_id, signal.discarded_at, signal.decision,
       coalesce((select jsonb_agg(jsonb_build_object('id', member.id, 'name', case when member.removed_at is null then coalesce(member.display_name, '') else 'Membro removido' end) order by member.created_at, member.id)
                   from app.task_assignees assignee
                   join app.members member on member.family_id = assignee.family_id and member.id = assignee.member_id
                  where assignee.family_id = signal.family_id and assignee.task_id = signal.task_id), '[]'::jsonb) as assignees
  from app.kids_signals signal
  join app.task_occurrences task on task.family_id = signal.family_id and task.id = signal.task_id
  join app.members child on child.family_id = signal.family_id and child.id = signal.signaled_by_id`;

export class PostgresKidsSignalRepository implements KidsSignalRepositoryPort {
  async findPhoto(tx: TransactionContext, familyId: string, mediaId: string) {
    const result = await asPostgresClient(tx).query<{
      owner_member_id: string;
      purpose: string;
      state: string;
    }>(
      `select owner_member_id, purpose, state from app.media_assets where family_id = $1 and id = $2`,
      [familyId, mediaId],
    );
    const row = result.rows[0];
    return row && { ownerMemberId: row.owner_member_id, purpose: row.purpose, state: row.state };
  }

  async findSignal(tx: TransactionContext, familyId: string, signalId: string) {
    const result = await asPostgresClient(tx).query<SignalRow>(
      `${signalSelect} where signal.family_id = $1 and signal.id = $2`,
      [familyId, signalId],
    );
    return result.rows[0] && record(result.rows[0]);
  }

  async listCurrent(
    tx: TransactionContext,
    params: { familyId: string; after?: { signaledAt: Date; signalId: string }; limit: number },
  ) {
    const result = await asPostgresClient(tx).query<SignalRow>(
      `${signalSelect}
        where signal.family_id = $1 and signal.discarded_at is null
          and task.status = 'awaitingConfirmation' and task.deleted_at is null
          and ($2::timestamptz is null or (signal.created_at, signal.id) > ($2, $3::uuid))
        order by signal.created_at, signal.id limit $4`,
      [
        params.familyId,
        params.after?.signaledAt ?? null,
        params.after?.signalId ?? null,
        params.limit,
      ],
    );
    return result.rows.map(record);
  }

  async createSignal(
    tx: TransactionContext,
    params: {
      id: string;
      familyId: string;
      taskId: string;
      signaledById: string;
      photoMediaId: string | null;
      now: Date;
    },
  ) {
    const client = asPostgresClient(tx);
    await client.query(
      `insert into app.kids_signals (id, family_id, task_id, signaled_by_id, photo_media_id, created_at)
       values ($1, $2, $3, $4, $5, $6)`,
      [
        params.id,
        params.familyId,
        params.taskId,
        params.signaledById,
        params.photoMediaId,
        params.now,
      ],
    );
    if (params.photoMediaId) {
      await client.query(
        `update app.media_assets set linked_at = coalesce(linked_at, $3)
          where family_id = $1 and id = $2`,
        [params.familyId, params.photoMediaId, params.now],
      );
    }
  }

  async setTaskAwaiting(tx: TransactionContext, familyId: string, taskId: string, now: Date) {
    await asPostgresClient(tx).query(
      `update app.task_occurrences set status = 'awaitingConfirmation', updated_at = $3
        where family_id = $1 and id = $2 and status = 'pending'`,
      [familyId, taskId, now],
    );
  }

  async rejectSignal(
    tx: TransactionContext,
    params: { signalId: string; familyId: string; taskId: string; actorId: string; now: Date },
  ) {
    const client = asPostgresClient(tx);
    await client.query(
      `update app.task_occurrences set status = 'pending', updated_at = $3
        where family_id = $1 and id = $2 and status = 'awaitingConfirmation'`,
      [params.familyId, params.taskId, params.now],
    );
    await client.query(
      `update app.kids_signals set discarded_at = $3, decision = 'rejected', decided_by_id = $4, decided_at = $3
        where family_id = $1 and id = $2 and discarded_at is null`,
      [params.familyId, params.signalId, params.now, params.actorId],
    );
  }

  async resolveSignal(
    tx: TransactionContext,
    params: {
      signalId: string;
      familyId: string;
      actorId: string;
      outcome: 'confirmed' | 'closedByManualCompletion';
      now: Date;
    },
  ) {
    await asPostgresClient(tx).query(
      `update app.kids_signals set discarded_at = $3, decision = $4, decided_by_id = $5, decided_at = $3
        where family_id = $1 and id = $2 and discarded_at is null`,
      [params.familyId, params.signalId, params.now, params.outcome, params.actorId],
    );
  }
}
