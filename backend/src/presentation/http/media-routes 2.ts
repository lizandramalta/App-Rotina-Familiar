import multipart from '@fastify/multipart';
import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { ValidationError } from '../../shared/domain/domain-error.js';
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

/** Rotas do módulo Media. Registradas sob `/v1` (BA-20). */
export function registerMediaRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.register(async (scope) => {
    await scope.register(multipart, {
      limits: { fileSize: MAX_UPLOAD_INPUT_BYTES, files: 1, fields: 4, parts: 6 },
    });

    scope.addHook('onRequest', createAuthenticationHook(container));

    scope.post('/media', { schema: { response: uploadResponseSchema } }, async (request, reply) => {
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

      const result = await container.uploadMediaUseCase.execute({ actor, purpose, content });

      return reply.status(201).header('Cache-Control', 'no-store').send(result);
    });
  });
}
