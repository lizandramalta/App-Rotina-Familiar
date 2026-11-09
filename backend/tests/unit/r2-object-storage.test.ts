/** Adaptador R2 (BA-01): comandos S3 enviados ao bucket privado, com o S3Client simulado. */
import {
  DeleteObjectCommand,
  GetObjectCommand,
  NoSuchKey,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { R2ObjectStorage } from '../../src/modules/media/infrastructure/r2-object-storage.js';

const SETTINGS = {
  endpoint: 'https://account.r2.cloudflarestorage.com',
  bucketName: 'test-bucket',
  accessKeyId: 'test-access-key',
  secretAccessKey: 'test-secret-key',
};

describe('R2ObjectStorage', () => {
  let send: ReturnType<typeof vi.spyOn>;
  let storage: R2ObjectStorage;

  beforeEach(() => {
    send = vi.spyOn(S3Client.prototype, 'send');
    storage = new R2ObjectStorage(SETTINGS);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('puts the object in the configured bucket as private, non-cacheable content', async () => {
    send.mockResolvedValue({} as never);
    const body = Buffer.from([1, 2, 3]);

    await storage.put({ key: 'family/a.jpg', body, contentType: 'image/jpeg' });

    const command = send.mock.calls[0]?.[0];
    expect(command).toBeInstanceOf(PutObjectCommand);
    expect((command as PutObjectCommand).input).toEqual({
      Bucket: 'test-bucket',
      Key: 'family/a.jpg',
      Body: body,
      ContentType: 'image/jpeg',
      CacheControl: 'private, no-store',
    });
  });

  it('gets the object bytes from the configured bucket', async () => {
    send.mockResolvedValue({
      Body: { transformToByteArray: async () => new Uint8Array([9, 8, 7]) },
    } as never);

    const result = await storage.get('family/a.jpg');

    expect(result).toEqual(Buffer.from([9, 8, 7]));
    const command = send.mock.calls[0]?.[0];
    expect(command).toBeInstanceOf(GetObjectCommand);
    expect((command as GetObjectCommand).input).toEqual({
      Bucket: 'test-bucket',
      Key: 'family/a.jpg',
    });
  });

  it('returns undefined when the object does not exist', async () => {
    send.mockRejectedValue(new NoSuchKey({ message: 'missing', $metadata: {} }) as never);

    await expect(storage.get('family/missing.jpg')).resolves.toBeUndefined();
  });

  it('propagates other storage failures on get', async () => {
    send.mockRejectedValue(new Error('network down') as never);

    await expect(storage.get('family/a.jpg')).rejects.toThrow('network down');
  });

  it('deletes the object from the configured bucket', async () => {
    send.mockResolvedValue({} as never);

    await storage.delete('family/a.jpg');

    const command = send.mock.calls[0]?.[0];
    expect(command).toBeInstanceOf(DeleteObjectCommand);
    expect((command as DeleteObjectCommand).input).toEqual({
      Bucket: 'test-bucket',
      Key: 'family/a.jpg',
    });
  });
});
