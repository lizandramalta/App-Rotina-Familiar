import sharp from 'sharp';
import { MediaFormatUnsupportedError, MediaTooLargeError } from '../domain/media-errors.js';
import type { ImageProcessorPort, ProcessedImage } from '../application/media-ports.js';

/** Lado maior da foto processada (SPEC-002 §5.2). */
const MAX_SIDE_PX = 1600;

/** Limite da foto depois de processada: 5 MB (SPEC-002 §5.2). */
export const MAX_PROCESSED_BYTES = 5 * 1024 * 1024;

/** Qualidades tentadas em ordem até a imagem caber no limite. */
const JPEG_QUALITIES = [85, 70, 55] as const;

/**
 * Converte qualquer imagem decodificável em JPEG de até 1.600 px, sem
 * metadados. `rotate()` aplica a orientação EXIF antes de ela ser descartada;
 * sem isso, fotos de celular ficariam deitadas.
 */
export class SharpImageProcessor implements ImageProcessorPort {
  public async processProfilePhoto(input: Buffer): Promise<ProcessedImage> {
    for (const quality of JPEG_QUALITIES) {
      const processed = await this.encode(input, quality);

      if (processed.sizeBytes <= MAX_PROCESSED_BYTES) {
        return processed;
      }
    }

    throw new MediaTooLargeError('The processed image still exceeds 5 MB.');
  }

  private async encode(input: Buffer, quality: number): Promise<ProcessedImage> {
    try {
      const { data, info } = await sharp(input, { failOn: 'error' })
        .rotate()
        .resize({
          width: MAX_SIDE_PX,
          height: MAX_SIDE_PX,
          fit: 'inside',
          withoutEnlargement: true,
        })
        .jpeg({ quality })
        .toBuffer({ resolveWithObject: true });

      return {
        body: data,
        contentType: 'image/jpeg',
        sizeBytes: data.length,
        width: info.width,
        height: info.height,
      };
    } catch {
      // Qualquer falha de decodificação é o mesmo erro para o cliente; o
      // conteúdo do arquivo não entra na mensagem.
      throw new MediaFormatUnsupportedError();
    }
  }
}
