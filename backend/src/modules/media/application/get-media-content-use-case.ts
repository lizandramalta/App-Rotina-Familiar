import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { NotFoundError } from '../../../shared/domain/domain-error.js';
import {
  MediaState,
  type MediaRepositoryPort,
  type ObjectStorageReaderPort,
} from './media-ports.js';

export interface MediaContent {
  readonly body: Buffer;
  readonly contentType: string;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * `GetMediaContent` (SPEC-006 CA-15/E-06): bytes de mídia `READY` da família do
 * ator. Inexistente, de outra família, fora de `READY` ou com UUID inválido
 * respondem igual (404), sem revelar que o identificador existe (RNF06).
 */
export class GetMediaContentUseCase {
  constructor(
    private readonly deps: {
      readonly repository: MediaRepositoryPort;
      readonly storage: ObjectStorageReaderPort;
      readonly transactionRunner: TransactionRunner;
    },
  ) {}

  public async execute(actor: ActorContext, mediaId: string): Promise<MediaContent> {
    if (!UUID.test(mediaId)) {
      throw new NotFoundError('Media not found.');
    }

    const media = await this.deps.transactionRunner.run((tx) =>
      this.deps.repository.findContentInFamily(tx, { familyId: actor.familyId, mediaId }),
    );
    if (media === undefined || media.state !== MediaState.READY) {
      throw new NotFoundError('Media not found.');
    }

    const body = await this.deps.storage.get(media.objectKey);
    if (body === undefined) {
      throw new NotFoundError('Media not found.');
    }

    return { body, contentType: media.contentType };
  }
}
