import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { isValidMemberRole, type MemberRole } from '../../../shared/domain/member-role.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import { RewardTitleAlreadyExistsError } from '../domain/reward-errors.js';
import type {
  RewardItemRecord,
  RewardRepositoryPort,
} from '../application/reward-repository-port.js';

interface RewardRow {
  id: string;
  title: string;
  details: string | null;
  source: 'predefined' | 'custom';
  created_at: Date;
}

function toRecord(row: RewardRow): RewardItemRecord {
  return {
    id: row.id,
    title: row.title,
    details: row.details,
    source: row.source,
    createdAt: row.created_at,
  };
}

function isUniqueTitleViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    error.code === '23505' &&
    'constraint' in error &&
    error.constraint === 'reward_items_custom_title_unique_idx'
  );
}

export class PostgresRewardRepository implements RewardRepositoryPort {
  public async findActorRole(
    tx: TransactionContext,
    actor: { readonly familyId: string; readonly memberId: string; readonly sessionId: string },
  ): Promise<MemberRole | undefined> {
    const result = await asPostgresClient(tx).query<{ role: string }>(
      `select m.role
         from app.sessions s
         join app.members m on m.family_id = s.family_id and m.id = s.member_id
        where s.id = $1 and s.family_id = $2 and s.member_id = $3
          and s.revoked_at is null`,
      [actor.sessionId, actor.familyId, actor.memberId],
    );
    const role = result.rows[0]?.role;
    return role !== undefined && isValidMemberRole(role) ? role : undefined;
  }

  public async listItems(
    tx: TransactionContext,
    familyId: string,
  ): Promise<readonly RewardItemRecord[]> {
    const result = await asPostgresClient(tx).query<RewardRow>(
      `select id, title, details, source, created_at
         from app.reward_items
        where source = 'predefined'
           or (source = 'custom' and family_id = $1)
        order by case when source = 'predefined' then 0 else 1 end,
                 sort_order nulls last, created_at, id`,
      [familyId],
    );
    return result.rows.map(toRecord);
  }

  public async insertCustom(
    tx: TransactionContext,
    item: {
      readonly id: string;
      readonly familyId: string;
      readonly createdById: string;
      readonly title: string;
      readonly normalizedTitle: string;
      readonly details: string | null;
      readonly createdAt: Date;
    },
  ): Promise<RewardItemRecord> {
    try {
      const result = await asPostgresClient(tx).query<RewardRow>(
        `insert into app.reward_items
          (id, family_id, created_by_id, title, normalized_title, details, source, created_at)
         values ($1, $2, $3, $4, $5, $6, 'custom', $7)
         returning id, title, details, source, created_at`,
        [
          item.id,
          item.familyId,
          item.createdById,
          item.title,
          item.normalizedTitle,
          item.details,
          item.createdAt,
        ],
      );
      const row = result.rows[0];
      if (row === undefined) throw new TypeError('Reward insert returned no row.');
      return toRecord(row);
    } catch (error) {
      if (isUniqueTitleViolation(error)) throw new RewardTitleAlreadyExistsError();
      throw error;
    }
  }
}
