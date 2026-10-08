import type { ActorContext } from '../../../shared/application/actor-context.js';
import { isValidMemberRole } from '../../../shared/domain/member-role.js';
import type { PostgresConnectionPool } from '../../../shared/infrastructure/postgres/connection-pool.js';
import type { SessionLookupPort } from '../application/session-lookup-port.js';

interface ActorRow {
  session_id: string;
  family_id: string;
  member_id: string;
  role: string;
  is_family_creator: boolean;
}

export class PostgresSessionLookup implements SessionLookupPort {
  constructor(private readonly pool: PostgresConnectionPool) {}

  public async findActorByAccessTokenHash(
    accessTokenHash: string,
    now: Date,
  ): Promise<ActorContext | undefined> {
    // Token, sessão e membro são conferidos juntos: sessão revogada ou token
    // vencido nunca resolvem um ator.
    const result = await this.pool.query<ActorRow>(
      `select s.id as session_id, s.family_id, s.member_id, m.role, m.is_family_creator
         from app.session_access_tokens t
         join app.sessions s on s.id = t.session_id
         join app.members m on m.family_id = s.family_id and m.id = s.member_id
        where t.token_hash = $1
          and t.revoked_at is null
          and t.expires_at > $2
          and s.revoked_at is null`,
      [accessTokenHash, now],
    );

    const row = result.rows[0];
    if (row === undefined || !isValidMemberRole(row.role)) {
      return undefined;
    }

    return {
      sessionId: row.session_id,
      familyId: row.family_id,
      memberId: row.member_id,
      role: row.role,
      isFamilyCreator: row.is_family_creator,
    };
  }
}
