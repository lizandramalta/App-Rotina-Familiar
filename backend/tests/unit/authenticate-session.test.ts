/** `AuthenticateSession`: o ator sai da sessão persistida, nunca do request (RNF06/07). */
import { createHash } from 'node:crypto';
import { describe, expect, it, vi } from 'vitest';
import { AuthenticateSessionUseCase } from '../../src/modules/access/application/authenticate-session-use-case.js';
import { AccessTokenInvalidError } from '../../src/modules/access/domain/access-errors.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const sha256 = (value: string): string => createHash('sha256').update(value).digest('hex');
const NOW = new Date('2026-10-08T12:00:00.000Z');

function build(lookupResult: typeof TEST_ACTOR | undefined) {
  const findActorByAccessTokenHash = vi.fn().mockResolvedValue(lookupResult);
  const useCase = new AuthenticateSessionUseCase({
    sessionLookup: { findActorByAccessTokenHash },
    crypto: { hashToken: sha256 },
    clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
  });
  return { useCase, findActorByAccessTokenHash };
}

describe('AuthenticateSessionUseCase', () => {
  it('looks the actor up by the token hash and the current time, never the raw token', async () => {
    const { useCase, findActorByAccessTokenHash } = build(TEST_ACTOR);

    const actor = await useCase.execute('opaque-access-token');

    expect(actor).toEqual(TEST_ACTOR);
    expect(findActorByAccessTokenHash).toHaveBeenCalledWith(sha256('opaque-access-token'), NOW);
  });

  it('rejects an unknown, expired or revoked token with ACCESS_TOKEN_INVALID', async () => {
    const { useCase } = build(undefined);

    const error = await useCase.execute('whatever').catch((e) => e);

    expect(error).toBeInstanceOf(AccessTokenInvalidError);
    expect(error).toMatchObject({ statusCode: 401, code: 'ACCESS_TOKEN_INVALID' });
  });

  it('rejects an empty token without querying the database', async () => {
    const { useCase, findActorByAccessTokenHash } = build(TEST_ACTOR);

    await expect(useCase.execute('')).rejects.toBeInstanceOf(AccessTokenInvalidError);
    expect(findActorByAccessTokenHash).not.toHaveBeenCalled();
  });
});
