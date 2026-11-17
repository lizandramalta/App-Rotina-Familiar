/**
 * Cifra reversível de segredos guardados pelo backend, como o refresh token
 * Apple (SPEC-001 Fase 4, BA-40). O valor decifrado só existe em memória durante
 * a revogação; nunca entra em log, resposta ou telemetria (RNF16).
 */
export interface SecretCipherPort {
  encrypt(plaintext: string): string;

  /** Lança erro se o valor foi alterado ou cifrado com outra chave. */
  decrypt(ciphertext: string): string;
}
