export interface InspectInviteCommand {
  readonly token: string;
  /** Origem da chamada, só para o limite de tentativas; nunca é persistida em claro. */
  readonly origin: string;
  readonly requestId: string;
}

export interface InspectInviteResult {
  readonly status: 'available';
}

/**
 * Entrada de `POST /access/invite-joins` (SPEC-005 §5.2).
 *
 * `familyId`, `memberId` e papel não existem aqui de propósito: vêm só do
 * convite validado (RNF06, RNF19).
 */
export interface JoinFamilyByInviteCommand {
  readonly token: string;
  readonly password: string;
  readonly attemptId: string;
  readonly attemptSecret: string;
  readonly installationProof: string;
  readonly switchConfirmed: boolean;
  /** Access token da sessão local a substituir, quando houver. */
  readonly previousAccessToken: string | undefined;
  readonly origin: string;
  readonly requestId: string;
}

/** Entrada de `POST /access/invite-joins/recover` (SPEC-005 §5.3). */
export interface RecoverInviteJoinCommand {
  readonly attemptId: string;
  readonly attemptSecret: string;
  readonly installationProof: string;
  readonly origin: string;
  readonly requestId: string;
}
