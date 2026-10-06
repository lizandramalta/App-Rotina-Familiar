import { config as loadDotenv } from 'dotenv';
import { z } from 'zod';
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

    // Integrations (optional for base phase)
    R2_ACCOUNT_ID: z.string().optional(),
    R2_ACCESS_KEY_ID: z.string().optional(),
    R2_SECRET_ACCESS_KEY: z.string().optional(),
    R2_BUCKET_NAME: z.string().optional(),
    R2_ENDPOINT: z.string().optional(),

    APPLE_CLIENT_ID: z.string().optional(),
    APPLE_TEAM_ID: z.string().optional(),
    APPLE_KEY_ID: z.string().optional(),
    APPLE_PRIVATE_KEY: z.string().optional(),

    APNS_KEY_ID: z.string().optional(),
    APNS_TEAM_ID: z.string().optional(),
    APNS_TOPIC: z.string().optional(),
    APNS_PRIVATE_KEY: z.string().optional(),
  })
  .refine(
    (data) => {
      // In production, enforce 32+ char secrets
      if (data.NODE_ENV === 'production') {
        return data.SESSION_SECRET.length >= 32 && data.INVITE_ENVELOPE_KEY.length >= 32;
      }
      return true;
    },
    {
      message:
        'In production, SESSION_SECRET and INVITE_ENVELOPE_KEY must have at least 32 characters.',
      path: ['SESSION_SECRET'],
    },
  );

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
