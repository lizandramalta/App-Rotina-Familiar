import type { MemberRole } from '../../../shared/domain/member-role.js';

/**
 * Entrada de `CreateFamily` (SPEC-002 §5.2).
 *
 * Todos os campos chegam como `unknown`: a validação semântica (e o código de
 * campo correspondente) é do caso de uso, não do schema HTTP — o contrato exige
 * `422 VALIDATION_FAILED` com `fieldErrors`, e não o `400` do schema.
 * `familyId`, papel e flag de Criador não existem aqui de propósito (RNF06).
 */
export interface CreateFamilyCommand {
  readonly creationGrant: unknown;
  readonly creatorName: unknown;
  readonly creatorNickname: unknown;
  readonly name: unknown;
  readonly timeZoneId: unknown;
  readonly installationProof: string;
}

export interface CreateFamilyResult {
  readonly family: {
    readonly id: string;
    readonly name: string;
    readonly timeZoneId: string;
    readonly createdAt: string;
  };
  readonly member: {
    readonly id: string;
    readonly name: string;
    readonly nickname: string | null;
    readonly role: MemberRole;
    readonly isFamilyCreator: boolean;
  };
  readonly session: {
    readonly sessionId: string;
    readonly memberId: string;
    readonly familyId: string;
    readonly role: MemberRole;
    readonly isFamilyCreator: boolean;
    readonly accessToken: string;
    readonly accessTokenExpiresAt: string;
    readonly refreshToken: string;
  };
}
