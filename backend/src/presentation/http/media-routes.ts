import multipart from '@fastify/multipart';
import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { DomainError, ValidationError } from '../../shared/domain/domain-error.js';
import { MediaTooLargeError } from '../../modules/media/domain/media-errors.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

/**
 * Limite operacional de entrada do upload. A SPEC fixa os 5 MB depois do
 * processamento; este teto só impede que o servidor receba arquivos absurdos.
 */
export const MAX_UPLOAD_INPUT_BYTES = 10 * 1024 * 1024;

function isErrorWithCode(error: unknown, code: string): boolean {
  return typeof error === 'object' && error !== null && 'code' in error && error.code === code;
}

const uploadResponseSchema = {
  201: {
    type: 'object',
    required: ['mediaId', 'state', 'width', 'height'],
    properties: {
      mediaId: { type: 'string' },
      state: { type: 'string' },
      width: { type: 'integer' },
      height: { type: 'integer' },
    },
  },
} as const;

const problemResponseSchema = {
  type: 'object',
  required: ['type', 'title', 'status', 'code', 'requestId'],
  properties: {
    type: { type: 'string' },
    title: { type: 'string' },
    status: { type: 'integer' },
    code: { type: 'string' },
    requestId: { type: 'string' },
    fieldErrors: {
      type: 'object',
      additionalProperties: { type: 'array', items: { type: 'string' } },
    },
  },
} as const;

/** OpenAPI-only: multipart bytes are consumed with request.parts(), not body coercion. */
export const onboardingUploadBodyDocumentation = {
  type: 'object',
  required: ['creationGrant', 'purpose', 'file'],
  properties: {
    creationGrant: { type: 'string' },
    purpose: { type: 'string', enum: ['profilePhoto'] },
    file: { type: 'string', format: 'binary' },
  },
} as const;

/** Rotas do módulo Media. Registradas sob `/v1` (BA-20). */
export function registerMediaRoutes(
  app: FastifyInstance,
  container: ApplicationContainer,
  releaseChannel: 'full' | 'testflight' = 'full',
): void {
  app.register(async (scope) => {
    await scope.register(multipart, {
      limits: { fileSize: MAX_UPLOAD_INPUT_BYTES, files: 1, fields: 4, parts: 5 },
    });

    scope.post<{ Headers: { 'x-installation-proof': string } }>(
      '/onboarding/media',
      {
        schema: {
          tags: ['Media'],
          summary: 'Upload a private creator photo before family creation',
          consumes: ['multipart/form-data'],
          headers: {
            type: 'object',
            required: ['x-installation-proof'],
            properties: { 'x-installation-proof': { type: 'string', minLength: 1 } },
          },
          body: {},
          response: {
            ...uploadResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            413: problemResponseSchema,
            415: problemResponseSchema,
            422: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) => {
        let creationGrant: unknown;
        let purpose: unknown;
        let content: Buffer | undefined;
        let fileCount = 0;
        const unknownFields: string[] = [];
        try {
          for await (const part of request.parts()) {
            if (part.type === 'file') {
              fileCount += 1;
              if (part.fieldname !== 'file') unknownFields.push(part.fieldname);
              content = await part.toBuffer();
            } else if (part.fieldname === 'creationGrant') {
              creationGrant = part.value;
            } else if (part.fieldname === 'purpose') {
              purpose = part.value;
            } else {
              unknownFields.push(part.fieldname);
            }
          }
        } catch (error) {
          if (isErrorWithCode(error, 'FST_REQ_FILE_TOO_LARGE')) throw new MediaTooLargeError();
          throw new ValidationError('The upload must be a multipart request with one file.', {
            file: ['MEDIA_FILE_REQUIRED'],
          });
        }
        if (unknownFields.length > 0) {
          throw new DomainError({
            message: 'The upload contains unknown fields.',
            code: 'UNKNOWN_FIELD',
            statusCode: 400,
            fieldErrors: { [unknownFields[0]!]: ['UNKNOWN_FIELD'] },
          });
        }
        if (fileCount !== 1 || content === undefined || content.length === 0) {
          throw new ValidationError('The upload must include one file.', {
            file: ['MEDIA_FILE_REQUIRED'],
          });
        }
        const result = await container.uploadOnboardingMediaUseCase.execute({
          creationGrant,
          installationProof: request.headers['x-installation-proof'],
          purpose,
          content,
        });
        return reply.status(201).header('Cache-Control', 'no-store').send(result);
      },
    );
  });

  app.register(async (scope) => {
    await scope.register(multipart, {
      limits: { fileSize: MAX_UPLOAD_INPUT_BYTES, files: 1, fields: 4, parts: 6 },
    });

    scope.addHook('onRequest', createAuthenticationHook(container));

    scope.get<{ Params: { mediaId: string } }>(
      '/media/:mediaId/content',
      {
        schema: {
          tags: ['Media'],
          summary: 'Download the bytes of a READY media of the actor family',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['mediaId'],
            additionalProperties: false,
            properties: { mediaId: { type: 'string' } },
          },
          response: {
            401: problemResponseSchema,
            404: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) => {
        const content = await container.getMediaContentUseCase.execute(
          requireActor(request),
          request.params.mediaId,
        );

        return reply
          .status(200)
          .header('Content-Type', content.contentType)
          .header('Cache-Control', 'private, no-store')
          .send(content.body);
      },
    );

    scope.post(
      '/media',
      {
        schema: {
          tags: ['Media'],
          summary: 'Upload private media',
          security: [{ bearerAuth: [] }],
          consumes: ['multipart/form-data'],
          response: uploadResponseSchema,
        },
      },
      async (request, reply) => {
        const actor = requireActor(request);

        let purpose: unknown;
        let content: Buffer | undefined;

        try {
          for await (const part of request.parts()) {
            if (part.type === 'file') {
              content = await part.toBuffer();
            } else if (part.fieldname === 'purpose') {
              purpose = part.value;
            }
          }
        } catch (error) {
          if (isErrorWithCode(error, 'FST_REQ_FILE_TOO_LARGE')) {
            throw new MediaTooLargeError();
          }

          throw new ValidationError('The upload must be a multipart request with one file.', {
            file: ['MEDIA_FILE_REQUIRED'],
          });
        }

        if (content === undefined || content.length === 0) {
          throw new ValidationError('The upload must include one file.', {
            file: ['MEDIA_FILE_REQUIRED'],
          });
        }

        if (releaseChannel === 'testflight' && purpose === 'taskSignal') {
          throw new ValidationError('Task signal media is not available in this release.', {
            purpose: ['MEDIA_PURPOSE_INVALID'],
          });
        }

        const result = await container.uploadMediaUseCase.execute({ actor, purpose, content });

        return reply.status(201).header('Cache-Control', 'no-store').send(result);
      },
    );
  });
}
