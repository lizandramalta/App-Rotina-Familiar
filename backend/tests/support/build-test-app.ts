import { vi } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { validateConfiguration } from '../../src/bootstrap/configuration.js';
import type { ApplicationContainer } from '../../src/bootstrap/container.js';
import { createAppleConfiguration } from '../../src/integrations/apple/apple-configuration.js';
import { buildHttpApp } from '../../src/presentation/http/app.js';
import { SystemClock } from '../../src/shared/application/clock.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import { ConsoleLogger } from '../../src/shared/infrastructure/observability/logger.js';

type UseCaseMock = { execute: ReturnType<typeof vi.fn> };

export interface TestApp {
  readonly app: FastifyInstance;
  readonly createFamily: UseCaseMock;
  readonly getFamilySettings: UseCaseMock;
  readonly previewTimeZoneChange: UseCaseMock;
  readonly changeTimeZone: UseCaseMock;
  readonly uploadMedia: UseCaseMock;
  readonly updateOwnProfile: UseCaseMock;
  readonly authenticateSession: UseCaseMock;
  readonly createTask: UseCaseMock;
  readonly getTask: UseCaseMock;
  readonly editTask: UseCaseMock;
  readonly deleteTask: UseCaseMock;
}

export const TEST_ACTOR: ActorContext = {
  sessionId: '6f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e',
  familyId: '11112222-3333-4444-5555-666677778888',
  memberId: 'a1b2c3d4-e5f6-4890-abcd-ef1234567890',
  role: 'administrator',
  isFamilyCreator: true,
};

/**
 * Monta o app HTTP real com os casos de uso substituídos por dublês: o que está
 * sob teste é o contrato de transporte (schema, status, corpo, autenticação).
 */
export function buildTestApp(): TestApp {
  const config = validateConfiguration({
    NODE_ENV: 'test',
    DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres_test',
    LOG_LEVEL: 'fatal',
  });

  const createFamily: UseCaseMock = { execute: vi.fn() };
  const getFamilySettings: UseCaseMock = { execute: vi.fn() };
  const previewTimeZoneChange: UseCaseMock = { execute: vi.fn() };
  const changeTimeZone: UseCaseMock = { execute: vi.fn() };
  const uploadMedia: UseCaseMock = { execute: vi.fn() };
  const updateOwnProfile: UseCaseMock = { execute: vi.fn() };
  const authenticateSession: UseCaseMock = { execute: vi.fn().mockResolvedValue(TEST_ACTOR) };
  const createTask: UseCaseMock = { execute: vi.fn() };
  const getTask: UseCaseMock = { execute: vi.fn() };
  const editTask: UseCaseMock = { execute: vi.fn() };
  const deleteTask: UseCaseMock = { execute: vi.fn() };

  const container = {
    config,
    logger: new ConsoleLogger('fatal'),
    clock: new SystemClock(),
    dbPool: { checkHealth: vi.fn() },
    appleConfig: createAppleConfiguration(config),
    signInWithAppleUseCase: { execute: vi.fn() },
    authenticateSessionUseCase: authenticateSession,
    createFamilyUseCase: createFamily,
    getFamilySettingsUseCase: getFamilySettings,
    previewFamilyTimeZoneChangeUseCase: previewTimeZoneChange,
    changeFamilyTimeZoneUseCase: changeTimeZone,
    uploadMediaUseCase: uploadMedia,
    updateOwnProfileUseCase: updateOwnProfile,
    createTaskUseCase: createTask,
    getTaskUseCase: getTask,
    editTaskUseCase: editTask,
    deleteTaskUseCase: deleteTask,
    dispose: vi.fn(),
  } as unknown as ApplicationContainer;

  return {
    app: buildHttpApp(container, config),
    createFamily,
    getFamilySettings,
    previewTimeZoneChange,
    changeTimeZone,
    uploadMedia,
    updateOwnProfile,
    authenticateSession,
    createTask,
    getTask,
    editTask,
    deleteTask,
  };
}
