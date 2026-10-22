import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

export type BadgeTier = 'bronze' | 'silver' | 'gold' | 'diamond';

export interface OwnProfileRecord {
  readonly name: string;
  readonly familyName: string;
  readonly nickname: string | null;
  readonly photoMediaId: string | null;
}

export interface NextTier {
  readonly code: BadgeTier;
  readonly requiredMissionCount: number;
}

export interface BadgeProgress {
  readonly totalParticipations: number;
  /** `null` quando o titular já atingiu `diamond` (RN64). */
  readonly nextTier: NextTier | null;
}

export interface BadgeAwardRecord {
  readonly awardId: string;
  readonly tier: BadgeTier;
  readonly requiredMissionCount: number;
  readonly awardedAt: Date;
}

export interface ContributingMissionRecord {
  readonly missionId: string;
  readonly title: string;
  readonly completedAt: Date | null;
}

export interface ProfileRepositoryPort {
  findOwnProfile(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<OwnProfileRecord | undefined>;

  /** Define (ou, com `null`, remove) a foto do próprio membro. */
  setPhoto(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly photoMediaId: string | null;
      readonly updatedAt: Date;
    },
  ): Promise<void>;

  /** Define o nome de identificação do próprio membro adulto (SPEC-006 E-05, RF02). */
  setName(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly name: string;
      readonly updatedAt: Date;
    },
  ): Promise<void>;

  /** Define (ou, com `null`, remove) o apelido do próprio membro (SPEC-006, RN63). */
  setNickname(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly nickname: string | null;
      readonly updatedAt: Date;
    },
  ): Promise<void>;

  /** Total de participações em missão e o próximo marco cumulativo (RN64). */
  findBadgeProgress(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<BadgeProgress>;

  /** Marcos já concedidos ao titular, do mais antigo para o mais recente. */
  findBadgeAwards(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<readonly BadgeAwardRecord[]>;

  /** Sempre escopado ao titular: marco de outro membro não é encontrado. */
  findBadgeAward(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string; readonly awardId: string },
  ): Promise<BadgeAwardRecord | undefined>;

  findContributingMissions(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string; readonly awardId: string },
  ): Promise<readonly ContributingMissionRecord[]>;
}
