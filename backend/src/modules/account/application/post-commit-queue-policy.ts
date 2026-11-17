/** Lease de um item reivindicado; expirado, outro ciclo pode retomá-lo (BA-39/BA-40). */
export const QUEUE_LEASE_MS = 60_000;

const BASE_RETRY_DELAY_MS = 60_000;
const MAX_RETRY_DELAY_MS = 6 * 60 * 60 * 1000;

/**
 * Atraso crescente entre tentativas: 1, 2, 4... minutos, limitado a 6 horas.
 * `attempts` é o total de tentativas já feitas, incluindo a que acabou de falhar.
 */
export function nextRetryDelayMs(attempts: number): number {
  const exponent = Math.max(0, attempts - 1);
  return Math.min(BASE_RETRY_DELAY_MS * 2 ** exponent, MAX_RETRY_DELAY_MS);
}

/** Motivo sanitizado para persistir/registrar: nunca o valor de um token. */
export function sanitizedReason(error: unknown): string {
  const reason = error instanceof Error ? error.message : 'unknown_failure';
  return reason.slice(0, 200);
}
