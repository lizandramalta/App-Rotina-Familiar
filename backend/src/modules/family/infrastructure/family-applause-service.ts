import { randomUUID } from 'node:crypto';
import type { PostgresConnectionPool } from '../../../shared/infrastructure/postgres/connection-pool.js';
import type { ActorContext } from '../../../shared/application/actor-context.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function dependency<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    throw error instanceof DomainError ? error : new DependencyUnavailableError();
  }
}

export class FamilyApplauseService {
  constructor(private readonly db: PostgresConnectionPool) {}

  async send(actor: ActorContext, recipientMemberId: string, startDate: string, endDate: string) {
    if (actor.role !== MemberRole.ADMINISTRATOR) throw new ActionNotAllowedError();
    if (!UUID.test(recipientMemberId))
      throw new ValidationError('Invalid recipient.', { recipientMemberId: ['INVALID'] });
    if (recipientMemberId === actor.memberId) throw new ActionNotAllowedError();
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(startDate) ||
      !/^\d{4}-\d{2}-\d{2}$/.test(endDate) ||
      startDate > endDate
    ) {
      throw new ValidationError('Invalid range.', { startDate: ['INVALID_RANGE'] });
    }
    const client = await dependency(() => this.db.getClient());
    try {
      await client.query('begin');
      const recipient = await client.query(
        `select 1 from app.members where family_id = $1 and id = $2 and removed_at is null for share`,
        [actor.familyId, recipientMemberId],
      );
      if (recipient.rowCount === 0) throw new NotFoundError('Member not found.');
      const sender = await client.query(
        `select 1 from app.members where family_id = $1 and id = $2 and removed_at is null and role = 'administrator' for share`,
        [actor.familyId, actor.memberId],
      );
      if (sender.rowCount === 0) throw new ActionNotAllowedError();
      const id = randomUUID();
      await client.query(
        `insert into app.family_applause (id, family_id, sender_member_id, recipient_member_id, start_date, end_date)
         values ($1, $2, $3, $4, $5, $6)`,
        [id, actor.familyId, actor.memberId, recipientMemberId, startDate, endDate],
      );
      await client.query(
        `insert into app.family_applause_push_outbox (id, applause_id, push_device_id)
         select gen_random_uuid(), $1, d.id from app.push_devices d
         join app.sessions s on s.id = d.session_id
         where s.family_id = $2 and s.member_id = $3 and s.revoked_at is null and d.revoked_at is null`,
        [id, actor.familyId, recipientMemberId],
      );
      await client.query('commit');
      return { id };
    } catch (error) {
      try {
        await client.query('rollback');
      } catch {
        /* Preserve original failure. */
      }
      throw error instanceof DomainError ? error : new DependencyUnavailableError();
    } finally {
      client.release();
    }
  }

  async received(actor: ActorContext) {
    const result = await dependency(() =>
      this.db.query<{
        id: string;
        sender_names: string[];
        created_at: Date;
      }>(
        `select (array_agg(a.id order by a.created_at desc, a.id desc))[1] as id,
              array_agg(distinct coalesce(m.display_name, 'Membro')) as sender_names,
              max(a.created_at) as created_at
       from app.family_applause a join app.members m on m.id = a.sender_member_id and m.family_id = a.family_id
       where a.family_id = $1 and a.recipient_member_id = $2 and a.dismissed_at is null
       group by a.start_date, a.end_date
       order by created_at desc limit 20`,
        [actor.familyId, actor.memberId],
      ),
    );
    return {
      items: result.rows.map((row) => ({
        id: row.id,
        senderNames: row.sender_names,
        createdAt: row.created_at.toISOString(),
      })),
    };
  }

  async dismiss(actor: ActorContext, id: string) {
    if (!UUID.test(id)) throw new NotFoundError('Message not found.');
    const result = await dependency(() =>
      this.db.query(
        `with selected as (
         select start_date, end_date from app.family_applause
         where id = $1 and family_id = $2 and recipient_member_id = $3
       )
       update app.family_applause a set dismissed_at = coalesce(a.dismissed_at, now())
       from selected s
       where a.family_id = $2 and a.recipient_member_id = $3
         and a.start_date = s.start_date and a.end_date = s.end_date`,
        [id, actor.familyId, actor.memberId],
      ),
    );
    if (result.rowCount === 0) throw new NotFoundError('Message not found.');
  }

  async summary(actor: ActorContext, startDate: string, endDate: string) {
    if (actor.role === MemberRole.KIDS) throw new ActionNotAllowedError();
    const result = await dependency(() =>
      this.db.query<{
        recipient_member_id: string;
        applause_count: string;
        sent_by_me: boolean;
      }>(
        `select recipient_member_id, count(distinct sender_member_id)::text as applause_count,
              bool_or(sender_member_id = $2) as sent_by_me
       from app.family_applause
       where family_id = $1 and start_date = $3::date and end_date = $4::date
       group by recipient_member_id`,
        [actor.familyId, actor.memberId, startDate, endDate],
      ),
    );
    return {
      items: result.rows.map((row) => ({
        memberId: row.recipient_member_id,
        count: Number(row.applause_count),
        sentByMe: row.sent_by_me,
      })),
    };
  }

  async registerDevice(actor: ActorContext, deviceToken: string, environment: string) {
    if (
      !/^[0-9a-f]{64,200}$/i.test(deviceToken) ||
      !['development', 'production'].includes(environment)
    ) {
      throw new ValidationError('Invalid APNs registration.', { deviceToken: ['INVALID'] });
    }
    const client = await dependency(() => this.db.getClient());
    try {
      await client.query('begin');
      await client.query(
        `update app.push_devices set revoked_at = now() where session_id = $1 and revoked_at is null`,
        [actor.sessionId],
      );
      await client.query(
        `insert into app.push_devices (id, session_id, device_token, environment) values ($1, $2, $3, $4)`,
        [randomUUID(), actor.sessionId, deviceToken.toLowerCase(), environment],
      );
      await client.query('commit');
    } catch (error) {
      try {
        await client.query('rollback');
      } catch {
        /* Preserve original failure. */
      }
      throw error instanceof DomainError ? error : new DependencyUnavailableError();
    } finally {
      client.release();
    }
  }
}
