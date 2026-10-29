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

/**
 * Chaves comparadas já normalizadas (minúsculas, sem `-` e `_`), por isso uma
 * única entrada cobre `APPLE_PRIVATE_KEY`, `apple_private_key` e `applePrivateKey`.
 * As provas da Apple e o header `X-Installation-Proof` nunca podem ser
 * registrados (SPEC-001, RNF08, RNF16).
 */
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

  // Sign in with Apple (SPEC-001)
  'appleprivatekey',
  'applekey',
  'identitytoken',
  'authorizationcode',
  'rawnonce',
  'installationproof',
  'xinstallationproof',
]);

const MAX_SANITIZE_DEPTH = 5;

const REDACTED = '[REDACTED]';

function isSensitiveKey(key: string): boolean {
  return SENSITIVE_KEYS.has(key.toLowerCase().replace(/[-_]/g, ''));
}

/** Bloco PEM completo e também um bloco truncado, sem o delimitador final. */
const PEM_BLOCK_PATTERN =
  /-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)/g;

/** JWT compacto, formato do `identityToken` da Apple. */
const JWT_PATTERN = /\beyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]+/g;

/**
 * Credencial precedida de esquema de autorização, com ou sem aspas. Vale também
 * sem chave antes (`invalid token: Bearer abc123`), caso em que a regra de
 * `chave=valor` não alcançaria a credencial.
 *
 * A credencial precisa conter dígito, `_` ou símbolo: sem essa exigência,
 * `Basic validation failed` seria redigido como se `validation` fosse segredo.
 * Uma credencial só de letras depois do esquema continua coberta pela regra de
 * `chave=valor`, que absorve o esquema e os termos seguintes.
 *
 * A aspa de fechamento é consumida apenas quando a de abertura também pertence à
 * credencial, via retrorreferência — assim `authorization="Bearer x1"` não perde
 * a aspa de fechamento do valor externo.
 */
const AUTH_SCHEME_PATTERN =
  /\b(?:Bearer|Basic|Digest)\s+(["'])?(?=[\w.~+/=-]*[0-9_.~+/=-])[\w.~+/=-]+\1?/gi;

/**
 * Primeiro termo de um valor sem aspas: consome caractere a caractere, mas se
 * recusa a começar onde um novo `chave=` começa. Sem essa recusa, o valor de uma
 * chave inofensiva engoliria a chave sensível seguinte junto com o separador dela
 * (`context: rawNonce='segredo'`), e o par sensível nunca seria examinado.
 */
const BARE_VALUE_HEAD = String.raw`(?:(?![A-Za-z][A-Za-z0-9_-]*\s*[:=])[^\s,;})"'])+`;

/**
 * Termos seguintes do mesmo valor, separados por espaço. Uma credencial pode ter
 * espaço no meio (`Authorization: Bearer <token>`): parar no primeiro espaço
 * redigiria só o esquema e deixaria a credencial atrás. A absorção para em um
 * termo que seja outro par `chave=valor`, para não esconder da varredura um par
 * sensível seguinte — e é inofensiva para chave não sensível, cujo trecho é
 * devolvido sem alteração.
 */
const BARE_VALUE_TAIL = String.raw`(?:[ \t]+(?![A-Za-z][A-Za-z0-9_-]*\s*[:=])[^\s,;})"']+)*`;

/**
 * `chave=valor` e `chave: valor`, com o valor entre aspas simples, entre aspas
 * duplas ou sem aspas. Um valor citado é capturado até a aspa de fechamento.
 */
const KEY_VALUE_PATTERN = new RegExp(
  String.raw`([A-Za-z][A-Za-z0-9_-]*)(\s*[:=]\s*)(?:(["'])([^"']*)\3|${BARE_VALUE_HEAD}${BARE_VALUE_TAIL})`,
  'g',
);

/**
 * Redige segredos em texto livre — `message`, `error.name`, `error.message` e
 * `error.stack` não têm chaves para inspecionar, então a varredura é por valor:
 * bloco PEM, JWT, credencial com esquema de autorização e `chaveSensivel=valor`.
 * Uma mensagem como `new Error('identityToken=' + token)` sairia em claro sem isso.
 */
export function redactSensitiveText(text: string): string {
  return text
    .replace(PEM_BLOCK_PATTERN, REDACTED)
    .replace(JWT_PATTERN, REDACTED)
    .replace(AUTH_SCHEME_PATTERN, REDACTED)
    .replace(
      KEY_VALUE_PATTERN,
      (match, key: string, separator: string, quote: string | undefined) => {
        if (!isSensitiveKey(key)) {
          return match;
        }

        const wrap = quote ?? '';
        return `${key}${separator}${wrap}${REDACTED}${wrap}`;
      },
    );
}

/**
 * Sanitizes object keys to prevent sensitive tokens and credentials from leaking in logs.
 */
export function sanitizeLogContext(obj: unknown, depth = 0): unknown {
  // A checagem de profundidade vem antes de qualquer atalho: devolver o valor
  // bruto aqui vazaria tanto um objeto quanto uma string com segredo aninhada
  // além do limite.
  if (depth > MAX_SANITIZE_DEPTH) {
    return '[TRUNCATED]';
  }

  if (obj === null || obj === undefined) {
    return obj;
  }

  if (typeof obj === 'string') {
    return redactSensitiveText(obj);
  }

  if (typeof obj !== 'object') {
    return obj;
  }

  if (Array.isArray(obj)) {
    return obj.map((item) => sanitizeLogContext(item, depth + 1));
  }

  const sanitized: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
    sanitized[key] = isSensitiveKey(key) ? REDACTED : sanitizeLogContext(value, depth + 1);
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
    // Sanitizar uma vez na construção, e não a cada log: os bindings são
    // imutáveis e `child` reconstrói o logger, então o resultado mesclado em
    // `output` já está redigido. A redação é idempotente.
    this.defaultBindings = sanitizeLogContext(defaultBindings) as Record<string, unknown>;
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
      // A mensagem é texto livre montado no ponto de chamada e pode carregar um
      // segredo interpolado.
      message: redactSensitiveText(message),
      ...this.defaultBindings,
    };

    if (extra) {
      Object.assign(payload, sanitizeLogContext(extra) as Record<string, unknown>);
    }

    if (err instanceof Error) {
      payload.error = {
        // `name` também é texto livre: um erro customizado pode trazer segredo nele.
        name: redactSensitiveText(err.name),
        message: redactSensitiveText(err.message),
        stack: err.stack === undefined ? undefined : redactSensitiveText(err.stack),
      };
    } else if (err) {
      payload.error = redactSensitiveText(String(err));
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
