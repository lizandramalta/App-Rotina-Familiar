import type { Configuration } from './configuration.js';
import { ConsoleLogger, type Logger } from '../shared/infrastructure/observability/logger.js';
import { SystemClock, type Clock } from '../shared/application/clock.js';
import { PostgresConnectionPool } from '../shared/infrastructure/postgres/connection-pool.js';
import {
  createAppleConfiguration,
  type AppleConfiguration,
} from '../integrations/apple/apple-configuration.js';
import { AppleJwksClient } from '../integrations/apple/apple-jwks-client.js';
import { AppleTokenVerifier } from '../integrations/apple/apple-token-verifier.js';
import { AppleTokenClient } from '../integrations/apple/apple-token-client.js';
import { PostgresTransactionRunner } from '../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type { TransactionRunner } from '../shared/application/transaction-runner.js';
import { PostgresAccessRepository } from '../modules/access/infrastructure/postgres-access-repository.js';
import { CryptoTokenService } from '../modules/access/infrastructure/crypto-token-service.js';
import { SignInWithAppleUseCase } from '../modules/access/application/sign-in-with-apple-use-case.js';
import { GetCurrentSessionUseCase } from '../modules/access/application/get-current-session-use-case.js';
import { RefreshSessionUseCase } from '../modules/access/application/refresh-session-use-case.js';
import { RevokeSessionUseCase } from '../modules/access/application/revoke-session-use-case.js';
import type { AccessRepositoryPort } from '../modules/access/application/access-repository-port.js';
import { SessionIssuer } from '../modules/access/application/session-issuer.js';
import { AuthenticateSessionUseCase } from '../modules/access/application/authenticate-session-use-case.js';
import { PostgresSessionLookup } from '../modules/access/infrastructure/postgres-session-lookup.js';
import { CreateFamilyUseCase } from '../modules/family/application/create-family-use-case.js';
import { PostgresFamilyCreationRepository } from '../modules/family/infrastructure/postgres-family-creation-repository.js';
import { ChangeFamilyTimeZoneUseCase } from '../modules/family/application/change-family-time-zone-use-case.js';
import { GetFamilySettingsUseCase } from '../modules/family/application/get-family-settings-use-case.js';
import { PreviewFamilyTimeZoneChangeUseCase } from '../modules/family/application/preview-family-time-zone-change-use-case.js';
import { PostgresFamilySettingsRepository } from '../modules/family/infrastructure/postgres-family-settings-repository.js';
import {
  CreateMemberUseCase,
  GetMemberDetailUseCase,
  ListFamilyMembersUseCase,
} from '../modules/family/application/member-management-use-cases.js';
import { IssueMemberInviteUseCase } from '../modules/family/application/issue-member-invite-use-case.js';
import { CryptoInviteCredentials } from '../modules/family/infrastructure/crypto-invite-credentials.js';
import { PostgresMemberInviteRepository } from '../modules/family/infrastructure/postgres-member-invite-repository.js';
import { PostgresMemberManagementRepository } from '../modules/family/infrastructure/postgres-member-management-repository.js';
import { UploadMediaUseCase } from '../modules/media/application/upload-media-use-case.js';
import type { ObjectStoragePort } from '../modules/media/application/media-ports.js';
import { PostgresMediaRepository } from '../modules/media/infrastructure/postgres-media-repository.js';
import { R2ObjectStorage } from '../modules/media/infrastructure/r2-object-storage.js';
import { SharpImageProcessor } from '../modules/media/infrastructure/sharp-image-processor.js';
import { UnavailableObjectStorage } from '../modules/media/infrastructure/unavailable-object-storage.js';
import { UpdateOwnProfileUseCase } from '../modules/profile/application/update-own-profile-use-case.js';
import { PostgresProfileRepository } from '../modules/profile/infrastructure/postgres-profile-repository.js';
import type { AppleTokenVerifierPort } from '../integrations/apple/apple-token-verifier-port.js';
import {
  CreateTaskUseCase,
  DeleteTaskUseCase,
  EditTaskUseCase,
  GetTaskUseCase,
} from '../modules/tasks/application/manage-task-use-cases.js';
import { PostgresTaskRepository } from '../modules/tasks/infrastructure/postgres-task-repository.js';

export interface ApplicationContainer {
  readonly config: Configuration;
  readonly logger: Logger;
  readonly clock: Clock;
  readonly dbPool: PostgresConnectionPool;
  readonly appleConfig: AppleConfiguration;
  readonly appleTokenVerifier: AppleTokenVerifierPort;
  readonly accessRepository: AccessRepositoryPort;
  readonly transactionRunner: TransactionRunner;
  readonly signInWithAppleUseCase: SignInWithAppleUseCase;
  readonly getCurrentSessionUseCase: GetCurrentSessionUseCase;
  readonly refreshSessionUseCase: RefreshSessionUseCase;
  readonly revokeSessionUseCase: RevokeSessionUseCase;
  readonly authenticateSessionUseCase: AuthenticateSessionUseCase;
  readonly createFamilyUseCase: CreateFamilyUseCase;
  readonly getFamilySettingsUseCase: GetFamilySettingsUseCase;
  readonly previewFamilyTimeZoneChangeUseCase: PreviewFamilyTimeZoneChangeUseCase;
  readonly changeFamilyTimeZoneUseCase: ChangeFamilyTimeZoneUseCase;
  readonly listFamilyMembersUseCase: ListFamilyMembersUseCase;
  readonly getMemberDetailUseCase: GetMemberDetailUseCase;
  readonly createMemberUseCase: CreateMemberUseCase;
  readonly issueMemberInviteUseCase: IssueMemberInviteUseCase;
  readonly uploadMediaUseCase: UploadMediaUseCase;
  readonly updateOwnProfileUseCase: UpdateOwnProfileUseCase;
  readonly createTaskUseCase: CreateTaskUseCase;
  readonly getTaskUseCase: GetTaskUseCase;
  readonly editTaskUseCase: EditTaskUseCase;
  readonly deleteTaskUseCase: DeleteTaskUseCase;
  dispose(): Promise<void>;
}

/**
 * Creates and initializes the top-level application dependency graph.
 */
export function createContainer(config: Configuration): ApplicationContainer {
  const logger = new ConsoleLogger(config.LOG_LEVEL, {
    service: 'backend',
    env: config.NODE_ENV,
  });

  const clock = new SystemClock();
  const dbPool = new PostgresConnectionPool(config, logger);
  const appleConfig = createAppleConfiguration(config);
  const transactionRunner = new PostgresTransactionRunner(dbPool);

  const appleTokenVerifier = new AppleTokenVerifier(
    appleConfig,
    new AppleJwksClient(appleConfig, logger),
    new AppleTokenClient(appleConfig, logger),
  );

  const accessRepository = new PostgresAccessRepository();
  // Uma instância só: a chave AES vem de uma derivação scrypt, que é custosa.
  const accessCrypto = new CryptoTokenService(config.SESSION_SECRET);

  const signInWithAppleUseCase = new SignInWithAppleUseCase({
    repository: accessRepository,
    tokenVerifier: appleTokenVerifier,
    crypto: accessCrypto,
    transactionRunner,
    clock,
    logger,
  });

  const getCurrentSessionUseCase = new GetCurrentSessionUseCase({
    repository: accessRepository,
    crypto: accessCrypto,
    transactionRunner,
    clock,
  });

  const refreshSessionUseCase = new RefreshSessionUseCase({
    repository: accessRepository,
    crypto: accessCrypto,
    transactionRunner,
    clock,
  });

  const revokeSessionUseCase = new RevokeSessionUseCase({
    repository: accessRepository,
    crypto: accessCrypto,
    transactionRunner,
    clock,
    logger,
  });

  const authenticateSessionUseCase = new AuthenticateSessionUseCase({
    sessionLookup: new PostgresSessionLookup(dbPool),
    crypto: accessCrypto,
    clock,
  });

  const createFamilyUseCase = new CreateFamilyUseCase({
    repository: new PostgresFamilyCreationRepository(),
    sessionIssuer: new SessionIssuer({
      repository: accessRepository,
      crypto: accessCrypto,
      logger,
    }),
    crypto: accessCrypto,
    transactionRunner,
    clock,
    logger,
  });

  const familySettingsRepository = new PostgresFamilySettingsRepository();

  const getFamilySettingsUseCase = new GetFamilySettingsUseCase({
    repository: familySettingsRepository,
    crypto: accessCrypto,
    transactionRunner,
    clock,
    logger,
  });

  const previewFamilyTimeZoneChangeUseCase = new PreviewFamilyTimeZoneChangeUseCase({
    repository: familySettingsRepository,
    transactionRunner,
    clock,
    logger,
  });

  const changeFamilyTimeZoneUseCase = new ChangeFamilyTimeZoneUseCase({
    repository: familySettingsRepository,
    crypto: accessCrypto,
    transactionRunner,
    clock,
    logger,
  });

  const memberManagementRepository = new PostgresMemberManagementRepository();
  const listFamilyMembersUseCase = new ListFamilyMembersUseCase({
    repository: memberManagementRepository,
    transactionRunner,
  });
  const getMemberDetailUseCase = new GetMemberDetailUseCase({
    repository: memberManagementRepository,
    transactionRunner,
  });
  const createMemberUseCase = new CreateMemberUseCase({
    repository: memberManagementRepository,
    transactionRunner,
    clock,
  });

  const issueMemberInviteUseCase = new IssueMemberInviteUseCase({
    repository: new PostgresMemberInviteRepository(),
    credentials: new CryptoInviteCredentials(config.INVITE_LINK_BASE_URL),
    transactionRunner,
    clock,
    logger,
  });

  // Sem R2 configurado o upload responde 503; a criação da família não depende
  // dele, já que a foto é opcional (SPEC-002 CA-10).
  const mediaRepository = new PostgresMediaRepository();
  const objectStorage = createObjectStorage(config, logger);

  const uploadMediaUseCase = new UploadMediaUseCase({
    repository: mediaRepository,
    storage: objectStorage,
    imageProcessor: new SharpImageProcessor(),
    crypto: accessCrypto,
    transactionRunner,
    logger,
    keyPrefix: config.NODE_ENV,
  });

  const updateOwnProfileUseCase = new UpdateOwnProfileUseCase({
    profileRepository: new PostgresProfileRepository(),
    mediaRepository,
    transactionRunner,
    clock,
  });

  const taskRepository = new PostgresTaskRepository();
  const taskDependencies = { repository: taskRepository, transactionRunner, clock };
  const createTaskUseCase = new CreateTaskUseCase(taskDependencies);
  const getTaskUseCase = new GetTaskUseCase({ repository: taskRepository, transactionRunner });
  const editTaskUseCase = new EditTaskUseCase(taskDependencies);
  const deleteTaskUseCase = new DeleteTaskUseCase(taskDependencies);

  return {
    config,
    logger,
    clock,
    dbPool,
    appleConfig,
    appleTokenVerifier,
    accessRepository,
    transactionRunner,
    signInWithAppleUseCase,
    getCurrentSessionUseCase,
    refreshSessionUseCase,
    revokeSessionUseCase,
    authenticateSessionUseCase,
    createFamilyUseCase,
    getFamilySettingsUseCase,
    previewFamilyTimeZoneChangeUseCase,
    changeFamilyTimeZoneUseCase,
    listFamilyMembersUseCase,
    getMemberDetailUseCase,
    createMemberUseCase,
    issueMemberInviteUseCase,
    uploadMediaUseCase,
    updateOwnProfileUseCase,
    createTaskUseCase,
    getTaskUseCase,
    editTaskUseCase,
    deleteTaskUseCase,
    async dispose(): Promise<void> {
      logger.info('Disposing application container...');
      await dbPool.close();
      logger.info('Application container disposed.');
    },
  };
}

function createObjectStorage(config: Configuration, logger: Logger): ObjectStoragePort {
  const { R2_ENDPOINT, R2_BUCKET_NAME, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY } = config;

  if (
    R2_ENDPOINT === undefined ||
    R2_BUCKET_NAME === undefined ||
    R2_ACCESS_KEY_ID === undefined ||
    R2_SECRET_ACCESS_KEY === undefined
  ) {
    logger.warn('r2_not_configured', { effect: 'media uploads respond 503' });
    return new UnavailableObjectStorage();
  }

  return new R2ObjectStorage({
    endpoint: R2_ENDPOINT,
    bucketName: R2_BUCKET_NAME,
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
  });
}
