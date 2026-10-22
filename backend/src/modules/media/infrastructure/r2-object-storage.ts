import {
  DeleteObjectCommand,
  GetObjectCommand,
  NoSuchKey,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import type { ObjectStorageMaintenancePort } from '../application/media-ports.js';

export interface R2Settings {
  readonly endpoint: string;
  readonly bucketName: string;
  readonly accessKeyId: string;
  readonly secretAccessKey: string;
}

/**
 * Adaptador do Cloudflare R2 pela API compatível com S3 (BA-01). O bucket é
 * privado: a leitura dos bytes passa sempre pelo backend.
 */
export class R2ObjectStorage implements ObjectStorageMaintenancePort {
  private readonly client: S3Client;

  constructor(private readonly settings: R2Settings) {
    this.client = new S3Client({
      region: 'auto',
      endpoint: settings.endpoint,
      credentials: {
        accessKeyId: settings.accessKeyId,
        secretAccessKey: settings.secretAccessKey,
      },
    });
  }

  public async put(params: {
    readonly key: string;
    readonly body: Buffer;
    readonly contentType: string;
  }): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.settings.bucketName,
        Key: params.key,
        Body: params.body,
        ContentType: params.contentType,
        CacheControl: 'private, no-store',
      }),
    );
  }

  public async get(key: string): Promise<Buffer | undefined> {
    try {
      const result = await this.client.send(
        new GetObjectCommand({ Bucket: this.settings.bucketName, Key: key }),
      );
      return result.Body === undefined
        ? undefined
        : Buffer.from(await result.Body.transformToByteArray());
    } catch (error) {
      if (error instanceof NoSuchKey) {
        return undefined;
      }
      throw error;
    }
  }

  public async delete(key: string): Promise<void> {
    await this.client.send(new DeleteObjectCommand({ Bucket: this.settings.bucketName, Key: key }));
  }
}
