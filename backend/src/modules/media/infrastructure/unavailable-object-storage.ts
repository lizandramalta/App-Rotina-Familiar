import { DependencyUnavailableError } from '../../../shared/domain/domain-error.js';
import type { ObjectStoragePort } from '../application/media-ports.js';

/**
 * Usado enquanto o R2 não está configurado. O upload responde 503 e a criação
 * da família segue funcionando, já que a foto é opcional (CA-10).
 */
export class UnavailableObjectStorage implements ObjectStoragePort {
  public async put(): Promise<void> {
    throw new DependencyUnavailableError('Object storage is not configured.');
  }
}
