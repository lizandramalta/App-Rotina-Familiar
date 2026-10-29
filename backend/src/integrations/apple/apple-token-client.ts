import { createPrivateKey, createSign } from 'node:crypto';
import type { Logger } from '../../shared/infrastructure/observability/logger.js';
import { P256_CURVE_NAMES } from '../../bootstrap/configuration.js';
import type { AppleConfiguration } from './apple-configuration.js';
import type {
  AppleAuthorizationCodeExchange,
  AppleTokenExchangePort,
} from './apple-token-exchange-port.js';

/** A Apple aceita client secret com no máximo 6 meses; 5 minutos basta e expõe menos. */
const CLIENT_SECRET_TTL_SECONDS = 300;

/** A troca não pode prender a requisição do app indefinidamente. */
const EXCHANGE_TIMEOUT_MS = 10_000;

/**
 * Falha da troca do `authorizationCode`. O verificador a converte em recusa da
 * prova; a razão serve a log e teste, nunca à resposta HTTP.
 */
export class AppleTokenExchangeError extends Error {
  constructor(reason: string) {
    super(reason);
    this.name = 'AppleTokenExchangeError';
  }
}

interface AppleTokenResponse {
  readonly id_token?: string;
  readonly error?: string;
}

const base64url = (value: object): string =>
  Buffer.from(JSON.stringify(value)).toString('base64url');

/**
 * Cliente de troca do `authorizationCode` com a Apple (SPEC-001 §5.1).
 *
 * Assina o client secret em ES256 com a chave `.p8` e troca o código em
 * `APPLE_TOKEN_URL`. Qualquer recusa, inconsistência ou falha de rede é erro:
 * a troca falha fechada, nunca aceita o código por omissão.
 */
export class AppleTokenClient implements AppleTokenExchangePort {
  constructor(
    private readonly appleConfig: AppleConfiguration,
    private readonly logger: Logger,
    private readonly now: () => number = () => Date.now(),
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  public async exchangeAuthorizationCode(
    authorizationCode: string,
  ): Promise<AppleAuthorizationCodeExchange> {
    const clientSecret = this.buildClientSecret();

    let response: Response;
    try {
      response = await this.fetchImpl(this.appleConfig.tokenUrl, {
        method: 'POST',
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          accept: 'application/json',
        },
        body: new URLSearchParams({
          client_id: this.appleConfig.clientId,
          client_secret: clientSecret,
          code: authorizationCode,
          grant_type: 'authorization_code',
        }).toString(),
        signal: AbortSignal.timeout(EXCHANGE_TIMEOUT_MS),
      });
    } catch (error) {
      // Rede indisponível ou timeout: a prova não pode ser considerada válida.
      // A mensagem original pode conter URL e detalhe de socket, não o código.
      this.logger.warn('apple_token_exchange_unreachable', {
        reason: error instanceof Error ? error.name : 'unknown_transport_failure',
      });
      throw new AppleTokenExchangeError('apple_token_exchange_unreachable');
    }

    if (!response.ok) {
      // O corpo de erro da Apple traz apenas um código (`invalid_grant`), mas
      // nunca é propagado à resposta HTTP do nosso backend.
      const reason = await this.readErrorCode(response);
      this.logger.warn('apple_token_exchange_rejected', {
        status: response.status,
        appleError: reason,
      });
      throw new AppleTokenExchangeError('apple_token_exchange_rejected');
    }

    let payload: AppleTokenResponse;
    try {
      payload = (await response.json()) as AppleTokenResponse;
    } catch {
      throw new AppleTokenExchangeError('apple_token_exchange_response_not_decodable');
    }

    return { subject: this.readIdTokenSubject(payload.id_token) };
  }

  /**
   * Em `development`/`test` as credenciais da Apple são opcionais (SCRUM-11),
   * então podem faltar aqui. Falhar é a única saída segura: seguir sem a troca
   * aceitaria qualquer `authorizationCode`.
   */
  private buildClientSecret(): string {
    const { teamId, keyId, privateKeyPem, clientId, issuer } = this.appleConfig;

    if (teamId === undefined || keyId === undefined || privateKeyPem === undefined) {
      throw new AppleTokenExchangeError('apple_token_exchange_credentials_missing');
    }

    const issuedAt = Math.floor(this.now() / 1000);
    const encodedHeader = base64url({ alg: 'ES256', kid: keyId, typ: 'JWT' });
    const encodedPayload = base64url({
      iss: teamId,
      iat: issuedAt,
      exp: issuedAt + CLIENT_SECRET_TTL_SECONDS,
      aud: issuer,
      sub: clientId,
    });

    let signingKey;
    try {
      signingKey = createPrivateKey({ key: privateKeyPem, format: 'pem' });
    } catch {
      // A exceção pode carregar material da chave; não propagar nem registrar.
      throw new AppleTokenExchangeError('apple_token_exchange_client_secret_not_signable');
    }

    // ES256 exige chave EC. Com uma chave RSA o Node assina sem reclamar e
    // ignora `dsaEncoding`, produzindo um JWT que a Apple recusaria com um erro
    // opaco; falhar aqui diz qual é o problema de configuração.
    if (signingKey.asymmetricKeyType !== 'ec') {
      throw new AppleTokenExchangeError('apple_token_exchange_client_secret_key_not_ec');
    }

    // Ser EC não basta: ES256 é ECDSA com P-256 e SHA-256 (RFC 7518 §3.4). Uma
    // chave secp384r1/secp521r1 geraria assinatura de 96 ou 132 bytes sob um
    // header que declara ES256 (64 bytes), e a Apple recusa categoricamente.
    const curve = signingKey.asymmetricKeyDetails?.namedCurve;
    if (curve === undefined || !P256_CURVE_NAMES.has(curve)) {
      throw new AppleTokenExchangeError('apple_token_exchange_client_secret_key_not_p256');
    }

    try {
      const signer = createSign('SHA256');
      signer.update(`${encodedHeader}.${encodedPayload}`);
      signer.end();

      // JOSE exige a assinatura ECDSA crua (r||s); o default do Node é DER.
      const signature = signer.sign({ key: signingKey, dsaEncoding: 'ieee-p1363' });

      return `${encodedHeader}.${encodedPayload}.${signature.toString('base64url')}`;
    } catch {
      throw new AppleTokenExchangeError('apple_token_exchange_client_secret_not_signable');
    }
  }

  private async readErrorCode(response: Response): Promise<string> {
    try {
      const body = (await response.json()) as AppleTokenResponse;
      return body.error ?? 'unspecified';
    } catch {
      return 'unspecified';
    }
  }

  private readIdTokenSubject(idToken: string | undefined): string | undefined {
    if (idToken === undefined) {
      return undefined;
    }

    const encodedPayload = idToken.split('.')[1];
    if (encodedPayload === undefined) {
      return undefined;
    }

    try {
      const payload = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf8')) as {
        sub?: unknown;
      };

      return typeof payload.sub === 'string' ? payload.sub : undefined;
    } catch {
      return undefined;
    }
  }
}
