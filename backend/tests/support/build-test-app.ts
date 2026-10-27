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
  readonly getFamily: UseCaseMock;
  readonly updateFamily: UseCaseMock;
  readonly getFamilySettings: UseCaseMock;
  readonly previewTimeZoneChange: UseCaseMock;
  readonly changeTimeZone: UseCaseMock;
  readonly listFamilyMembers: UseCaseMock;
  readonly getMemberDetail: UseCaseMock;
  readonly createMember: UseCaseMock;
  readonly issueMemberInvite: UseCaseMock;
  readonly uploadMedia: UseCaseMock;
  readonly uploadOnboardingMedia: UseCaseMock;
  readonly updateOwnProfile: UseCaseMock;
  readonly getOwnProfile: UseCaseMock;
  readonly getMediaContent: UseCaseMock;
  readonly getOwnBadges: UseCaseMock;
  readonly getBadgeContributions: UseCaseMock;
  readonly authenticateSession: UseCaseMock;
  readonly inspectInvite: UseCaseMock;
  readonly joinFamilyByInvite: UseCaseMock;
  readonly recoverInviteJoin: UseCaseMock;
  readonly createTask: UseCaseMock;
  readonly completeTask: UseCaseMock;
  readonly reopenTask: UseCaseMock;
  readonly getTask: UseCaseMock;
  readonly getOwnTasks: UseCaseMock;
  readonly getOwnProgress: UseCaseMock;
  readonly editTask: UseCaseMock;
  readonly deleteTask: UseCaseMock;
  readonly createRoutine: UseCaseMock;
  readonly getRoutine: UseCaseMock;
  readonly updateFutureRoutine: UseCaseMock;
  readonly deleteFutureRoutineTasks: UseCaseMock;
  readonly createMission: UseCaseMock;
  readonly editMission: UseCaseMock;
  readonly listMissions: UseCaseMock;
  readonly getMissionDetail: UseCaseMock;
  readonly getMissionTaskOptions: UseCaseMock;
  readonly listRewardItems: UseCaseMock;
  readonly addRewardItem: UseCaseMock;
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
  const getFamily: UseCaseMock = { execute: vi.fn() };
  const updateFamily: UseCaseMock = { execute: vi.fn() };
  const getFamilySettings: UseCaseMock = { execute: vi.fn() };
  const previewTimeZoneChange: UseCaseMock = { execute: vi.fn() };
  const changeTimeZone: UseCaseMock = { execute: vi.fn() };
  const listFamilyMembers: UseCaseMock = { execute: vi.fn() };
  const getMemberDetail: UseCaseMock = { execute: vi.fn() };
  const createMember: UseCaseMock = { execute: vi.fn() };
  const issueMemberInvite: UseCaseMock = { execute: vi.fn() };
  const uploadMedia: UseCaseMock = { execute: vi.fn() };
  const uploadOnboardingMedia: UseCaseMock = { execute: vi.fn() };
  const updateOwnProfile: UseCaseMock = { execute: vi.fn() };
  const getOwnProfile: UseCaseMock = { execute: vi.fn() };
  const getMediaContent: UseCaseMock = { execute: vi.fn() };
  const getOwnBadges: UseCaseMock = { execute: vi.fn() };
  const getBadgeContributions: UseCaseMock = { execute: vi.fn() };
  const authenticateSession: UseCaseMock = { execute: vi.fn().mockResolvedValue(TEST_ACTOR) };
  const inspectInvite: UseCaseMock = { execute: vi.fn() };
  const joinFamilyByInvite: UseCaseMock = { execute: vi.fn() };
  const recoverInviteJoin: UseCaseMock = { execute: vi.fn() };
  const createTask: UseCaseMock = { execute: vi.fn() };
  const completeTask: UseCaseMock = { execute: vi.fn() };
  const reopenTask: UseCaseMock = { execute: vi.fn() };
  const getTask: UseCaseMock = { execute: vi.fn() };
  const getOwnTasks: UseCaseMock = { execute: vi.fn() };
  const getOwnProgress: UseCaseMock = { execute: vi.fn() };
  const editTask: UseCaseMock = { execute: vi.fn() };
  const deleteTask: UseCaseMock = { execute: vi.fn() };
  const createRoutine: UseCaseMock = { execute: vi.fn() };
  const getRoutine: UseCaseMock = { execute: vi.fn() };
  const updateFutureRoutine: UseCaseMock = { execute: vi.fn() };
  const deleteFutureRoutineTasks: UseCaseMock = { execute: vi.fn() };
  const createMission: UseCaseMock = { execute: vi.fn() };
  const editMission: UseCaseMock = { execute: vi.fn() };
  const listMissions: UseCaseMock = { execute: vi.fn() };
  const getMissionDetail: UseCaseMock = { execute: vi.fn() };
  const getMissionTaskOptions: UseCaseMock = { execute: vi.fn() };
  const listRewardItems: UseCaseMock = { execute: vi.fn() };
  const addRewardItem: UseCaseMock = { execute: vi.fn() };

  const container = {
    config,
    logger: new ConsoleLogger('fatal'),
    clock: new SystemClock(),
    dbPool: { checkHealth: vi.fn() },
    appleConfig: createAppleConfiguration(config),
    signInWithAppleUseCase: { execute: vi.fn() },
    authenticateSessionUseCase: authenticateSession,
    inspectInviteUseCase: inspectInvite,
    joinFamilyByInviteUseCase: joinFamilyByInvite,
    recoverInviteJoinUseCase: recoverInviteJoin,
    createFamilyUseCase: createFamily,
    getFamilyUseCase: getFamily,
    updateFamilyUseCase: updateFamily,
    getFamilySettingsUseCase: getFamilySettings,
    previewFamilyTimeZoneChangeUseCase: previewTimeZoneChange,
    changeFamilyTimeZoneUseCase: changeTimeZone,
    listFamilyMembersUseCase: listFamilyMembers,
    getMemberDetailUseCase: getMemberDetail,
    createMemberUseCase: createMember,
    issueMemberInviteUseCase: issueMemberInvite,
    uploadMediaUseCase: uploadMedia,
    uploadOnboardingMediaUseCase: uploadOnboardingMedia,
    updateOwnProfileUseCase: updateOwnProfile,
    getOwnProfileUseCase: getOwnProfile,
    getMediaContentUseCase: getMediaContent,
    getOwnBadgesUseCase: getOwnBadges,
    getBadgeContributionsUseCase: getBadgeContributions,
    createTaskUseCase: createTask,
    completeTaskUseCase: completeTask,
    reopenTaskUseCase: reopenTask,
    getTaskUseCase: getTask,
    getOwnTasksUseCase: getOwnTasks,
    getOwnProgressUseCase: getOwnProgress,
    editTaskUseCase: editTask,
    deleteTaskUseCase: deleteTask,
    createRoutineUseCase: createRoutine,
    getRoutineUseCase: getRoutine,
    updateFutureRoutineUseCase: updateFutureRoutine,
    deleteFutureRoutineTasksUseCase: deleteFutureRoutineTasks,
    createMissionUseCase: createMission,
    editMissionUseCase: editMission,
    listMissionsUseCase: listMissions,
    getMissionDetailUseCase: getMissionDetail,
    getMissionTaskOptionsUseCase: getMissionTaskOptions,
    listRewardItemsUseCase: listRewardItems,
    addRewardItemUseCase: addRewardItem,
    dispose: vi.fn(),
  } as unknown as ApplicationContainer;

  return {
    app: buildHttpApp(container, config),
    createFamily,
    getFamily,
    updateFamily,
    getFamilySettings,
    previewTimeZoneChange,
    changeTimeZone,
    listFamilyMembers,
    getMemberDetail,
    createMember,
    issueMemberInvite,
    uploadMedia,
    uploadOnboardingMedia,
    updateOwnProfile,
    getOwnProfile,
    getMediaContent,
    getOwnBadges,
    getBadgeContributions,
    authenticateSession,
    inspectInvite,
    joinFamilyByInvite,
    recoverInviteJoin,
    createTask,
    completeTask,
    reopenTask,
    getTask,
    getOwnTasks,
    getOwnProgress,
    editTask,
    deleteTask,
    createRoutine,
    getRoutine,
    updateFutureRoutine,
    deleteFutureRoutineTasks,
    createMission,
    editMission,
    listMissions,
    getMissionDetail,
    getMissionTaskOptions,
    listRewardItems,
    addRewardItem,
  };
}
