import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  DependencyUnavailableError,
  DomainError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import { isValidMemberRole, MemberRole } from '../../../shared/domain/member-role.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { AccessCryptoPort } from '../../access/application/access-crypto-port.js';
import type { SessionIssuer } from '../../access/application/session-issuer.js';
import type { OnboardingMediaPort } from '../../media/application/onboarding-media-port.js';
import { CreationGrantInvalidError } from '../domain/family-errors.js';
import { normalizeName, normalizeNickname } from '../domain/text-rules.js';
import { DEFAULT_TIME_ZONE_ID, isValidTimeZoneId } from '../domain/time-zone.js';
import { buildInitialWeeklyCycle } from '../domain/weekly-cycle.js';
import type { CreateFamilyCommand, CreateFamilyResult } from './create-family-dto.js';
import type { FamilyCreationRepositoryPort } from './family-creation-repository-port.js';

interface ValidatedInput {
  readonly creatorName: string;
  readonly creatorNickname: string | null;
  readonly familyName: string;
  readonly timeZoneId: string;
  readonly initialMembers: readonly { name: string; role: MemberRole }[];
  readonly creatorPhotoMediaId: string | undefined;
}

/**
 * `CreateFamily` (UC01, SPEC-002 Fase 1).
 *
 * Consome o `creationGrant` e cria, numa única transação, a família, o Criador
 * Administrador, membros iniciais, ciclo, foto opcional e sessão (CA-01/CA-10).
 */
export class CreateFamilyUseCase {
  constructor(
    private readonly deps: {
      readonly repository: FamilyCreationRepositoryPort;
      readonly onboardingMedia: OnboardingMediaPort;
      readonly sessionIssuer: SessionIssuer;
      readonly crypto: Pick<AccessCryptoPort, 'newId' | 'hashToken'>;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(command: CreateFamilyCommand): Promise<CreateFamilyResult> {
    try {
      const input = this.validate(command);
      return await this.createFamily(command, input);
    } catch (error) {
      if (error instanceof DomainError) {
        // Só o código técnico: grant, nomes e tokens nunca entram no log (RNF08).
        this.deps.logger.warn('family_creation_rejected', { reason: error.code });
        throw error;
      }

      // Falha de banco ou de conexão: o commit pode ou não ter acontecido, então
      // a resposta não afirma reversão (CA-09, RNF12).
      this.deps.logger.error('family_creation_failed', error);
      throw new DependencyUnavailableError();
    }
  }

  private validate(command: CreateFamilyCommand): ValidatedInput {
    const fieldErrors: Record<string, string[]> = {};

    const creatorName = normalizeName(command.creatorName);
    if ('problem' in creatorName) {
      fieldErrors['creatorName'] = [`MEMBER_NAME_${creatorName.problem}`];
    }

    const creatorNickname = normalizeNickname(command.creatorNickname);
    if ('problem' in creatorNickname) {
      fieldErrors['creatorNickname'] = [`NICKNAME_${creatorNickname.problem}`];
    }

    const familyName = normalizeName(command.name);
    if ('problem' in familyName) {
      fieldErrors['name'] = [`FAMILY_NAME_${familyName.problem}`];
    }

    // Ausente ou `null` usa o padrão; qualquer outro valor precisa ser IANA.
    const timeZoneId =
      command.timeZoneId === undefined || command.timeZoneId === null
        ? DEFAULT_TIME_ZONE_ID
        : command.timeZoneId;
    if (typeof timeZoneId !== 'string' || !isValidTimeZoneId(timeZoneId)) {
      fieldErrors['timeZoneId'] = ['TIME_ZONE_ID_INVALID'];
    }

    const initialMembers: { name: string; role: MemberRole }[] = [];
    if (command.initialMembers !== undefined) {
      if (!Array.isArray(command.initialMembers)) {
        fieldErrors['initialMembers'] = ['INITIAL_MEMBERS_INVALID'];
      } else {
        for (const [index, item] of command.initialMembers.entries()) {
          if (typeof item !== 'object' || item === null || Array.isArray(item)) {
            fieldErrors[`initialMembers[${index}]`] = ['INITIAL_MEMBER_INVALID'];
            continue;
          }
          const member = item as Record<string, unknown>;
          for (const key of Object.keys(member)) {
            if (key !== 'name' && key !== 'role') {
              throw new DomainError({
                message: 'The request contains an unknown field.',
                code: 'UNKNOWN_FIELD',
                statusCode: 400,
                fieldErrors: { [`initialMembers[${index}].${key}`]: ['UNKNOWN_FIELD'] },
              });
            }
          }
          const name = normalizeName(member['name']);
          if ('problem' in name)
            fieldErrors[`initialMembers[${index}].name`] = [`MEMBER_NAME_${name.problem}`];
          const role = member['role'];
          if (typeof role !== 'string' || !isValidMemberRole(role)) {
            fieldErrors[`initialMembers[${index}].role`] = ['MEMBER_ROLE_INVALID'];
          }
          if (!('problem' in name) && typeof role === 'string' && isValidMemberRole(role)) {
            initialMembers.push({ name: name.value, role });
          }
        }
      }
    }

    const creatorPhotoMediaId = command.creatorPhotoMediaId;
    if (
      creatorPhotoMediaId !== undefined &&
      (typeof creatorPhotoMediaId !== 'string' ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          creatorPhotoMediaId,
        ))
    ) {
      fieldErrors['creatorPhotoMediaId'] = ['PHOTO_MEDIA_NOT_READY'];
    }

    if (
      'problem' in creatorName ||
      'problem' in creatorNickname ||
      'problem' in familyName ||
      typeof timeZoneId !== 'string' ||
      Object.keys(fieldErrors).length > 0
    ) {
      throw new ValidationError('The request contains invalid values.', fieldErrors);
    }

    return {
      creatorName: creatorName.value,
      creatorNickname: creatorNickname.value,
      familyName: familyName.value,
      timeZoneId,
      initialMembers,
      creatorPhotoMediaId:
        typeof creatorPhotoMediaId === 'string' ? creatorPhotoMediaId : undefined,
    };
  }

  private async createFamily(
    command: CreateFamilyCommand,
    input: ValidatedInput,
  ): Promise<CreateFamilyResult> {
    if (typeof command.creationGrant !== 'string' || command.creationGrant.length === 0) {
      throw new CreationGrantInvalidError();
    }

    const { crypto, repository } = this.deps;
    const grantTokenHash = crypto.hashToken(command.creationGrant);
    const installationProofHash = crypto.hashToken(command.installationProof);
    const now = this.deps.clock.now();

    const result = await this.deps.transactionRunner.run(async (tx) => {
      const grant = await repository.findCreationGrantByTokenHash(tx, grantTokenHash);
      if (grant === undefined) {
        throw new CreationGrantInvalidError();
      }

      // O grant está preso ao aparelho do login. Conferir antes de consumir evita
      // que quem o roubou o queime para o dono legítimo.
      if (grant.installationProofHash !== installationProofHash) {
        throw new CreationGrantInvalidError();
      }

      await repository.lockCreatorIdentity(tx, grant.creatorIdentityId);

      // Revalidado depois do lock: uma criação concorrente da mesma identidade já
      // pode ter consumido o grant ou criado o vínculo (CA-03).
      if (!(await repository.consumeCreationGrant(tx, { grantId: grant.id, now }))) {
        throw new CreationGrantInvalidError();
      }

      if (await repository.hasFamilyMembership(tx, grant.creatorIdentityId)) {
        throw new CreationGrantInvalidError();
      }

      let photo;
      if (input.creatorPhotoMediaId !== undefined) {
        photo = await this.deps.onboardingMedia.findForGrant(
          tx,
          input.creatorPhotoMediaId,
          grant.id,
        );
        if (photo === undefined) {
          const anyPhoto = await this.deps.onboardingMedia.findById(tx, input.creatorPhotoMediaId);
          throw new ValidationError('The photo is unavailable for this onboarding.', {
            creatorPhotoMediaId: [
              anyPhoto === undefined ? 'PHOTO_MEDIA_NOT_READY' : 'PHOTO_MEDIA_NOT_OWNED',
            ],
          });
        }
        if (photo.purpose !== 'PROFILE_PHOTO') {
          throw new ValidationError('The photo purpose is invalid.', {
            creatorPhotoMediaId: ['PHOTO_MEDIA_PURPOSE_MISMATCH'],
          });
        }
        if (photo.state !== 'READY') {
          throw new ValidationError('The photo is not ready.', {
            creatorPhotoMediaId: ['PHOTO_MEDIA_NOT_READY'],
          });
        }
        if (photo.sizeBytes === null || photo.contentType !== 'image/jpeg') {
          throw new ValidationError('The photo is not ready.', {
            creatorPhotoMediaId: ['PHOTO_MEDIA_NOT_READY'],
          });
        }
      }

      await repository.revokeOpenCreationGrants(tx, {
        creatorIdentityId: grant.creatorIdentityId,
        now,
      });

      const familyId = crypto.newId();
      const memberId = crypto.newId();
      const cycle = buildInitialWeeklyCycle(now, input.timeZoneId);

      await repository.insertFamily(tx, {
        familyId,
        name: input.familyName,
        timeZoneId: input.timeZoneId,
        createdAt: now,
      });

      await repository.insertCreatorMember(tx, {
        memberId,
        familyId,
        creatorIdentityId: grant.creatorIdentityId,
        name: input.creatorName,
        nickname: input.creatorNickname,
        createdAt: now,
      });

      const initialMembers = [];
      for (const initial of input.initialMembers) {
        const id = crypto.newId();
        await repository.insertInitialMember(tx, {
          id,
          familyId,
          name: initial.name,
          role: initial.role,
          createdAt: now,
        });
        initialMembers.push({ id, name: initial.name, role: initial.role });
      }

      await repository.insertWeeklyCycle(tx, {
        cycleId: crypto.newId(),
        familyId,
        startsAt: cycle.startsAt,
        endsAt: cycle.endsAt,
        timeZoneId: cycle.timeZoneId,
        referenceWeek: cycle.referenceWeek,
      });

      if (photo !== undefined) {
        await this.deps.onboardingMedia.transferToCreator(tx, {
          media: photo,
          familyId,
          memberId,
          now,
        });
      }

      const session = await this.deps.sessionIssuer.issue(tx, {
        familyId,
        memberId,
        role: MemberRole.ADMINISTRATOR,
        isFamilyCreator: true,
        installationProofHash,
        now,
      });

      return { familyId, memberId, initialMembers, session };
    });

    this.deps.logger.info('family_created', {
      familyId: result.familyId,
      timeZoneId: input.timeZoneId,
    });

    return {
      family: {
        id: result.familyId,
        name: input.familyName,
        timeZoneId: input.timeZoneId,
        createdAt: now.toISOString(),
      },
      member: {
        id: result.memberId,
        name: input.creatorName,
        nickname: input.creatorNickname,
        role: MemberRole.ADMINISTRATOR,
        isFamilyCreator: true,
      },
      initialMembers: result.initialMembers,
      session: result.session,
    };
  }
}
