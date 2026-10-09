/**
 * Confere a senha apresentada contra o verificador persistido (BA-09, BA-22).
 * Fica na Application para o caso de uso não depender de `node:crypto`.
 */
export interface InvitePasswordVerifierPort {
  verify(password: string, verifier: string): Promise<boolean>;
}
