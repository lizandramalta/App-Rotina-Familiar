import type { MemberRole } from '../../../shared/domain/member-role.js';

/**
 * Entrada de `SignInWithApple` (SPEC-001 §5.2.1).
 *
 * `familyId` não existe aqui de propósito: a família vem exclusivamente do
 * vínculo persistido à identidade Apple validada (CA-06, RNF06).
 */
export interface SignInWithAppleCommand {
  readonly identityToken: string;
  readonly authorizationCode: string;
  readonly rawNonce: string;
  readonly installationProof: string;
}

/** Sessão do Criador cuja identidade já tem família vinculada (CA-01). */
export interface SessionResult {
  readonly outcome: 'session';
  readonly sessionId: string;
  readonly memberId: string;
  readonly familyId: string;
  readonly role: MemberRole;
  readonly isFamilyCreator: boolean;
  readonly accessToken: string;
  readonly accessTokenExpiresAt: string;
  readonly refreshToken: string;
}

/** Grant restrito para identidade sem família vinculada (CA-02, BA-21). */
export interface CreationGrantResult {
  readonly outcome: 'creationGrant';
  readonly creationGrant: string;
  readonly expiresAt: string;
}

/**
 * O discriminante `outcome` existe para a camada HTTP escolher o corpo da
 * resposta sem inferir pela presença de campos.
 */
export type SignInWithAppleResult = SessionResult | CreationGrantResult;
