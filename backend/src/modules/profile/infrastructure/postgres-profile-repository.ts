import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  BadgeAwardRecord,
  BadgeProgress,
  BadgeTier,
  ContributingMissionRecord,
  OwnProfileRecord,
  ProfileRepositoryPort,
} from '../application/profile-repository-port.js';

interface ProfileRow {
  display_name: string;
  family_name: string;
  nickname: string | null;
  photo_media_id: string | null;
}

interface BadgeProgressRow {
  total_participations: number;
  next_tier_code: BadgeTier | null;
  next_tier_required: number | null;
}

interface BadgeAwardRow {
  award_id: string;
  tier: BadgeTier;
  required_mission_count: number;
  awarded_at: Date;
}

interface ContributingMissionRow {
  mission_id: string;
  title: string;
  completed_at: Date | null;
}

function toBadgeAward(row: BadgeAwardRow): BadgeAwardRecord {
  return {
    awardId: row.award_id,
    tier: row.tier,
    requiredMissionCount: row.required_mission_count,
    awardedAt: row.awarded_at,
  };
}

export class PostgresProfileRepository implements ProfileRepositoryPort {
  public async findOwnProfile(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<OwnProfileRecord | undefined> {
    const result = await asPostgresClient(tx).query<ProfileRow>(
      `select m.display_name, f.name as family_name, m.nickname, m.photo_media_id
         from app.members m
         join app.families f on f.id = m.family_id
        where m.family_id = $1 and m.id = $2`,
      [params.familyId, params.memberId],
    );
    const row = result.rows[0];
    return row === undefined
      ? undefined
      : {
          name: row.display_name,
          familyName: row.family_name,
          nickname: row.nickname,
          photoMediaId: row.photo_media_id,
        };
  }

  public async setPhoto(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly photoMediaId: string | null;
      readonly updatedAt: Date;
    },
  ): Promise<void> {
    // O escopo por família e membro vem da sessão; a FK composta de
    // `photo_media_id` impede ainda uma mídia de outra família no banco.
    await asPostgresClient(tx).query(
      `update app.members
          set photo_media_id = $3, updated_at = $4
        where family_id = $1 and id = $2`,
      [params.familyId, params.memberId, params.photoMediaId, params.updatedAt],
    );
  }

  public async setName(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly name: string;
      readonly updatedAt: Date;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.members
          set display_name = $3, updated_at = $4
        where family_id = $1 and id = $2`,
      [params.familyId, params.memberId, params.name, params.updatedAt],
    );
  }

  public async setNickname(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly nickname: string | null;
      readonly updatedAt: Date;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.members
          set nickname = $3, updated_at = $4
        where family_id = $1 and id = $2`,
      [params.familyId, params.memberId, params.nickname, params.updatedAt],
    );
  }

  public async findBadgeProgress(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<BadgeProgress> {
    // `familyId` não participa do filtro de `mission_participations`/`badges`:
    // `member_id` já pertence a uma única família (RNF06); mantido no parâmetro
    // só para a assinatura do port ficar simétrica aos demais métodos.
    const result = await asPostgresClient(tx).query<BadgeProgressRow>(
      `with total as (
         select count(*)::int as total_participations
           from app.mission_participations
          where member_id = $1
       ),
       next_tier as (
         select b.code as next_tier_code, b.min_missions as next_tier_required
           from app.badges b, total t
          where b.min_missions > t.total_participations
          order by b.min_missions
          limit 1
       )
       select t.total_participations, nt.next_tier_code, nt.next_tier_required
         from total t
         left join next_tier nt on true`,
      [params.memberId],
    );
    const row = result.rows[0];
    if (row === undefined) {
      throw new Error('Badge progress aggregation did not return a row.');
    }
    return {
      totalParticipations: row.total_participations,
      nextTier:
        row.next_tier_code === null || row.next_tier_required === null
          ? null
          : { code: row.next_tier_code, requiredMissionCount: row.next_tier_required },
    };
  }

  public async findBadgeAwards(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<readonly BadgeAwardRecord[]> {
    const result = await asPostgresClient(tx).query<BadgeAwardRow>(
      `select mb.id as award_id, mb.badge_code as tier, b.min_missions as required_mission_count,
              mb.awarded_at
         from app.member_badges mb
         join app.badges b on b.code = mb.badge_code
        where mb.family_id = $1 and mb.member_id = $2
        order by b.min_missions`,
      [params.familyId, params.memberId],
    );
    return result.rows.map(toBadgeAward);
  }

  public async findBadgeAward(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string; readonly awardId: string },
  ): Promise<BadgeAwardRecord | undefined> {
    const result = await asPostgresClient(tx).query<BadgeAwardRow>(
      `select mb.id as award_id, mb.badge_code as tier, b.min_missions as required_mission_count,
              mb.awarded_at
         from app.member_badges mb
         join app.badges b on b.code = mb.badge_code
        where mb.family_id = $1 and mb.member_id = $2 and mb.id = $3`,
      [params.familyId, params.memberId, params.awardId],
    );
    const row = result.rows[0];
    return row === undefined ? undefined : toBadgeAward(row);
  }

  public async findContributingMissions(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string; readonly awardId: string },
  ): Promise<readonly ContributingMissionRecord[]> {
    const result = await asPostgresClient(tx).query<ContributingMissionRow>(
      `select m.id as mission_id, m.title, m.completed_at
         from app.badge_participations bp
         join app.missions m on m.family_id = $1 and m.id = bp.mission_id
        where bp.member_badge_id = $2 and bp.member_id = $3
        order by m.completed_at, m.id`,
      [params.familyId, params.awardId, params.memberId],
    );
    return result.rows.map((row) => ({
      missionId: row.mission_id,
      title: row.title,
      completedAt: row.completed_at,
    }));
  }
}
