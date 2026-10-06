export type LogLevel = 'trace' | 'debug' | 'info' | 'warn' | 'error' | 'fatal';

export interface Logger {
  trace(message: string, context?: Record<string, unknown>): void;
  debug(message: string, context?: Record<string, unknown>): void;
  info(message: string, context?: Record<string, unknown>): void;
  warn(message: string, context?: Record<string, unknown>): void;
  error(message: string, error?: Error | unknown, context?: Record<string, unknown>): void;
  fatal(message: string, error?: Error | unknown, context?: Record<string, unknown>): void;
  child(bindings: Record<string, unknown>): Logger;
}

const SENSITIVE_KEYS = new Set([
  'authorization',
  'refreshtoken',
  'refresh_token',
  'password',
  'invitetoken',
  'invite_token',
  'installationsecret',
  'installation_secret',
  'appleproof',
  'apple_proof',
  'clientsecret',
  'sessionsecret',
  'envelopekey',
]);

/**
 * Sanitizes object keys to prevent sensitive tokens and credentials from leaking in logs.
 */
export function sanitizeLogContext(obj: unknown, depth = 0): unknown {
  if (depth > 5 || obj === null || obj === undefined) {
    return obj;
  }

  if (typeof obj !== 'object') {
    return obj;
  }

  if (Array.isArray(obj)) {
    return obj.map((item) => sanitizeLogContext(item, depth + 1));
  }

  const sanitized: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
    const normalizedKey = key.toLowerCase().replace(/[-_]/g, '');
    if (SENSITIVE_KEYS.has(normalizedKey)) {
      sanitized[key] = '[REDACTED]';
    } else if (typeof value === 'object' && value !== null) {
      sanitized[key] = sanitizeLogContext(value, depth + 1);
    } else {
      sanitized[key] = value;
    }
  }

  return sanitized;
}

const LOG_LEVEL_SEVERITY: Record<LogLevel, number> = {
  trace: 10,
  debug: 20,
  info: 30,
  warn: 40,
  error: 50,
  fatal: 60,
};

export class ConsoleLogger implements Logger {
  private readonly minSeverity: number;
  private readonly defaultBindings: Record<string, unknown>;

  constructor(minLevel: LogLevel = 'info', defaultBindings: Record<string, unknown> = {}) {
    this.minSeverity = LOG_LEVEL_SEVERITY[minLevel] ?? LOG_LEVEL_SEVERITY.info;
    this.defaultBindings = defaultBindings;
  }

  private output(
    level: LogLevel,
    message: string,
    extra?: Record<string, unknown>,
    err?: unknown,
  ): void {
    if (LOG_LEVEL_SEVERITY[level] < this.minSeverity) {
      return;
    }

    const payload: Record<string, unknown> = {
      timestamp: new Date().toISOString(),
      level,
      message,
      ...this.defaultBindings,
    };

    if (extra) {
      Object.assign(payload, sanitizeLogContext(extra));
    }

    if (err instanceof Error) {
      payload.error = {
        name: err.name,
        message: err.message,
        stack: err.stack,
      };
    } else if (err) {
      payload.error = String(err);
    }

    const json = JSON.stringify(payload);
    if (level === 'error' || level === 'fatal') {
      console.error(json);
    } else if (level === 'warn') {
      console.warn(json);
    } else {
      console.log(json);
    }
  }

  public trace(message: string, context?: Record<string, unknown>): void {
    this.output('trace', message, context);
  }

  public debug(message: string, context?: Record<string, unknown>): void {
    this.output('debug', message, context);
  }

  public info(message: string, context?: Record<string, unknown>): void {
    this.output('info', message, context);
  }

  public warn(message: string, context?: Record<string, unknown>): void {
    this.output('warn', message, context);
  }

  public error(message: string, error?: Error | unknown, context?: Record<string, unknown>): void {
    this.output('error', message, context, error);
  }

  public fatal(message: string, error?: Error | unknown, context?: Record<string, unknown>): void {
    this.output('fatal', message, context, error);
  }

  public child(bindings: Record<string, unknown>): Logger {
    return new ConsoleLogger(
      Object.keys(LOG_LEVEL_SEVERITY).find(
        (lvl) => LOG_LEVEL_SEVERITY[lvl as LogLevel] === this.minSeverity,
      ) as LogLevel,
      { ...this.defaultBindings, ...bindings },
    );
  }
}
