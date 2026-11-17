import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { isValidMemberRole, MemberRole } from '../../../shared/domain/member-role.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type { MemberManagementRepositoryPort } from '../../family/application/member-management-repository-port.js';
import type { AppleTokenTypeHint } from '../../../integrations/apple/apple-token-revocation-port.js';
import type {
  AccountDeletionRepositoryPort,
  CreatorAppleCredentials,
  DeletableMemberRecord,
} from '../application/account-deletion-ports.js';

interface MemberRow {
  readonly id: string;
  readonly role: string;
  readonly is_family_creator: boolean;
}

interface CredentialsRow {
  readonly creator_identity_id: string;
  readonly apple_subject_hash: string;
  readonly apple_refresh_token_encrypted: string | null;
}

/**
 * Ordem de exclusão física das tabelas da família, de filhas para mães (RN70).
 * As FKs do schema são `restrict`/`no action` para proteger o histórico; por
 * isso a família só pode ser apagada nesta ordem explícita. O teste de
 * integração varre `information_schema` e falha se uma tabela nova com
 * `family_id` ficar com linhas da família excluída.
 */
const FAMILY_DELETE_STATEMENTS: readonly string[] = [
  `update app.members set photo_media_id = null where family_id = $1`,
  `delete from app.family_applause_push_outbox o
    using app.family_applause a
    where a.id = o.applause_id and a.family_id = $1`,
  `delete from app.family_applause where family_id = $1`,
  `delete from app.member_badges where family_id = $1`,
  `delete from app.mission_participations where family_id = $1`,
  `delete from app.mission_tasks where family_id = $1`,
  `delete from app.missions where family_id = $1`,
  `delete from app.kids_signals where family_id = $1`,
  `delete from app.completion_credits where family_id = $1`,
  `delete from app.completions where family_id = $1`,
  `delete from app.task_events where family_id = $1`,
  `delete from app.task_assignees where family_id = $1`,
  `delete from app.task_occurrences where family_id = $1`,
  `delete from app.routine_assignees where family_id = $1`,
  `delete from app.routines where family_id = $1`,
  `delete from app.task_templates where family_id = $1`,
  `delete from app.reward_items where family_id = $1`,
  `delete from app.weekly_recognitions where family_id = $1`,
  `delete from app.weekly_highlights where family_id = $1`,
  `delete from app.weekly_highlight_jobs where family_id = $1`,
  `delete from app.weekly_cycles where family_id = $1`,
  `delete from app.family_time_zone_changes where family_id = $1`,
  `delete from app.member_invites where family_id = $1`,
  `delete from app.sessions where family_id = $1`,
  `delete from app.media_assets where family_id = $1`,
  `delete from app.members where family_id = $1`,
  `delete from app.families where id = $1`,
];

/**
 * Persistência da exclusão de conta (SPEC-022, BA-40). Reaproveita os efeitos da
 * remoção de RN10 (`removeMember`) para não duplicar a regra de responsáveis.
 */
export class PostgresAccountDeletionRepository implements AccountDeletionRepositoryPort {
  constructor(
    private readonly memberManagement: Pick<MemberManagementRepositoryPort, 'removeMember'>,
  ) {}

  public async findActiveMember(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<DeletableMemberRecord | undefined> {
    const result = await asPostgresClient(tx).query<MemberRow>(
      `select id, role, is_family_creator from app.members
        where family_id = $1 and id = $2 and removed_at is null and deleted_at is null`,
      [params.familyId, params.memberId],
    );
    const row = result.rows[0];
    if (row === undefined) return undefined;
    return {
      id: row.id,
      role: isValidMemberRole(row.role) ? row.role : MemberRole.MEMBER,
      isFamilyCreator: row.is_family_creator,
    };
  }

  public async findCreatorAppleCredentials(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<CreatorAppleCredentials | undefined> {
    const result = await asPostgresClient(tx).query<CredentialsRow>(
      `select ci.id as creator_identity_id, ci.apple_subject_hash, ci.apple_refresh_token_encrypted
         from app.members m
         join app.creator_identities ci on ci.id = m.creator_identity_id
        where m.family_id = $1 and m.id = $2 and m.is_family_creator
          and m.removed_at is null and m.deleted_at is null`,
      [params.familyId, params.memberId],
    );
    const row = result.rows[0];
    if (row === undefined) return undefined;
    return {
      creatorIdentityId: row.creator_identity_id,
      appleSubjectHash: row.apple_subject_hash,
      refreshTokenEncrypted: row.apple_refresh_token_encrypted ?? undefined,
    };
  }

  public async deleteMemberAccount(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string; readonly now: Date },
  ): Promise<void> {
    const client = asPostgresClient(tx);
    const values = [params.familyId, params.memberId, params.now];

    // O motivo próprio vem antes de `removeMember`, que só altera sessões ainda
    // não revogadas (auditoria distingue remoção de exclusão).
    await client.query(
      `update app.sessions set revoked_at = $3, revoked_reason = 'ACCOUNT_DELETED'
        where family_id = $1 and member_id = $2 and revoked_at is null`,
      values,
    );
    await this.memberManagement.removeMember(tx, params);

    await client.query(
      `insert into app.media_object_deletions (id, object_key, next_attempt_at)
       select gen_random_uuid(), object_key, $3 from app.media_assets
        where family_id = $1 and owner_member_id = $2 and state <> 'DELETED'
       on conflict (object_key) do nothing`,
      values,
    );
    await client.query(
      `update app.media_assets set state = 'DELETING'
        where family_id = $1 and owner_member_id = $2 and state <> 'DELETED'`,
      [params.familyId, params.memberId],
    );
    await client.query(
      `update app.members
          set deleted_at = $3, removed_at = coalesce(removed_at, $3),
              display_name = null, nickname = null, photo_media_id = null, updated_at = $3
        where family_id = $1 and id = $2`,
      values,
    );
  }

  public async deleteFamily(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly creatorIdentityId: string },
  ): Promise<{ readonly memberCount: number }> {
    const client = asPostgresClient(tx);

    const members = await client.query<{ count: string }>(
      `select count(*)::text as count from app.members where family_id = $1`,
      [params.familyId],
    );

    // As chaves entram na fila antes de os registros sumirem: a fila passa a ser
    // a única referência aos objetos privados no R2 (RNF24, RNF28).
    await client.query(
      `insert into app.media_object_deletions (id, object_key)
       select gen_random_uuid(), object_key from app.media_assets
        where family_id = $1 and state <> 'DELETED'
       on conflict (object_key) do nothing`,
      [params.familyId],
    );
    await client.query(
      `insert into app.media_object_deletions (id, object_key)
       select gen_random_uuid(), om.object_key
         from app.onboarding_media om
         join app.family_creation_grants g on g.id = om.grant_id
        where g.creator_identity_id = $1 and om.state <> 'DELETED'
       on conflict (object_key) do nothing`,
      [params.creatorIdentityId],
    );

    for (const statement of FAMILY_DELETE_STATEMENTS) {
      await client.query(statement, [params.familyId]);
    }

    await client.query(
      `delete from app.onboarding_media
        where grant_id in (select id from app.family_creation_grants where creator_identity_id = $1)`,
      [params.creatorIdentityId],
    );
    // `family_creation_grants` cai em cascata com a identidade.
    await client.query(`delete from app.creator_identities where id = $1`, [
      params.creatorIdentityId,
    ]);

    return { memberCount: Number(members.rows[0]?.count ?? 0) };
  }

  public async enqueueAppleTokenRevocation(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly tokenEncrypted: string;
      readonly tokenTypeHint: AppleTokenTypeHint;
      readonly now: Date;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.apple_token_revocations (id, token_encrypted, token_type_hint, next_attempt_at)
       values ($1, $2, $3, $4)`,
      [params.id, params.tokenEncrypted, params.tokenTypeHint, params.now],
    );
  }
}
