import type { ActorContext } from '../../../shared/application/actor-context.js';

export interface IssueMemberInviteCommand {
  readonly actor: ActorContext;
  readonly memberId: string;
  /** Apenas correlação em logs; nunca chave de idempotência (BA-07). */
  readonly requestId: string;
}

/** Credenciais transitórias: saem uma única vez e não são recuperáveis. */
export interface InviteCredentialsView {
  readonly inviteId: string;
  readonly link: string;
  readonly password: string;
}
