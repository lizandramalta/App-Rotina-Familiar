import { DomainError } from '../../../shared/domain/domain-error.js';

/**
 * Prova Apple inválida, inconsistente entre si ou expirada (CA-04, SPEC-001).
 *
 * A mensagem é sempre genérica: distinguir "assinatura inválida" de "nonce
 * divergente" na resposta diria ao chamador qual etapa falhou, e nenhum detalhe
 * da prova pode aparecer em resposta ou log (RNF08, RNF16).
 */
export class AppleProofInvalidError extends DomainError {
  constructor(message = 'The Apple identity proof is invalid or has expired.') {
    super({ message, code: 'APPLE_PROOF_INVALID', statusCode: 401 });
  }
}

/**
 * Access token ausente, malformado, desconhecido ou fora da janela de 15
 * minutos (BA-10). Orienta o app a renovar o acesso com o refresh token.
 *
 * A mensagem não distingue "ausente" de "expirado": saber qual dos dois é o
 * caso diria ao chamador se o token existiu algum dia (RNF08, RNF16).
 */
export class SessionExpiredError extends DomainError {
  constructor(message = 'The access token is missing, invalid, or expired.') {
    super({ message, code: 'SESSION_EXPIRED', statusCode: 401 });
  }
}

/**
 * Sessão encerrada — por revogação explícita (CA-09) ou substituída por um novo
 * login Apple (CA-05). Diferente de `SessionExpiredError` de propósito: aqui
 * renovar não resolve, e o app precisa voltar ao login.
 */
export class SessionRevokedError extends DomainError {
  constructor(message = 'The session has been revoked.') {
    super({ message, code: 'SESSION_REVOKED', statusCode: 401 });
  }
}

/**
 * Access token ausente, desconhecido, expirado ou de sessão revogada. Uma única
 * resposta para todos os casos: distinguir o motivo diria a quem sonda qual
 * etapa falhou.
 */
export class AccessTokenInvalidError extends DomainError {
  constructor(message = 'The access token is missing, invalid or has expired.') {
    super({ message, code: 'ACCESS_TOKEN_INVALID', statusCode: 401 });
  }
}
