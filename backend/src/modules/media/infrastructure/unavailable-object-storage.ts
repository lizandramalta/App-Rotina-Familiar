import { DependencyUnavailableError } from '../../../shared/domain/domain-error.js';
import type { ObjectStorageMaintenancePort } from '../application/media-ports.js';

/**
 * Usado enquanto o R2 não está configurado. O upload responde 503 e a criação
 * da família segue funcionando, já que a foto é opcional (CA-10).
 */
export class UnavailableObjectStorage implements ObjectStorageMaintenancePort {
  public async put(): Promise<void> {
    throw new DependencyUnavailableError('Object storage is not configured.');
  }

  public async get(): Promise<Buffer | undefined> {
    throw new DependencyUnavailableError('Object storage is not configured.');
  }

  public async delete(): Promise<void> {
    throw new DependencyUnavailableError('Object storage is not configured.');
  }
}
