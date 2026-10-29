import type { Logger } from '../../shared/infrastructure/observability/logger.js';
import type { AppleConfiguration } from './apple-configuration.js';
import type { AppleJsonWebKey, AppleJwksPort } from './apple-jwks-port.js';

/** As chaves públicas da Apple mudam raramente; 24h é o intervalo usual. */
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

interface JwksResponse {
  readonly keys?: readonly AppleJsonWebKey[];
}

/**
 * Cliente do JWKS da Apple com cache em memória.
 *
 * Em cache miss de `kid` o JWKS é rebuscado antes de desistir: a Apple faz
 * rotação de chaves, e um `kid` novo não pode exigir reinício do processo.
 */
export class AppleJwksClient implements AppleJwksPort {
  private cachedKeys: readonly AppleJsonWebKey[] = [];
  private cacheExpiresAt = 0;
  private inFlight?: Promise<readonly AppleJsonWebKey[]>;

  constructor(
    private readonly appleConfig: AppleConfiguration,
    private readonly logger: Logger,
    private readonly now: () => number = () => Date.now(),
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  public async findSigningKey(kid: string): Promise<AppleJsonWebKey | undefined> {
    const cached = this.findInCache(kid);
    if (cached !== undefined) {
      return cached;
    }

    const keys = await this.refresh();
    return keys.find((key) => key.kid === kid);
  }

  private findInCache(kid: string): AppleJsonWebKey | undefined {
    if (this.now() >= this.cacheExpiresAt) {
      return undefined;
    }

    return this.cachedKeys.find((key) => key.kid === kid);
  }

  /**
   * Busca única por rajada: várias verificações concorrentes em cache miss
   * compartilham a mesma requisição em vez de disparar uma cada.
   */
  private async refresh(): Promise<readonly AppleJsonWebKey[]> {
    this.inFlight ??= this.fetchKeys().finally(() => {
      this.inFlight = undefined;
    });

    return this.inFlight;
  }

  private async fetchKeys(): Promise<readonly AppleJsonWebKey[]> {
    const response = await this.fetchImpl(this.appleConfig.jwksUrl, {
      method: 'GET',
      headers: { accept: 'application/json' },
    });

    if (!response.ok) {
      throw new Error(`Apple JWKS request failed with status ${response.status}`);
    }

    const payload = (await response.json()) as JwksResponse;
    const keys = payload.keys ?? [];

    if (keys.length === 0) {
      throw new Error('Apple JWKS response contained no keys');
    }

    this.cachedKeys = keys;
    this.cacheExpiresAt = this.now() + CACHE_TTL_MS;
    this.logger.debug('Apple JWKS cache refreshed', { keyCount: keys.length });

    return keys;
  }
}
