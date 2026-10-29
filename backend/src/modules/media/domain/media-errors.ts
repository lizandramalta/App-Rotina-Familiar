import { DomainError } from '../../../shared/domain/domain-error.js';

export class MediaTooLargeError extends DomainError {
  constructor(message = 'The uploaded file exceeds the allowed size.') {
    super({ message, code: 'MEDIA_TOO_LARGE', statusCode: 413 });
  }
}

export class MediaFormatUnsupportedError extends DomainError {
  constructor(message = 'The uploaded file is not a recognizable image.') {
    super({ message, code: 'MEDIA_FORMAT_UNSUPPORTED', statusCode: 415 });
  }
}

/** Mídia ainda processando, falha ou removida (SPEC-002 §5.3). */
export class PhotoMediaNotReadyError extends DomainError {
  constructor(message = 'The media is not ready to be linked.') {
    super({ message, code: 'PHOTO_MEDIA_NOT_READY', statusCode: 422 });
  }
}

/** Mídia de outro titular da mesma família. */
export class PhotoMediaNotOwnedError extends DomainError {
  constructor(message = 'The media does not belong to the authenticated member.') {
    super({ message, code: 'PHOTO_MEDIA_NOT_OWNED', statusCode: 422 });
  }
}

export class PhotoMediaPurposeMismatchError extends DomainError {
  constructor(message = 'The media was not uploaded as a profile photo.') {
    super({ message, code: 'PHOTO_MEDIA_PURPOSE_MISMATCH', statusCode: 422 });
  }
}
