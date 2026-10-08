import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

interface TaskParams {
  readonly taskId: string;
}

interface TaskBody {
  readonly title?: unknown;
  readonly weight?: unknown;
  readonly scheduledDate?: unknown;
  readonly assigneeIds?: unknown;
  readonly note?: unknown;
  readonly signalResolution?: unknown;
}

const taskProperties = {
  title: {},
  weight: {},
  scheduledDate: {},
  assigneeIds: {},
  note: {},
  signalResolution: {},
} as const;

const taskResponseSchema = {
  type: 'object',
  required: [
    'id',
    'title',
    'weight',
    'scheduledDate',
    'assigneeIds',
    'note',
    'status',
    'routineId',
    'createdAt',
  ],
  properties: {
    id: { type: 'string' },
    title: { type: 'string' },
    weight: { type: 'integer' },
    scheduledDate: { type: 'string' },
    assigneeIds: { type: 'array', items: { type: 'string' } },
    note: { type: ['string', 'null'] },
    status: { type: 'string' },
    routineId: { type: ['string', 'null'] },
    createdAt: { type: 'string' },
  },
} as const;

/** Rotas de CRUD da tarefa única — SPEC-007 fases 1 e 2. */
export function registerTaskRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));

    scope.post<{ Body: TaskBody }>(
      '/tasks',
      {
        schema: {
          body: { type: 'object', additionalProperties: false, properties: taskProperties },
          response: { 201: taskResponseSchema },
        },
      },
      async (request, reply) => {
        const task = await container.createTaskUseCase.execute({
          actor: requireActor(request),
          title: request.body.title,
          weight: request.body.weight,
          scheduledDate: request.body.scheduledDate,
          assigneeIds: request.body.assigneeIds,
          note: request.body.note,
        });
        return reply
          .status(201)
          .header('Location', `/v1/tasks/${task.id}`)
          .header('Cache-Control', 'no-store')
          .send(task);
      },
    );

    scope.get<{ Params: TaskParams }>(
      '/tasks/:taskId',
      { schema: { response: { 200: taskResponseSchema } } },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.getTaskUseCase.execute(requireActor(request), request.params.taskId),
          ),
    );

    scope.patch<{ Params: TaskParams; Body: TaskBody }>(
      '/tasks/:taskId',
      {
        schema: {
          body: { type: 'object', additionalProperties: false, properties: taskProperties },
          response: { 200: taskResponseSchema },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.editTaskUseCase.execute({
              actor: requireActor(request),
              taskId: request.params.taskId,
              title: request.body.title,
              weight: request.body.weight,
              scheduledDate: request.body.scheduledDate,
              assigneeIds: request.body.assigneeIds,
              note: request.body.note,
              signalResolution: request.body.signalResolution,
            }),
          ),
    );

    scope.delete<{ Params: TaskParams }>(
      '/tasks/:taskId',
      {
        schema: {
          response: {
            200: { type: 'object', required: ['id'], properties: { id: { type: 'string' } } },
          },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.deleteTaskUseCase.execute(requireActor(request), request.params.taskId),
          ),
    );
  });
}
