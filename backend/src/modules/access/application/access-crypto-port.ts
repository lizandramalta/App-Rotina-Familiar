/**
 * Material criptográfico de que o módulo Access precisa. Fica na camada de
 * Application para que o caso de uso não dependa de `node:crypto`; o adaptador
 * é `CryptoTokenService`, em Infrastructure.
 */
export interface AccessCryptoPort {
  /** Identificador de registro novo (UUID). */
  newId(): string;

  /** Token opaco de alta entropia, devolvido ao cliente e nunca persistido. */
  generateOpaqueToken(): string;

  /** SHA-256 do token opaco; é isso que vai para o banco. */
  hashToken(token: string): string;

  /**
   * Compara dois hashes em tempo constante. Validar a prova de instalação do
   * refresh com `===` deixaria o tempo de resposta contar quantos caracteres
   * do hash coincidem (CA-08).
   */
  hashesMatch(left: string, right: string): boolean;

  /** SHA-256 do `sub` da Apple, usado como chave de unicidade. */
  hashAppleSubject(appleSubject: string): string;

  /** Cifra reversível do `sub` da Apple (AES-256-GCM). */
  encryptAppleSubject(appleSubject: string): string;
}
