import { config as loadDotenv } from 'dotenv';
import { z } from 'zod';
import { createPrivateKey, type KeyObject } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

export class ConfigurationError extends Error {
  public readonly issues: z.ZodIssue[];

  constructor(message: string, issues: z.ZodIssue[] = []) {
    super(message);
    this.name = 'ConfigurationError';
    this.issues = issues;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

/**
 * Arquivos .env guardam a chave em uma única linha, com "\n" literal no lugar das
 * quebras. Normalizar antes de validar e antes de usar evita exigir formatação
 * diferente entre `.env` e variáveis injetadas pela plataforma.
 */
export function normalizePrivateKeyPem(value: string): string {
  return value
    .trim()
    .replace(/^["']|["']$/g, '')
    .replace(/\\r\\n|\\n|\\r/g, '\n')
    .trim();
}

/**
 * Delimitadores corretos não garantem uma chave utilizável: um .p8 truncado ou
 * com base64 corrompido passa por qualquer regex e só falha ao assinar o client
 * secret, em produção. Deixar o Node tentar interpretar a chave é a única
 * verificação que prova que ela serve.
 */
/**
 * Nomes com que o Node identifica a curva NIST P-256. ES256 é definido como
 * ECDSA com P-256 e SHA-256 (RFC 7518 §3.4): qualquer outra curva produz
 * assinatura de tamanho diferente e a Apple recusa.
 */
export const P256_CURVE_NAMES: ReadonlySet<string> = new Set(['prime256v1', 'p256', 'secp256r1']);

function privateKeyFromPem(value: string): KeyObject | undefined {
  try {
    return createPrivateKey({ key: normalizePrivateKeyPem(value), format: 'pem' });
  } catch {
    // A exceção carrega detalhes do material da chave; não propagar nem registrar.
    return undefined;
  }
}

function isPrivateKeyPem(value: string): boolean {
  return privateKeyFromPem(value) !== undefined;
}

/** Chave efetivamente utilizável para assinar o client secret ES256 da Apple. */
function isP256PrivateKeyPem(value: string): boolean {
  const key = privateKeyFromPem(value);

  if (key === undefined || key.asymmetricKeyType !== 'ec') {
    return false;
  }

  const curve = key.asymmetricKeyDetails?.namedCurve;
  return curve !== undefined && P256_CURVE_NAMES.has(curve);
}

/**
 * Trata variável ausente e string vazia como "não informada", para que um
 * placeholder vazio no .env local não derrube o boot em development/test.
 */
function optionalEnv<T extends z.ZodTypeAny>(schema: T) {
  return z.preprocess(
    (value) => (typeof value === 'string' && value.trim() === '' ? undefined : value),
    schema.optional(),
  );
}

/** Team ID e Key ID da Apple têm exatamente 10 caracteres alfanuméricos. */
const appleIdentifierSchema = z
  .string()
  .length(10, 'must have exactly 10 characters')
  .regex(/^[A-Za-z0-9]{10}$/, 'must contain only alphanumeric characters');

const APPLE_PRODUCTION_REQUIRED_KEYS = [
  'APPLE_TEAM_ID',
  'APPLE_KEY_ID',
  'APPLE_PRIVATE_KEY',
] as const;

/**
 * Endpoints oficiais da Apple. Sobrescrever é legítimo apenas para apontar a um
 * stub em development/test; em production um host diferente significaria
 * conferir a prova de identidade contra uma origem não confiável.
 */
const APPLE_CANONICAL_URLS = {
  APPLE_ISSUER: 'https://appleid.apple.com',
  APPLE_JWKS_URL: 'https://appleid.apple.com/auth/keys',
  APPLE_TOKEN_URL: 'https://appleid.apple.com/auth/token',
} as const;

const environmentSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().min(1024).max(65535).default(3000),
    HOST: z.string().default('0.0.0.0'),
    API_BASE_URL: z.string().url().default('http://localhost:3000'),
    LOG_LEVEL: z.enum(['trace', 'debug', 'info', 'warn', 'error', 'fatal']).default('info'),

    // Supabase PostgreSQL Configuration (BA-01, BA-05, BA-19)
    DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
    DATABASE_SCHEMA: z.string().min(1).default('app'),
    DATABASE_POOL_MIN: z.coerce.number().int().min(1).default(2),
    DATABASE_POOL_MAX: z.coerce.number().int().min(2).default(10),
    DATABASE_SSL: z
      .string()
      .optional()
      .transform((val) => val === 'true' || val === '1'),

    // Session and invite recovery keys (BA-10, BA-11)
    SESSION_SECRET: z
      .string()
      .min(16, 'SESSION_SECRET must be at least 16 characters for dev and 32 in production')
      .default('development-session-secret-change-in-production-min-32-chars!'),
    INVITE_ENVELOPE_KEY: z
      .string()
      .min(16, 'INVITE_ENVELOPE_KEY must be at least 16 characters for dev and 32 in production')
      .default('0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'),

    // Base pública do link de convite (SPEC-004). O padrão é um domínio reservado
    // (RFC 2606) que nunca resolve: serve a dev/test, e em production é recusado.
    INVITE_LINK_BASE_URL: z.string().url().default('https://example.invalid'),

    // Limite de tentativas do ingresso por convite (SPEC-005, RNF21, BA-29). A
    // senha tem poucos bits; este limite é o que a protege contra adivinhação.
    INVITE_ATTEMPT_LIMIT: z.coerce.number().int().min(1).default(5),
    INVITE_ORIGIN_ATTEMPT_LIMIT: z.coerce.number().int().min(1).default(30),
    INVITE_ATTEMPT_WINDOW_MINUTES: z.coerce.number().int().min(1).default(15),

    // Atrás de proxy, `request.ip` só reflete o cliente real com isto ligado.
    // Padrão desligado: confiar em `X-Forwarded-For` sem proxy permite forjá-lo.
    TRUST_PROXY: z
      .string()
      .optional()
      .transform((val) => val === 'true' || val === '1'),

    // Integrations (optional for base phase)
    R2_ACCOUNT_ID: z.string().optional(),
    R2_ACCESS_KEY_ID: z.string().optional(),
    R2_SECRET_ACCESS_KEY: z.string().optional(),
    R2_BUCKET_NAME: z.string().optional(),
    R2_ENDPOINT: z.string().optional(),

    // Sign in with Apple (BA-04, SPEC-001). Em development/test as credenciais
    // reais são opcionais para não bloquear o boot local; em production a
    // validação é estrita (ver superRefine abaixo).
    APPLE_CLIENT_ID: z.string().min(1).default('com.lizandramalta.mutua'),
    APPLE_TEAM_ID: optionalEnv(appleIdentifierSchema),
    APPLE_KEY_ID: optionalEnv(appleIdentifierSchema),
    APPLE_PRIVATE_KEY: optionalEnv(
      z.string().refine(isPrivateKeyPem, 'must be a PEM-encoded private key'),
    ),
    APPLE_ISSUER: z.string().url().default(APPLE_CANONICAL_URLS.APPLE_ISSUER),
    APPLE_JWKS_URL: z.string().url().default(APPLE_CANONICAL_URLS.APPLE_JWKS_URL),
    APPLE_TOKEN_URL: z.string().url().default(APPLE_CANONICAL_URLS.APPLE_TOKEN_URL),

    APNS_KEY_ID: z.string().optional(),
    APNS_TEAM_ID: z.string().optional(),
    APNS_TOPIC: z.string().optional(),
    APNS_PRIVATE_KEY: z.string().optional(),
  })
  .superRefine((data, ctx) => {
    if (data.NODE_ENV !== 'production') {
      return;
    }

    if (data.SESSION_SECRET.length < 32 || data.INVITE_ENVELOPE_KEY.length < 32) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message:
          'In production, SESSION_SECRET and INVITE_ENVELOPE_KEY must have at least 32 characters.',
        path: ['SESSION_SECRET'],
      });
    }

    // Um link apontando para o domínio reservado entregaria convites inúteis.
    if (new URL(data.INVITE_LINK_BASE_URL).hostname.endsWith('.invalid')) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'INVITE_LINK_BASE_URL must be a real public URL in production.',
        path: ['INVITE_LINK_BASE_URL'],
      });
    }

    for (const key of APPLE_PRODUCTION_REQUIRED_KEYS) {
      if (data[key] === undefined) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: `${key} is required in production for Sign in with Apple.`,
          path: [key],
        });
      }
    }

    // Em produção a chave precisa ser utilizável de fato: uma chave RSA ou EC de
    // outra curva passa como PEM válido, mas produziria um client secret que a
    // Apple recusa, derrubando toda autenticação em runtime em vez do boot.
    if (data.APPLE_PRIVATE_KEY !== undefined && !isP256PrivateKeyPem(data.APPLE_PRIVATE_KEY)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message:
          'APPLE_PRIVATE_KEY must be an EC private key on the P-256 curve in production, as required by the ES256 client secret.',
        path: ['APPLE_PRIVATE_KEY'],
      });
    }

    for (const [key, canonicalUrl] of Object.entries(APPLE_CANONICAL_URLS)) {
      if (data[key as keyof typeof APPLE_CANONICAL_URLS] !== canonicalUrl) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: `${key} must be the canonical Apple endpoint ${canonicalUrl} in production.`,
          path: [key],
        });
      }
    }
  });

export type Configuration = z.infer<typeof environmentSchema>;

/**
 * Validates a dictionary of environment variables with fail-fast behavior.
 */
export function validateConfiguration(rawEnv: Record<string, unknown>): Configuration {
  const result = environmentSchema.safeParse(rawEnv);

  if (!result.success) {
    const errorDetails = result.error.issues
      .map((issue) => `  - [${issue.path.join('.') || 'root'}]: ${issue.message}`)
      .join('\n');

    throw new ConfigurationError(
      `Fail-fast: Environment configuration validation failed:\n${errorDetails}`,
      result.error.issues,
    );
  }

  return result.data;
}

/**
 * Loads environment variables from .env files (.env.test in test, .env otherwise)
 * and performs strict fail-fast validation.
 */
export function loadConfiguration(): Configuration {
  const nodeEnv = process.env.NODE_ENV || 'development';

  if (nodeEnv === 'test') {
    const envTestPath = resolve(process.cwd(), '.env.test');
    if (existsSync(envTestPath)) {
      loadDotenv({ path: envTestPath });
    }
  } else {
    const envPath = resolve(process.cwd(), '.env');
    if (existsSync(envPath)) {
      loadDotenv({ path: envPath });
    }
  }

  // Fallback defaults for test environment to allow unit tests without local Postgres
  if (process.env.NODE_ENV === 'test' && !process.env.DATABASE_URL) {
    process.env.DATABASE_URL = 'postgresql://postgres:postgres@localhost:54322/postgres_test';
  }

  return validateConfiguration(process.env);
}
