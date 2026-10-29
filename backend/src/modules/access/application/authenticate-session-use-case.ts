import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import { AccessTokenInvalidError } from '../domain/access-errors.js';
import type { AccessCryptoPort } from './access-crypto-port.js';
import type { SessionLookupPort } from './session-lookup-port.js';

/**
 * Constrói o `ActorContext` a partir do Bearer. A família e o papel do ator
 * saem exclusivamente da sessão persistida (RNF06).
 */
export class AuthenticateSessionUseCase {
  constructor(
    private readonly deps: {
      readonly sessionLookup: SessionLookupPort;
      readonly crypto: Pick<AccessCryptoPort, 'hashToken'>;
      readonly clock: Clock;
    },
  ) {}

  public async execute(accessToken: string): Promise<ActorContext> {
    if (accessToken.length === 0) {
      throw new AccessTokenInvalidError();
    }

    const actor = await this.deps.sessionLookup.findActorByAccessTokenHash(
      this.deps.crypto.hashToken(accessToken),
      this.deps.clock.now(),
    );

    if (actor === undefined) {
      throw new AccessTokenInvalidError();
    }

    return actor;
  }
}
