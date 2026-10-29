import {
  createHash,
  createPublicKey,
  createVerify,
  timingSafeEqual,
  type JsonWebKey,
} from 'node:crypto';
import type { AppleConfiguration } from './apple-configuration.js';
import type { AppleJsonWebKey, AppleJwksPort } from './apple-jwks-port.js';
import type { AppleTokenExchangePort } from './apple-token-exchange-port.js';
import type {
  AppleIdentityProof,
  AppleTokenVerifierPort,
  VerifiedAppleIdentity,
} from './apple-token-verifier-port.js';

/** Tolerância de relógio na checagem de validade do token. */
const CLOCK_SKEW_TOLERANCE_SECONDS = 60;

interface IdentityTokenHeader {
  readonly alg?: string;
  readonly kid?: string;
}

interface IdentityTokenPayload {
  readonly iss?: string;
  readonly aud?: string | readonly string[];
  readonly sub?: string;
  readonly exp?: number;
  readonly iat?: number;
  readonly nonce?: string;
  readonly email?: string;
  readonly email_verified?: boolean | string;
  readonly is_private_email?: boolean | string;
}

/**
 * Erro interno da verificação. O caso de uso o converte em
 * `AppleProofInvalidError`; a razão serve a log e teste, nunca à resposta.
 */
export class AppleProofVerificationError extends Error {
  constructor(reason: string) {
    super(reason);
    this.name = 'AppleProofVerificationError';
  }
}

function decodeSegment(segment: string, what: string): unknown {
  try {
    return JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'));
  } catch {
    throw new AppleProofVerificationError(`identity_token_${what}_not_decodable`);
  }
}

function asBoolean(value: boolean | string | undefined): boolean | undefined {
  if (value === undefined) {
    return undefined;
  }

  return value === true || value === 'true';
}

/** Comparação de tamanho fixo, para o resultado não depender do tempo gasto. */
function equalsConstantTime(left: string, right: string): boolean {
  const leftDigest = createHash('sha256').update(left).digest();
  const rightDigest = createHash('sha256').update(right).digest();

  return timingSafeEqual(leftDigest, rightDigest);
}

/**
 * Verificador da prova Apple (SPEC-001 §5.1).
 *
 * Confere assinatura RS256 contra a chave pública do JWKS, emissor, audiência,
 * validade e correspondência do `rawNonce`; em seguida troca o
 * `authorizationCode` com a Apple e exige que o `sub` devolvido na troca seja o
 * mesmo do `identityToken`. As duas metades da prova precisam pertencer à mesma
 * autenticação.
 */
export class AppleTokenVerifier implements AppleTokenVerifierPort {
  constructor(
    private readonly appleConfig: AppleConfiguration,
    private readonly jwks: AppleJwksPort,
    private readonly tokenExchange: AppleTokenExchangePort,
    private readonly now: () => number = () => Date.now(),
  ) {}

  public async verifyIdentityProof(proof: AppleIdentityProof): Promise<VerifiedAppleIdentity> {
    // A prova é indivisível: a spec não aceita `authorizationCode` sem o
    // `identityToken` correspondente, nem nonce ausente.
    if (proof.identityToken.length === 0) {
      throw new AppleProofVerificationError('identity_token_missing');
    }
    if (proof.authorizationCode.length === 0) {
      throw new AppleProofVerificationError('authorization_code_missing');
    }
    if (proof.rawNonce.length === 0) {
      throw new AppleProofVerificationError('raw_nonce_missing');
    }

    const segments = proof.identityToken.split('.');
    if (segments.length !== 3) {
      throw new AppleProofVerificationError('identity_token_malformed');
    }

    const [encodedHeader, encodedPayload, encodedSignature] = segments as [string, string, string];
    const header = decodeSegment(encodedHeader, 'header') as IdentityTokenHeader;

    if (header.alg !== 'RS256') {
      throw new AppleProofVerificationError('identity_token_unexpected_algorithm');
    }
    if (header.kid === undefined || header.kid.length === 0) {
      throw new AppleProofVerificationError('identity_token_missing_kid');
    }

    const signingKey = await this.jwks.findSigningKey(header.kid);
    if (signingKey === undefined) {
      throw new AppleProofVerificationError('identity_token_unknown_kid');
    }

    this.assertSignature({ encodedHeader, encodedPayload, encodedSignature, signingKey });

    const payload = decodeSegment(encodedPayload, 'payload') as IdentityTokenPayload;
    this.assertClaims(payload);
    this.assertNonce(payload, proof.rawNonce);

    const subject = payload.sub;
    if (subject === undefined || subject.length === 0) {
      throw new AppleProofVerificationError('identity_token_missing_subject');
    }

    // A troca vem depois da verificação local: um identityToken inválido é
    // recusado sem gastar uma chamada de rede à Apple.
    await this.assertAuthorizationCodeBelongsToSubject(proof.authorizationCode, subject);

    return {
      subject,
      email: payload.email,
      isEmailVerified: asBoolean(payload.email_verified),
      isPrivateEmail: asBoolean(payload.is_private_email),
    };
  }

  /**
   * Troca o `authorizationCode` com a Apple e confere o titular. Qualquer
   * recusa, indisponibilidade ou divergência de `sub` invalida a prova inteira
   * (CA-04): aceitar um código não verificado permitiria combinar a prova de
   * uma autenticação com o código de outra.
   */
  private async assertAuthorizationCodeBelongsToSubject(
    authorizationCode: string,
    identityTokenSubject: string,
  ): Promise<void> {
    let exchangedSubject: string | undefined;

    try {
      const exchange = await this.tokenExchange.exchangeAuthorizationCode(authorizationCode);
      exchangedSubject = exchange.subject;
    } catch (error) {
      throw new AppleProofVerificationError(
        error instanceof Error ? error.message : 'authorization_code_exchange_failed',
      );
    }

    if (exchangedSubject === undefined || exchangedSubject.length === 0) {
      throw new AppleProofVerificationError('authorization_code_exchange_missing_subject');
    }

    if (!equalsConstantTime(exchangedSubject, identityTokenSubject)) {
      throw new AppleProofVerificationError('authorization_code_subject_mismatch');
    }
  }

  private assertSignature(params: {
    readonly encodedHeader: string;
    readonly encodedPayload: string;
    readonly encodedSignature: string;
    readonly signingKey: AppleJsonWebKey;
  }): void {
    // Conversão campo a campo em vez de cast: `AppleJsonWebKey` descreve o que
    // a Apple publica, e `JsonWebKey` do Node tem índice aberto.
    const jwk: JsonWebKey = {
      kty: params.signingKey.kty,
      n: params.signingKey.n,
      e: params.signingKey.e,
      alg: params.signingKey.alg,
      kid: params.signingKey.kid,
      use: params.signingKey.use,
    };

    let publicKey;
    try {
      publicKey = createPublicKey({ key: jwk, format: 'jwk' });
    } catch {
      throw new AppleProofVerificationError('jwks_key_not_usable');
    }

    const verifier = createVerify('RSA-SHA256');
    verifier.update(`${params.encodedHeader}.${params.encodedPayload}`);
    verifier.end();

    const isValid = verifier.verify(publicKey, Buffer.from(params.encodedSignature, 'base64url'));
    if (!isValid) {
      throw new AppleProofVerificationError('identity_token_signature_invalid');
    }
  }

  private assertClaims(payload: IdentityTokenPayload): void {
    if (payload.iss !== this.appleConfig.issuer) {
      throw new AppleProofVerificationError('identity_token_unexpected_issuer');
    }

    const audiences = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
    if (!audiences.includes(this.appleConfig.clientId)) {
      throw new AppleProofVerificationError('identity_token_unexpected_audience');
    }

    if (typeof payload.exp !== 'number') {
      throw new AppleProofVerificationError('identity_token_missing_expiration');
    }

    const nowSeconds = Math.floor(this.now() / 1000);
    if (payload.exp + CLOCK_SKEW_TOLERANCE_SECONDS <= nowSeconds) {
      throw new AppleProofVerificationError('identity_token_expired');
    }

    if (
      typeof payload.iat === 'number' &&
      payload.iat - CLOCK_SKEW_TOLERANCE_SECONDS > nowSeconds
    ) {
      throw new AppleProofVerificationError('identity_token_issued_in_the_future');
    }
  }

  /**
   * O app envia o nonce em claro e a Apple devolve o hash dele no token. Hex e
   * base64url são aceitos porque as duas codificações circulam nos exemplos da
   * Apple e ambas derivam do mesmo SHA-256 — aceitar as duas evita recusar uma
   * prova legítima por divergência de formatação.
   */
  private assertNonce(payload: IdentityTokenPayload, rawNonce: string): void {
    if (payload.nonce === undefined || payload.nonce.length === 0) {
      throw new AppleProofVerificationError('identity_token_missing_nonce');
    }

    const digest = createHash('sha256').update(rawNonce).digest();
    const matches =
      equalsConstantTime(payload.nonce, digest.toString('hex')) ||
      equalsConstantTime(payload.nonce, digest.toString('base64url'));

    if (!matches) {
      throw new AppleProofVerificationError('identity_token_nonce_mismatch');
    }
  }
}
