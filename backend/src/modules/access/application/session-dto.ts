import type { MemberRole } from '../../../shared/domain/member-role.js';

/** Entrada das rotas autenticadas por Bearer (`/me/session`). */
export interface AccessTokenCommand {
  readonly accessToken: string;
}

/**
 * Projeção de `GET /me/session` (CA-07, SPEC-001 §5.2.2).
 *
 * Nenhum token, hash ou segredo entra aqui: o tipo é o próprio contrato de não
 * vazamento, e o schema de resposta da rota repete a restrição.
 */
export interface CurrentSessionResult {
  readonly memberId: string;
  readonly familyId: string;
  readonly role: MemberRole;
  readonly isFamilyCreator: boolean;
}

/**
 * Entrada de `POST /access/refresh` (CA-08, SPEC-001 §5.2.3). A prova de
 * instalação é obrigatória: sem ela o refresh token sozinho abriria sessão em
 * qualquer instalação.
 */
export interface RefreshSessionCommand {
  readonly refreshToken: string;
  readonly installationProof: string;
}

/** Novo access token de 15 minutos; o refresh token não é reemitido (BA-10). */
export interface RefreshedAccessResult {
  readonly accessToken: string;
  readonly accessTokenExpiresAt: string;
}
