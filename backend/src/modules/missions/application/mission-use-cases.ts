import { randomUUID } from 'node:crypto';
import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../../shared/application/transaction-runner.js';
import {
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import {
  MissionCompletedProtectedError,
  MissionManagementNotAllowedError,
  MissionWouldHaveNoTasksError,
  TaskNotInFamilyError,
} from '../domain/mission-errors.js';
import {
  normalizeTaskIds,
  validateMissionNote,
  validateMissionTitle,
} from '../domain/mission-validation.js';
import type { CloseEligibleMissions } from './close-eligible-missions.js';
import type {
  MissionParticipantRecord,
  MissionRecord,
  MissionRepositoryPort,
  MissionStatus,
  MissionSummaryRecord,
  MissionTaskOptionRecord,
  MissionTaskRecord,
  PageCursor,
} from './mission-repository-port.js';

export const TASK_OPTIONS_PAGE_SIZE = 20;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const QUERY_MAX_LENGTH = 60;

export interface MissionResponse {
  readonly id: string;
  readonly familyId: string;
  readonly title: string;
  readonly note: string | null;
  readonly status: MissionStatus;
  readonly taskIds: readonly string[];
  readonly completedAt: string | null;
  readonly isRedemptionAvailable: boolean;
  readonly createdAt: string;
}

export interface MissionTaskProjection {
  readonly id: string;
  readonly title: string;
  readonly status: MissionTaskRecord['status'];
}

export interface MissionParticipantProjection {
  readonly memberId: string;
  readonly displayName: string;
}

/** SPEC-016 CA-01: contagens e percentual canônicos, visíveis a toda a família. */
export interface MissionListItem {
  readonly id: string;
  readonly title: string;
  readonly status: MissionStatus;
  readonly taskCount: number;
  readonly completedTaskCount: number;
  readonly progressPercent: number;
  readonly isRedemptionAvailable: boolean;
  // Aceite de recompensa é introduzido pela SPEC-017; nenhum registro existe ainda (CA-05).
  readonly acceptedReward: null;
}

/** Projeção Kids da lista: sem a situação de resgate (RF36/RN33). */
export interface KidsMissionListItem {
  readonly id: string;
  readonly title: string;
  readonly status: MissionStatus;
  readonly taskCount: number;
  readonly completedTaskCount: number;
  readonly progressPercent: number;
  readonly acceptedReward: null;
}

export interface MissionListResponse {
  readonly inProgress: readonly (MissionListItem | KidsMissionListItem)[];
  readonly completed: readonly (MissionListItem | KidsMissionListItem)[];
}

/** SPEC-016 CA-03: detalhe completo para Administrador/Membro, com participações. */
export interface MissionDetailResponse {
  readonly id: string;
  readonly familyId: string;
  readonly title: string;
  readonly note: string | null;
  readonly status: MissionStatus;
  readonly tasks: readonly MissionTaskProjection[];
  readonly completedAt: string | null;
  readonly progressPercent: number;
  readonly isRedemptionAvailable: boolean;
  readonly acceptedReward: null;
  readonly participations: readonly MissionParticipantProjection[];
  readonly createdAt: string;
}

/** Projeção Kids do detalhe: sem participações nem situação de resgate (CA-03, RF36). */
export interface KidsMissionDetailResponse {
  readonly id: string;
  readonly title: string;
  readonly note: string | null;
  readonly status: MissionStatus;
  readonly tasks: readonly MissionTaskProjection[];
  readonly completedAt: string | null;
  readonly progressPercent: number;
  readonly acceptedReward: null;
  readonly createdAt: string;
}

export interface Page<T> {
  readonly items: readonly T[];
  readonly nextCursor: string | null;
}

export interface MissionCommand {
  readonly actor: ActorContext;
  readonly title: unknown;
  readonly note: unknown;
  readonly taskIds: unknown;
}

export interface EditMissionCommand extends MissionCommand {
  readonly missionId: string;
}

interface Deps {
  readonly repository: MissionRepositoryPort;
  readonly transactionRunner: TransactionRunner;
  readonly clock: Clock;
  readonly logger: Logger;
}

function statusOf(mission: { readonly completedAt: Date | null }): MissionStatus {
  return mission.completedAt === null ? 'inProgress' : 'completed';
}

function toResponse(mission: MissionRecord): MissionResponse {
  return {
    id: mission.id,
    familyId: mission.familyId,
    title: mission.title,
    note: mission.note,
    status: statusOf(mission),
    taskIds: mission.taskIds,
    completedAt: mission.completedAt?.toISOString() ?? null,
    isRedemptionAvailable: mission.completedAt !== null,
    createdAt: mission.createdAt.toISOString(),
  };
}

/** Tarefas vinculadas concluídas / total vinculado × 100; sem tarefa vinculada não há divisão (RF30). */
function progressPercentOf(totalTasks: number, completedTasks: number): number {
  return totalTasks === 0 ? 0 : (completedTasks / totalTasks) * 100;
}

function completedTasksOf(tasks: readonly MissionTaskRecord[]): number {
  // `awaitingConfirmation` nunca conta como concluída (RN26/RN35).
  return tasks.filter((task) => task.status === 'completed').length;
}

function toMissionDetailResponse(
  mission: MissionRecord,
  participations: readonly MissionParticipantRecord[],
): MissionDetailResponse {
  return {
    id: mission.id,
    familyId: mission.familyId,
    title: mission.title,
    note: mission.note,
    status: statusOf(mission),
    tasks: mission.tasks,
    completedAt: mission.completedAt?.toISOString() ?? null,
    progressPercent: progressPercentOf(mission.tasks.length, completedTasksOf(mission.tasks)),
    isRedemptionAvailable: mission.completedAt !== null,
    // Aceite de recompensa é introduzido pela SPEC-017; nenhum registro existe ainda (CA-05).
    acceptedReward: null,
    participations: participations.map((participant) => ({
      memberId: participant.memberId,
      displayName: participant.displayName,
    })),
    createdAt: mission.createdAt.toISOString(),
  };
}

function toKidsMissionDetailResponse(mission: MissionRecord): KidsMissionDetailResponse {
  return {
    id: mission.id,
    title: mission.title,
    note: mission.note,
    status: statusOf(mission),
    tasks: mission.tasks,
    completedAt: mission.completedAt?.toISOString() ?? null,
    progressPercent: progressPercentOf(mission.tasks.length, completedTasksOf(mission.tasks)),
    acceptedReward: null,
    createdAt: mission.createdAt.toISOString(),
  };
}

async function translateDependencyFailure<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof DomainError) {
      throw error;
    }
    throw new DependencyUnavailableError();
  }
}

/** O papel é relido após adquirir o lock: a sessão não amplia privilégio. */
async function requireAdministrator(
  deps: Deps,
  tx: TransactionContext,
  actor: ActorContext,
): Promise<void> {
  const role = await deps.repository.findMemberRole(tx, actor.familyId, actor.memberId);
  if (role === undefined) {
    throw new NotFoundError('Mission not found.');
  }
  if (role !== MemberRole.ADMINISTRATOR) {
    throw deniedBy(deps, actor, new MissionManagementNotAllowedError());
  }
}

function deniedBy<E extends DomainError>(deps: Deps, actor: ActorContext, error: E): E {
  deps.logger.warn('mission_management_denied', {
    actorId: actor.memberId,
    targetFamilyId: actor.familyId,
    code: error.code,
  });
  return error;
}

async function requireTasksInFamily(
  deps: Deps,
  tx: TransactionContext,
  familyId: string,
  taskIds: readonly string[],
): Promise<void> {
  const found = await deps.repository.countFamilyTasks(tx, familyId, taskIds);
  if (found !== taskIds.length) {
    throw new TaskNotInFamilyError();
  }
}

function assertUuid(value: string): void {
  if (!UUID_PATTERN.test(value)) {
    throw new NotFoundError('Mission not found.');
  }
}

export class CreateMissionUseCase {
  constructor(private readonly deps: Deps & { readonly closer: CloseEligibleMissions }) {}

  public async execute(command: MissionCommand): Promise<MissionResponse> {
    const { actor } = command;
    // Recusa antecipada por perfil: Membro/Kids nem chegam a abrir transação.
    if (actor.role !== MemberRole.ADMINISTRATOR) {
      throw deniedBy(this.deps, actor, new MissionManagementNotAllowedError());
    }
    const title = validateMissionTitle(command.title);
    const note = validateMissionNote(command.note);
    const taskIds = normalizeTaskIds(command.taskIds);

    return translateDependencyFailure(() =>
      this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        await requireAdministrator(this.deps, tx, actor);
        await requireTasksInFamily(this.deps, tx, actor.familyId, taskIds);

        const now = this.deps.clock.now();
        const missionId = randomUUID();
        await this.deps.repository.insertMission(tx, {
          missionId,
          familyId: actor.familyId,
          title,
          note,
          taskIds,
          now,
        });
        await this.deps.closer.closeByIds(tx, {
          familyId: actor.familyId,
          missionIds: [missionId],
          now,
          trigger: 'create',
        });
        const created = await this.deps.repository.findMission(tx, actor.familyId, missionId);
        if (created === undefined) {
          throw new DependencyUnavailableError();
        }
        this.deps.logger.info('mission_created', {
          missionId,
          familyId: actor.familyId,
          taskCount: taskIds.length,
          initialStatus: statusOf(created),
          hasNote: note !== null,
        });
        return toResponse(created);
      }),
    );
  }
}

export class EditMissionUseCase {
  constructor(private readonly deps: Deps & { readonly closer: CloseEligibleMissions }) {}

  public async execute(command: EditMissionCommand): Promise<MissionResponse> {
    const { actor } = command;
    if (actor.role !== MemberRole.ADMINISTRATOR) {
      throw deniedBy(this.deps, actor, new MissionManagementNotAllowedError());
    }
    assertUuid(command.missionId);

    return translateDependencyFailure(() =>
      this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        await requireAdministrator(this.deps, tx, actor);
        const current = await this.deps.repository.findMission(
          tx,
          actor.familyId,
          command.missionId,
          true,
        );
        if (current === undefined) {
          throw new NotFoundError('Mission not found.');
        }
        if (current.completedAt !== null) {
          throw deniedBy(this.deps, actor, new MissionCompletedProtectedError());
        }

        const title =
          command.title === undefined ? current.title : validateMissionTitle(command.title);
        const note = command.note === undefined ? current.note : validateMissionNote(command.note);
        let taskIds = current.taskIds;
        if (command.taskIds !== undefined) {
          if (Array.isArray(command.taskIds) && command.taskIds.length === 0) {
            throw new MissionWouldHaveNoTasksError();
          }
          taskIds = normalizeTaskIds(command.taskIds);
          await requireTasksInFamily(this.deps, tx, actor.familyId, taskIds);
        }

        const now = this.deps.clock.now();
        await this.deps.repository.updateMission(tx, {
          mission: current,
          title,
          note,
          taskIds,
          now,
        });
        await this.deps.closer.closeByIds(tx, {
          familyId: actor.familyId,
          missionIds: [current.id],
          now,
          trigger: 'edit',
        });
        const updated = await this.deps.repository.findMission(tx, actor.familyId, current.id);
        if (updated === undefined) {
          throw new DependencyUnavailableError();
        }
        this.deps.logger.info('mission_edited', {
          missionId: current.id,
          familyId: actor.familyId,
          taskCountDelta: taskIds.length - current.taskIds.length,
          hasNote: note !== null,
        });
        return toResponse(updated);
      }),
    );
  }
}

export class GetMissionDetailUseCase {
  constructor(private readonly deps: Deps) {}

  public async execute(
    actor: ActorContext,
    missionId: string,
  ): Promise<MissionDetailResponse | KidsMissionDetailResponse> {
    assertUuid(missionId);
    const isKids = actor.role === MemberRole.KIDS;
    // Missão e participações são lidas na mesma transação: uma reabertura
    // confirmada entre as duas consultas nunca aparece misturada (CA-06).
    return translateDependencyFailure(() =>
      this.deps.transactionRunner.run(async (tx) => {
        const mission = await this.deps.repository.findMission(tx, actor.familyId, missionId);
        if (mission === undefined) {
          throw new NotFoundError('Mission not found.');
        }
        if (isKids) {
          return toKidsMissionDetailResponse(mission);
        }
        const participations = await this.deps.repository.listParticipations(
          tx,
          actor.familyId,
          missionId,
        );
        return toMissionDetailResponse(mission, participations);
      }),
    );
  }
}

function toListItem(
  record: MissionSummaryRecord,
  isKids: boolean,
): MissionListItem | KidsMissionListItem {
  const base = {
    id: record.id,
    title: record.title,
    status: statusOf(record),
    taskCount: record.taskCount,
    completedTaskCount: record.completedTaskCount,
    progressPercent: progressPercentOf(record.taskCount, record.completedTaskCount),
    // Aceite de recompensa é introduzido pela SPEC-017; nenhum registro existe ainda (CA-05).
    acceptedReward: null,
  };
  return isKids ? base : { ...base, isRedemptionAvailable: record.completedAt !== null };
}

function encodeCursor(cursor: PageCursor): string {
  return Buffer.from(JSON.stringify(cursor), 'utf8').toString('base64url');
}

function decodeCursor(input: unknown): PageCursor | undefined {
  if (input === undefined) {
    return undefined;
  }
  try {
    const parsed: unknown = JSON.parse(Buffer.from(String(input), 'base64url').toString('utf8'));
    if (
      typeof parsed === 'object' &&
      parsed !== null &&
      'sortKey' in parsed &&
      'id' in parsed &&
      typeof parsed.sortKey === 'string' &&
      typeof parsed.id === 'string' &&
      parsed.sortKey.length > 0 &&
      parsed.sortKey.length <= 64 &&
      !Number.isNaN(Date.parse(parsed.sortKey)) &&
      UUID_PATTERN.test(parsed.id)
    ) {
      return { sortKey: parsed.sortKey, id: parsed.id };
    }
  } catch {
    // cai no erro de validação abaixo
  }
  throw new ValidationError('The cursor is invalid.', { cursor: ['CURSOR_INVALID'] });
}

function paginate<T>(rows: readonly T[], size: number, cursorOf: (row: T) => PageCursor): Page<T> {
  const items = rows.slice(0, size);
  const last = items.at(-1);
  return {
    items,
    nextCursor: rows.length > size && last !== undefined ? encodeCursor(cursorOf(last)) : null,
  };
}

export class ListMissionsUseCase {
  constructor(private readonly deps: Deps) {}

  public async execute(actor: ActorContext): Promise<MissionListResponse> {
    const rows = await translateDependencyFailure(() =>
      this.deps.transactionRunner.run((tx) =>
        this.deps.repository.listMissions(tx, { familyId: actor.familyId }),
      ),
    );
    const isKids = actor.role === MemberRole.KIDS;
    const inProgress: (MissionListItem | KidsMissionListItem)[] = [];
    const completed: (MissionListItem | KidsMissionListItem)[] = [];
    for (const row of rows) {
      const bucket = row.completedAt === null ? inProgress : completed;
      bucket.push(toListItem(row, isKids));
    }
    return { inProgress, completed };
  }
}

export class GetMissionTaskOptionsUseCase {
  constructor(private readonly deps: Deps) {}

  public async execute(
    actor: ActorContext,
    queryInput: unknown,
    cursorInput: unknown,
  ): Promise<Page<MissionTaskOptionRecord>> {
    if (actor.role !== MemberRole.ADMINISTRATOR) {
      throw deniedBy(this.deps, actor, new MissionManagementNotAllowedError());
    }
    const query = this.normalizeQuery(queryInput);
    const after = decodeCursor(cursorInput);
    const rows = await translateDependencyFailure(() =>
      this.deps.transactionRunner.run(async (tx) => {
        await requireAdministrator(this.deps, tx, actor);
        return this.deps.repository.listTaskOptions(tx, {
          familyId: actor.familyId,
          query,
          after,
          limit: TASK_OPTIONS_PAGE_SIZE + 1,
        });
      }),
    );
    return paginate(rows, TASK_OPTIONS_PAGE_SIZE, (row) => ({
      sortKey: row.scheduledDate,
      id: row.id,
    }));
  }

  private normalizeQuery(input: unknown): string | undefined {
    if (input === undefined) {
      return undefined;
    }
    if (typeof input !== 'string' || [...input].length > QUERY_MAX_LENGTH) {
      throw new ValidationError('The search query is invalid.', { query: ['QUERY_INVALID'] });
    }
    const trimmed = input.trim();
    return trimmed.length === 0 ? undefined : trimmed;
  }
}
