/** SCRUM-106 / SPEC-002 CA-10: grant upload transport and documented contract. */
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { buildTestApp, type TestApp } from '../support/build-test-app.js';

const boundary = 'onboarding-test-boundary';
function multipart(parts: { name: string; value: string | Buffer; filename?: string }[]): Buffer {
  const chunks: Buffer[] = [];
  for (const part of parts) {
    const disposition =
      part.filename === undefined
        ? `name="${part.name}"`
        : `name="${part.name}"; filename="${part.filename}"`;
    chunks.push(
      Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; ${disposition}\r\n${part.filename === undefined ? '' : 'Content-Type: image/png\r\n'}\r\n`,
      ),
    );
    chunks.push(Buffer.isBuffer(part.value) ? part.value : Buffer.from(part.value));
    chunks.push(Buffer.from('\r\n'));
  }
  chunks.push(Buffer.from(`--${boundary}--\r\n`));
  return Buffer.concat(chunks);
}

describe('POST /v1/onboarding/media', () => {
  let test: TestApp;
  beforeEach(() => {
    test = buildTestApp();
    test.uploadOnboardingMedia.execute.mockResolvedValue({
      mediaId: 'media-1',
      state: 'READY',
      width: 8,
      height: 8,
    });
  });
  afterEach(async () => {
    await test.app.close();
  });

  const upload = (parts: { name: string; value: string | Buffer; filename?: string }[]) =>
    test.app.inject({
      method: 'POST',
      url: '/v1/onboarding/media',
      headers: {
        'x-installation-proof': 'device-proof',
        'content-type': `multipart/form-data; boundary=${boundary}`,
      },
      payload: multipart(parts),
    });

  it('accepts a photo with grant and installation proof without Bearer', async () => {
    const response = await upload([
      { name: 'creationGrant', value: 'grant' },
      { name: 'purpose', value: 'profilePhoto' },
      { name: 'file', value: Buffer.from('photo'), filename: 'photo.png' },
    ]);
    expect(response.statusCode).toBe(201);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(test.uploadOnboardingMedia.execute).toHaveBeenCalledWith({
      creationGrant: 'grant',
      installationProof: 'device-proof',
      purpose: 'profilePhoto',
      content: Buffer.from('photo'),
    });
    expect(test.authenticateSession.execute).not.toHaveBeenCalled();
  });

  it('rejects a client supplied family id and documents multipart without Bearer', async () => {
    const response = await upload([
      { name: 'creationGrant', value: 'grant' },
      { name: 'familyId', value: 'other-family' },
      { name: 'purpose', value: 'profilePhoto' },
      { name: 'file', value: Buffer.from('photo'), filename: 'photo.png' },
    ]);
    expect(response.statusCode).toBe(400);
    expect(response.json().code).toBe('UNKNOWN_FIELD');
    const docs = await test.app.inject({ method: 'GET', url: '/docs/json' });
    const operation = docs.json().paths['/v1/onboarding/media'].post;
    expect(operation.security ?? []).toEqual([]);
    expect(operation.requestBody.content['multipart/form-data']).toBeDefined();
  });
});
