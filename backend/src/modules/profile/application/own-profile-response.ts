import type { BadgeProgress } from './profile-repository-port.js';

export interface NextTierResponse {
  readonly code: string;
  readonly requiredMissionCount: number;
  readonly remaining: number;
}

export interface OwnProfileResponse {
  readonly memberId: string;
  readonly name: string;
  readonly nickname: string | null;
  readonly photoMediaId: string | null;
  readonly totalParticipations: number;
  readonly nextTier: NextTierResponse | null;
}

/** `null` quando o titular já atingiu `diamond`; senão quantas faltam (RN64). */
export function toNextTierResponse(progress: BadgeProgress): NextTierResponse | null {
  if (progress.nextTier === null) {
    return null;
  }
  return {
    code: progress.nextTier.code,
    requiredMissionCount: progress.nextTier.requiredMissionCount,
    remaining: progress.nextTier.requiredMissionCount - progress.totalParticipations,
  };
}

export function toOwnProfileResponse(params: {
  readonly memberId: string;
  readonly name: string;
  readonly nickname: string | null;
  readonly photoMediaId: string | null;
  readonly progress: BadgeProgress;
}): OwnProfileResponse {
  return {
    memberId: params.memberId,
    name: params.name,
    nickname: params.nickname,
    photoMediaId: params.photoMediaId,
    totalParticipations: params.progress.totalParticipations,
    nextTier: toNextTierResponse(params.progress),
  };
}
