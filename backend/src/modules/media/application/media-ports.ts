import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

export const MediaPurpose = {
  PROFILE_PHOTO: 'PROFILE_PHOTO',
  TASK_SIGNAL: 'TASK_SIGNAL',
} as const;
export type MediaPurpose = (typeof MediaPurpose)[keyof typeof MediaPurpose];

export const MediaState = {
  UPLOADING: 'UPLOADING',
  READY: 'READY',
  DELETING: 'DELETING',
  DELETED: 'DELETED',
  FAILED: 'FAILED',
} as const;
export type MediaState = (typeof MediaState)[keyof typeof MediaState];

export interface ProcessedImage {
  readonly body: Buffer;
  readonly contentType: 'image/jpeg';
  readonly sizeBytes: number;
  readonly width: number;
  readonly height: number;
}

/** Normaliza a imagem enviada: JPEG, lado maior limitado, sem metadados. */
export interface ImageProcessorPort {
  processProfilePhoto(input: Buffer): Promise<ProcessedImage>;
}

/** Armazenamento privado de objetos (R2). Nunca devolve URL pública. */
export interface ObjectStoragePort {
  put(params: {
    readonly key: string;
    readonly body: Buffer;
    readonly contentType: string;
  }): Promise<void>;
}

export interface MediaRecord {
  readonly id: string;
  readonly ownerMemberId: string;
  readonly purpose: MediaPurpose;
  readonly state: MediaState;
}

export interface MediaRepositoryPort {
  reserve(
    tx: TransactionContext,
    params: {
      readonly mediaId: string;
      readonly familyId: string;
      readonly ownerMemberId: string;
      readonly objectKey: string;
      readonly purpose: MediaPurpose;
    },
  ): Promise<void>;

  markReady(
    tx: TransactionContext,
    params: { readonly mediaId: string; readonly sizeBytes: number; readonly contentType: string },
  ): Promise<void>;

  markFailed(tx: TransactionContext, mediaId: string): Promise<void>;

  /** Sempre no escopo da família: mídia de outra família não é encontrada. */
  findInFamily(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly mediaId: string },
  ): Promise<MediaRecord | undefined>;

  markLinked(
    tx: TransactionContext,
    params: { readonly mediaId: string; readonly linkedAt: Date },
  ): Promise<void>;
}
