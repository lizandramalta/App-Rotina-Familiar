/**
 * Prova de identidade enviada pelo app ao final do login nativo (SPEC-001).
 * Nenhum destes campos pode ser registrado em log ou telemetria (RNF08, RNF16).
 */
export interface AppleIdentityProof {
  readonly identityToken: string;
  readonly authorizationCode: string;
  readonly rawNonce: string;
}

/**
 * Resultado da verificação. `subject` é o `sub` emitido pela Apple e é o único
 * identificador estável da identidade do Criador (SPEC-001).
 */
export interface VerifiedAppleIdentity {
  readonly subject: string;
  readonly email?: string;
  readonly isEmailVerified?: boolean;
  readonly isPrivateEmail?: boolean;
}

export interface AppleTokenVerifierPort {
  /**
   * Confere assinatura, emissor, audiência, validade e correspondência do
   * `rawNonce`, e troca o `authorizationCode` com a Apple. Rejeita a prova
   * quando qualquer uma dessas verificações falha.
   */
  verifyIdentityProof(proof: AppleIdentityProof): Promise<VerifiedAppleIdentity>;
}
