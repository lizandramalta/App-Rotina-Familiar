import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
} from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import { SessionRevokedError } from '../../access/domain/access-errors.js';
import { InviteNotIssuableError } from '../domain/family-errors.js';
import type { MemberInviteCredentialsPort } from './member-invite-credentials-port.js';
import type { InviteCredentialsView, IssueMemberInviteCommand } from './member-invite-dto.js';
import type { MemberInviteRepositoryPort } from './member-invite-repository-port.js';

/** Motivo gravado na sessão revogada pela reemissão (RN47). */
export const INVITE_REISSUED_REVOCATION_REASON = 'INVITE_REISSUED';

const ROUTE = 'POST /v1/family/members/{memberId}/invites';

/**
 * Emite ou reemite o convite de um perfil (SPEC-004 Fase 1, UC02/RN45–47).
 *
 * Cada chamada confirmada cria credenciais novas e, no mesmo commit, invalida os
 * convites disponíveis e revoga a sessão do alvo. Não há idempotência nem
 * recuperação de senha (BA-07, BA-09): se a resposta se perder, o resultado é
 * incerto e uma nova emissão explícita substitui qualquer conjunto anterior.
 */
export class IssueMemberInviteUseCase {
  constructor(
    private readonly deps: {
      readonly repository: MemberInviteRepositoryPort;
      readonly credentials: MemberInviteCredentialsPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(command: IssueMemberInviteCommand): Promise<InviteCredentialsView> {
    const { actor, memberId, requestId } = command;

    try {
      // Papel vindo da sessão: recusa antes de tocar o alvo (CA-03).
      if (actor.role !== MemberRole.ADMINISTRATOR) {
        throw new ActionNotAllowedError();
      }

      // Hash scrypt é custoso: gerado antes do lock para não segurá-lo (BA-08).
      const generated = await this.deps.credentials.generate();

      const result = await this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        const state = await this.deps.repository.findActorState(tx, {
          familyId: actor.familyId,
          memberId: actor.memberId,
          sessionId: actor.sessionId,
        });
        // Sessão revogada ou papel alterado enquanto esperava o lock (RNF07).
        if (state === undefined || !state.sessionActive) {
          throw new SessionRevokedError();
        }
        if (state.role !== MemberRole.ADMINISTRATOR) {
          throw new ActionNotAllowedError();
        }

        const target = await this.deps.repository.findTarget(tx, {
          familyId: actor.familyId,
          memberId,
        });
        if (target === undefined) {
          // Alvo externo é indistinguível de inexistente (RNF06).
          throw new NotFoundError('Family member not found.');
        }
        // O Criador volta por Apple; o próprio ator não revoga a sessão que usa.
        if (target.isFamilyCreator || target.id === actor.memberId) {
          throw new InviteNotIssuableError();
        }

        const now = this.deps.clock.now();
        await this.deps.repository.invalidateAvailableInvites(tx, {
          familyId: actor.familyId,
          memberId,
          at: now,
        });
        await this.deps.repository.revokeActiveSession(tx, {
          familyId: actor.familyId,
          memberId,
          reason: INVITE_REISSUED_REVOCATION_REASON,
        });
        await this.deps.repository.insertInvite(tx, {
          id: generated.inviteId,
          familyId: actor.familyId,
          memberId,
          issuedByMemberId: actor.memberId,
          tokenHash: generated.tokenHash,
          passwordVerifier: generated.passwordVerifier,
          createdAt: now,
        });
        return { at: now };
      });

      // Somente identificadores: nenhum segredo entra no log (SPEC-004 §8).
      this.deps.logger.info('member_invite_issued', {
        familyId: actor.familyId,
        memberId,
        inviteId: generated.inviteId,
        actorId: actor.memberId,
        at: result.at.toISOString(),
      });

      return {
        inviteId: generated.inviteId,
        link: this.deps.credentials.buildLink(generated.token),
        password: generated.password,
      };
    } catch (error) {
      if (error instanceof DomainError) {
        this.deps.logger.warn('member_invite_issue_denied', {
          requestId,
          actorId: actor.memberId,
          route: ROUTE,
          reason: error.code,
        });
        throw error;
      }
      // Falha após o envio pode ter confirmado a escrita: não afirma rollback (CA-07).
      this.deps.logger.error('member_invite_issue_uncertain', undefined, {
        requestId,
        route: ROUTE,
        failure: error instanceof Error ? error.name : 'UnknownFailure',
      });
      throw new DependencyUnavailableError();
    }
  }
}
