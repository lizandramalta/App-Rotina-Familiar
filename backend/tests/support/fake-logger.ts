import { vi } from 'vitest';
import type { Logger } from '../../src/shared/infrastructure/observability/logger.js';

/** Logger que registra tudo o que recebe, para provar o que NÃO vaza (RNF08). */
export function createRecordingLogger(): { logger: Logger; calls: unknown[][] } {
  const calls: unknown[][] = [];
  const record =
    (...prefix: unknown[]) =>
    (...args: unknown[]) => {
      calls.push([...prefix, ...args]);
    };

  const logger = {
    trace: vi.fn(record('trace')),
    debug: vi.fn(record('debug')),
    info: vi.fn(record('info')),
    warn: vi.fn(record('warn')),
    error: vi.fn(record('error')),
    fatal: vi.fn(record('fatal')),
    child: vi.fn(),
  } as unknown as Logger;

  return { logger, calls };
}
