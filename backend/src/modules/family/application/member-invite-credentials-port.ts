export interface GeneratedInviteCredentials {
  readonly inviteId: string;
  /** Token opaco que compõe o link; só existe em memória. */
  readonly token: string;
  /** Senha legível para a pessoa convidada; só existe em memória. */
  readonly password: string;
  /** O que o banco recebe no lugar do token. */
  readonly tokenHash: string;
  /** O que o banco recebe no lugar da senha. */
  readonly passwordVerifier: string;
}

/**
 * Geração criptográfica das credenciais de convite (BA-09). Fica na camada de
 * Application para que o caso de uso não dependa de `node:crypto`.
 */
export interface MemberInviteCredentialsPort {
  generate(): Promise<GeneratedInviteCredentials>;

  /** Link entregue ao cliente, montado a partir do token e da base configurada. */
  buildLink(token: string): string;
}
