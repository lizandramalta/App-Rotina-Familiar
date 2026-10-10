import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import type { AccessCryptoPort } from './access-crypto-port.js';
import type { AccessRepositoryPort } from './access-repository-port.js';
import { assertSessionIsActive } from './active-session.js';
import type { AccessTokenCommand, CurrentSessionResult } from './session-dto.js';

/**
 * `GetCurrentSession` (CA-07, SPEC-001 §5.2.2).
 *
 * Lê sempre o estado atual do servidor — perfil, família, papel e
 * `isFamilyCreator` — e devolve apenas a projeção: nenhum token, hash ou
 * segredo sai daqui.
 */
export class GetCurrentSessionUseCase {
  constructor(
    private readonly deps: {
      readonly repository: AccessRepositoryPort;
      readonly crypto: AccessCryptoPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  public async execute(command: AccessTokenCommand): Promise<CurrentSessionResult> {
    const tokenHash = this.deps.crypto.hashToken(command.accessToken);
    const now = this.deps.clock.now();

    const record = await this.deps.transactionRunner.run((tx) =>
      this.deps.repository.findSessionAndMemberByAccessTokenHash(tx, tokenHash),
    );

    const session = assertSessionIsActive(record, now);

    return {
      memberId: session.memberId,
      familyId: session.familyId,
      role: session.role,
      isFamilyCreator: session.isFamilyCreator,
    };
  }
}
