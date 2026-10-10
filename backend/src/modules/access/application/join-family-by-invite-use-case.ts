import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { DependencyUnavailableError, DomainError } from '../../../shared/domain/domain-error.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import {
  AccessSwitchConfirmationRequiredError,
  InvitePasswordInvalidError,
  InviteUnavailableError,
  JoinResultUncertainError,
  PreviousSessionInvalidError,
  RateLimitedError,
} from '../domain/invite-errors.js';
import type { AccessCryptoPort } from './access-crypto-port.js';
import type { AccessRepositoryPort } from './access-repository-port.js';
import type { InviteAttemptLimiterPort } from './invite-attempt-limiter-port.js';
import type { InviteAttemptPolicy } from './invite-attempt-policy.js';
import type { InviteJoinEnvelopePort } from './invite-join-envelope-port.js';
import type { JoinFamilyByInviteCommand } from './invite-join-dto.js';
import type { InviteJoinRepositoryPort } from './invite-join-repository-port.js';
import type { InvitePasswordVerifierPort } from './invite-password-verifier-port.js';
import type { IssuedSession, SessionIssuer } from './session-issuer.js';

/** Janela de recuperação de ingresso: dez minutos desde o commit (BA-11). */
export const JOIN_RECOVERY_WINDOW_MS = 10 * 60 * 1000;

/** Motivo gravado nas sessões encerradas pelo ingresso (RN47). */
export const ACCESS_SWITCHED_REVOCATION_REASON = 'ACCESS_SWITCHED';
export const INVITE_JOIN_REPLACED_REASON = 'INVITE_JOIN_REPLACED';

const ROUTE = 'POST /v1/access/invite-joins';

/**
 * `JoinFamilyByInvite` (UC09, SPEC-005 Fase 1).
 *
 * Família, perfil e papel derivam exclusivamente do convite. A senha é
 * conferida antes do lock (o scrypt é custoso, BA-28) e tudo o que importa é
 * revalidado dentro da transação serializada: o commit consome o convite, abre
 * a sessão, guarda o envelope de recuperação e, em troca confirmada, encerra a
 * sessão anterior.
 */
export class JoinFamilyByInviteUseCase {
  constructor(
    private readonly deps: {
      readonly repository: InviteJoinRepositoryPort;
      readonly accessRepository: AccessRepositoryPort;
      readonly sessionIssuer: SessionIssuer;
      readonly authenticate: { execute(accessToken: string): Promise<ActorContext> };
      readonly passwordVerifier: InvitePasswordVerifierPort;
      readonly envelope: InviteJoinEnvelopePort;
      readonly limiter: InviteAttemptLimiterPort;
      readonly crypto: Pick<AccessCryptoPort, 'hashToken'>;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
      readonly policy: InviteAttemptPolicy;
    },
  ) {}

  public async execute(command: JoinFamilyByInviteCommand): Promise<IssuedSession> {
    // Antes do commit, uma falha não deixa dúvida (503 comum); depois dele, o
    // resultado é incerto e o app precisa usar a recuperação (CA-07).
    let commitStarted = false;

    try {
      const { policy } = this.deps;
      const now = this.deps.clock.now();

      const originExceeded = await this.deps.limiter.recordAndCheckExceeded({
        scope: 'origin',
        subjectHash: this.deps.crypto.hashToken(`origin:${command.origin}`),
        limit: policy.originLimit,
        now,
        windowMs: policy.windowMs,
      });
      if (originExceeded) {
        throw new RateLimitedError(Math.ceil(policy.windowMs / 1000));
      }

      const previous = await this.authenticatePreviousSession(command.previousAccessToken);

      const tokenHash = this.deps.crypto.hashToken(command.token);
      const invite = await this.deps.transactionRunner.run((tx) =>
        this.deps.repository.findInviteByTokenHash(tx, tokenHash),
      );
      if (invite === undefined || invite.status !== 'available') {
        throw new InviteUnavailableError();
      }

      // Sessão anterior válida exige confirmação explícita; sem sessão anterior
      // o campo não produz troca (SPEC-005 §5.2).
      if (previous !== undefined && !command.switchConfirmed) {
        throw new AccessSwitchConfirmationRequiredError();
      }

      const inviteExceeded = await this.deps.limiter.recordAndCheckExceeded({
        scope: 'invite',
        subjectHash: this.deps.crypto.hashToken(`invite:${tokenHash}`),
        limit: policy.inviteLimit,
        now,
        windowMs: policy.windowMs,
      });
      if (inviteExceeded) {
        throw new RateLimitedError(Math.ceil(policy.windowMs / 1000));
      }

      const passwordMatches = await this.deps.passwordVerifier.verify(
        command.password,
        invite.passwordVerifier,
      );
      if (!passwordMatches) {
        throw new InvitePasswordInvalidError();
      }

      const attemptSecretHash = this.deps.crypto.hashToken(command.attemptSecret);
      const installationProofHash = this.deps.crypto.hashToken(command.installationProof);

      commitStarted = true;
      const session = await this.deps.transactionRunner.forFamily(invite.familyId, async (tx) => {
        const locked = await this.deps.repository.lockInviteForJoin(tx, invite.inviteId);
        // Estado revalidado depois de esperar o lock: a segunda tentativa
        // concorrente chega aqui com o convite já consumido (CA-05).
        if (
          locked === undefined ||
          locked.status !== 'available' ||
          locked.isFamilyCreator ||
          locked.familyId !== invite.familyId
        ) {
          throw new InviteUnavailableError();
        }

        if (previous !== undefined) {
          const revoked = await this.deps.accessRepository.revokeSessionById(tx, {
            sessionId: previous.sessionId,
            reason: ACCESS_SWITCHED_REVOCATION_REASON,
          });
          if (!revoked) {
            throw new PreviousSessionInvalidError();
          }
          await this.deps.accessRepository.revokeAccessTokensForSession(tx, previous.sessionId);
          await this.deps.accessRepository.revokePushDevicesForSession(tx, previous.sessionId);
        }

        const consumed = await this.deps.repository.markInviteConsumed(tx, {
          inviteId: locked.inviteId,
          at: now,
        });
        if (!consumed) {
          throw new InviteUnavailableError();
        }

        const issued = await this.deps.sessionIssuer.issue(tx, {
          familyId: locked.familyId,
          memberId: locked.memberId,
          role: locked.role,
          isFamilyCreator: locked.isFamilyCreator,
          installationProofHash,
          now,
          replacedReason: INVITE_JOIN_REPLACED_REASON,
        });

        // Aproveita o commit do ingresso para varrer envelopes vencidos, já que
        // não há job de limpeza próprio nesta fase (BA-32).
        await this.deps.repository.purgeExpiredJoinRecoveries(tx, now);

        const stored = await this.deps.repository.insertJoinRecovery(tx, {
          attemptId: command.attemptId,
          inviteId: locked.inviteId,
          sessionId: issued.sessionId,
          attemptSecretHash,
          installationProofHash,
          envelope: this.deps.envelope.seal(command.attemptId, issued),
          createdAt: now,
          expiresAt: new Date(now.getTime() + JOIN_RECOVERY_WINDOW_MS),
        });
        // Um `attemptId` reaproveitado nunca sobrescreve a recuperação de outro
        // ingresso; a transação inteira é desfeita.
        if (!stored) {
          throw new InviteUnavailableError();
        }

        return issued;
      });

      this.deps.logger.info('invite_join_confirmed', {
        requestId: command.requestId,
        sessionId: session.sessionId,
        memberId: session.memberId,
        familyId: session.familyId,
        role: session.role,
        at: now.toISOString(),
      });

      return session;
    } catch (error) {
      if (error instanceof DomainError) {
        this.deps.logger.warn('invite_join_denied', {
          requestId: command.requestId,
          route: ROUTE,
          code: error.code,
          at: this.deps.clock.now().toISOString(),
        });
        throw error;
      }

      this.deps.logger.error('invite_join_uncertain', undefined, {
        requestId: command.requestId,
        route: ROUTE,
        commitStarted,
        failure: error instanceof Error ? error.name : 'UnknownFailure',
      });
      throw commitStarted ? new JoinResultUncertainError() : new DependencyUnavailableError();
    }
  }

  private async authenticatePreviousSession(
    accessToken: string | undefined,
  ): Promise<ActorContext | undefined> {
    if (accessToken === undefined) {
      return undefined;
    }

    try {
      return await this.deps.authenticate.execute(accessToken);
    } catch (error) {
      if (error instanceof DomainError) {
        throw new PreviousSessionInvalidError();
      }
      throw error;
    }
  }
}
