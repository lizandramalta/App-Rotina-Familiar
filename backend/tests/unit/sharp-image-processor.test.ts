/** Processamento da foto de perfil (SPEC-002 §5.2): JPEG, 1.600 px, sem metadados. */
import sharp from 'sharp';
import { describe, expect, it } from 'vitest';
import {
  MediaFormatUnsupportedError,
  MediaTooLargeError,
} from '../../src/modules/media/domain/media-errors.js';
import {
  MAX_PROCESSED_BYTES,
  SharpImageProcessor,
} from '../../src/modules/media/infrastructure/sharp-image-processor.js';

const processor = new SharpImageProcessor();

const solidImage = (width: number, height: number, format: 'png' | 'webp' | 'jpeg' = 'png') => {
  const image = sharp({
    create: { width, height, channels: 3, background: { r: 200, g: 40, b: 40 } },
  });
  return image.toFormat(format).toBuffer();
};

describe('SharpImageProcessor', () => {
  it('converts a PNG to JPEG', async () => {
    const result = await processor.processProfilePhoto(await solidImage(400, 300));

    expect(result.contentType).toBe('image/jpeg');
    expect((await sharp(result.body).metadata()).format).toBe('jpeg');
    expect(result.sizeBytes).toBe(result.body.length);
    expect(result.width).toBe(400);
    expect(result.height).toBe(300);
  });

  it('accepts other decodable formats', async () => {
    const result = await processor.processProfilePhoto(await solidImage(64, 64, 'webp'));

    expect((await sharp(result.body).metadata()).format).toBe('jpeg');
  });

  it('limits the longest side to 1600 px keeping the aspect ratio', async () => {
    const result = await processor.processProfilePhoto(await solidImage(3200, 1600));

    expect(result.width).toBe(1600);
    expect(result.height).toBe(800);
  });

  it('does not enlarge small images', async () => {
    const result = await processor.processProfilePhoto(await solidImage(50, 40));

    expect([result.width, result.height]).toEqual([50, 40]);
  });

  it('strips metadata such as EXIF and GPS', async () => {
    const withExif = await sharp({
      create: { width: 100, height: 100, channels: 3, background: '#fff' },
    })
      .withExif({ IFD0: { Copyright: 'someone', Artist: 'GPS-tagged person' } })
      .jpeg()
      .toBuffer();
    expect((await sharp(withExif).metadata()).exif).toBeDefined();

    const result = await processor.processProfilePhoto(withExif);

    expect((await sharp(result.body).metadata()).exif).toBeUndefined();
  });

  it('applies the EXIF orientation before discarding it', async () => {
    const landscapeRotated = await sharp({
      create: { width: 200, height: 100, channels: 3, background: '#fff' },
    })
      .withMetadata({ orientation: 6 })
      .jpeg()
      .toBuffer();

    const result = await processor.processProfilePhoto(landscapeRotated);

    expect([result.width, result.height]).toEqual([100, 200]);
  });

  it.each([
    ['plain text', Buffer.from('this is not an image')],
    ['an empty buffer', Buffer.alloc(0)],
    ['a truncated header', Buffer.from([0x89, 0x50, 0x4e, 0x47])],
  ])('rejects %s with MediaFormatUnsupportedError', async (_label, input) => {
    await expect(processor.processProfilePhoto(input)).rejects.toBeInstanceOf(
      MediaFormatUnsupportedError,
    );
  });

  it('keeps the processed size within the 5 MB limit', async () => {
    const noisy = await sharp({
      create: {
        width: 1600,
        height: 1600,
        channels: 3,
        background: '#808080',
        noise: { type: 'gaussian', mean: 128, sigma: 60 },
      },
    })
      .png()
      .toBuffer();

    const result = await processor.processProfilePhoto(noisy);

    expect(result.sizeBytes).toBeLessThanOrEqual(MAX_PROCESSED_BYTES);
  });

  it('exposes MediaTooLargeError as 413 MEDIA_TOO_LARGE', () => {
    expect(new MediaTooLargeError()).toMatchObject({ statusCode: 413, code: 'MEDIA_TOO_LARGE' });
    expect(new MediaFormatUnsupportedError()).toMatchObject({
      statusCode: 415,
      code: 'MEDIA_FORMAT_UNSUPPORTED',
    });
  });
});
