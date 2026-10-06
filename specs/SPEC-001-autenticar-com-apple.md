# Spec 001: Autenticar com Apple

**Status:** aprovada
**Autor:** Ana Luísa Coleone | **Criada em:** 2026-10-06 | **Aprovada por:** Ana Luísa Coleone | **Em:** 2026-10-06
**Base funcional:** 1.5
**UX-spec:** [UX-001-autenticar-com-apple.md](UX-001-autenticar-com-apple.md)
**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 1 - Acesso, família e perfis

## 1. Contexto e Objetivo

- **Problema / Necessidade:** o Criador da Família precisa de uma forma de entrar no aplicativo sem senha própria, usando sua identidade Apple, e o sistema precisa reconhecer se essa identidade já está vinculada a uma família ou se ainda vai criar uma.
- **Objetivo da entrega:** autenticar o Criador (ou futuro Criador) via Sign in with Apple nativo, validar a prova recebida, abrir a sessão do app quando já houver família vinculada e, quando não houver, emitir um grant restrito que habilita a criação da família em `SPEC-002`. Entrega também o ciclo de vida da sessão resultante (consulta, renovação e revogação), sem o qual a autenticação não seria utilizável.

## 2. Rastreabilidade e Dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Casos de uso | UC04 |
| Regras de negócio | RN44 |
| Requisitos funcionais | RF37, RF39 (parcial — apenas o reconhecimento da associação existente; a vinculação ao criar a família é de `SPEC-002`) |
| Requisitos não funcionais | RNF01, RNF05, RNF06, RNF07, RNF08, RNF12, RNF13, RNF14, RNF15, RNF16, RNF22 |
| Telas e fluxos de navegação | TEL-001, UF-01 (trecho de autenticação), UF-03 (trecho "Criador retorna por Apple") |
| Decisões arquiteturais aplicáveis | MA-10, BA-10, BA-19, BA-21 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md` (RN44), `docs/02-requisitos.md` (RF37, RF39, RNF01/05/06/07/08/12/13/14/15/16/22), `docs/03-casos-de-uso.md` (UC04), `docs/design/screen-map.md` (TEL-001), `docs/design/user-flows.md` (UF-01, UF-03), `docs/architecture/mobile-architecture.md` (§9), `docs/architecture/mobile-decisions.md` (MA-10, P-07), `docs/architecture/mobile-feature-catalog.md` (módulo `Access`), `docs/architecture/backend-architecture.md` (§8 "Criador via Apple"), `docs/architecture/backend-contracts.md` (§2, §7 `backend-uc04`), `docs/architecture/backend-decisions.md` (BA-10, BA-19, BA-21).
- **Depende de (specs pré-requisito):** Nenhuma - entrega independente.
- **Dependências externas e infraestrutura:** Sign in with Apple (`AuthenticationServices` no mobile; validação oficial de chaves/emissor/audiência no backend); TLS em todas as chamadas.

## 3. Escopo da Entrega

### 3.1. Dentro do escopo
- `POST /access/apple`: validar a prova do login nativo Apple e, a partir dela, (a) abrir a sessão do Criador quando já houver família vinculada à identidade, ou (b) emitir um `creationGrant` restrito quando não houver família.
- Substituição da sessão anterior do Criador quando um novo acesso Apple é confirmado (RN44).
- Rejeição explícita de prova Apple ausente, inválida ou de autenticação cancelada/falha, sem conceder acesso.
- Isolamento: `familyId` e `role` da sessão resultante são sempre derivados no servidor a partir da identidade Apple validada, nunca aceitos do cliente.
- Ciclo de vida da sessão emitida por esta entrega: `GET /me/session` (consulta), `POST /access/refresh` (renovação do access token), `DELETE /me/session` (revogação).
- Tela TEL-001 (Entrada): botão nativo Apple e feedback de erro/estado.

### 3.2. Fora do escopo (desta spec)
- Criação da própria família e tela TEL-002 (UC01) — fica em `SPEC-002-criar-configurar-familia`, que consome o `creationGrant` emitido aqui.
- Ingresso por convite, recuperação de ingresso, troca de acesso com sessão ativa (MOD-013) e tela TEL-004 (UC09) — ficam em `SPEC-005-ingressar-por-convite`.
- Gerenciamento de membros, promoção/remoção de Administrador (UC02) — fica em `SPEC-003-gerenciar-membros`.

### 3.3. Fora de questão (Anti-requisitos / Suposições descartadas)
- Este fluxo NÃO cria a família; "sem família vinculada" só devolve um grant restrito, nunca os dados de uma família.
- NÃO existe tela de seleção de perfil nem formulário de senha nesta entrega; a única interação visível é o botão nativo Apple.
- Administrador convidado, Membro e Kids NÃO se autenticam por `POST /access/apple`; eles ingressam exclusivamente por convite (UC09).
- O `creationGrant` não é uma sessão de membro e não autoriza nenhuma consulta de dados de família (RNF06).
- Não há login por e-mail/senha nem qualquer outro provedor de identidade nesta etapa.

## 4. Perfis, Atores e Regras de Autorização (RBAC)

Esta entrega não segue a matriz Administrador/Membro/Kids porque a rota é de **identidade**, não de perfil — os demais perfis nunca chegam a este endpoint (ingressam por convite, UC09). A distinção relevante é entre os dois resultados possíveis da mesma identidade Apple:

| Situação | Pode | Não pode | Reação do sistema a tentativa não autorizada |
|---|---|---|---|
| **Identidade Apple sem família vinculada** | Receber `creationGrant` restrito e seguir para `SPEC-002` (criação) | Consultar ou alterar dados de qualquer família; usar o grant como sessão de membro | HTTP 403 `ACTION_NOT_ALLOWED` em qualquer rota que exija sessão de membro |
| **Identidade Apple com família vinculada (Criador)** | Obter `SessionResult` e acessar sua própria família | Acessar dados de outra família | HTTP 404 `RESOURCE_NOT_FOUND` (RNF06) |
| **Prova Apple ausente, inválida, expirada ou autenticação cancelada** | Tentar novamente | Obter sessão ou grant | HTTP 401 `APPLE_PROOF_INVALID`; nenhuma credencial é emitida |

- **Isolamento Multitenant Familiar (RNF06):** o servidor nunca aceita `familyId` enviado pelo cliente nesta rota; a família devolvida vem exclusivamente da associação já persistida à identidade Apple validada (RN44).

## 5. Contrato de Dados, Interface e Validações

### 5.1. Dicionário de Campos e Validações de Entrada

| Campo (`json_key`) | Tipo | Obrigatório? | Regras de Validação e Limites | Código de Erro (`fieldErrors[].code`) | Descrição e Comportamento |
|---|---|---|---|---|---|
| `identityToken` | string (JWT) | Sim | Assinatura, emissor, audiência e validade conferidos no backend contra as chaves públicas da Apple | `APPLE_PROOF_INVALID` | Prova de identidade emitida pela Apple ao final do login nativo |
| `authorizationCode` | string | Sim | Trocado pela integração oficial Apple no backend; não aceito sem `identityToken` correspondente | `APPLE_PROOF_INVALID` | Código de autorização do fluxo nativo, usado na validação server-to-server |
| `rawNonce` | string | Sim | Deve corresponder ao hash do `nonce` presente em `identityToken` | `APPLE_PROOF_INVALID` | Nonce gerado pelo app antes de iniciar o login nativo, usado para impedir replay |

**Header privado de instalação:** `X-Installation-Proof` (string opaca) — obrigatório em todas as rotas desta spec; nunca registrado em log (RNF08, RNF16).

### 5.2. Contrato de API Compartilhado (Endpoints e Payloads)

#### 5.2.1 `POST /access/apple`
- **Autenticação:** nenhuma (ponto de entrada da sessão).
- **Headers específicos:** `X-Installation-Proof`.

Payload de entrada:
```json
{
  "identityToken": "<jwt da Apple>",
  "authorizationCode": "<code da Apple>",
  "rawNonce": "<nonce gerado pelo app>"
}
```

Resposta de sucesso — identidade com família vinculada:
- **HTTP Status:** `200 OK`
```json
{
  "sessionId": "e4f5a6b7-c8d9-0123-4567-89abcdef0123",
  "memberId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "familyId": "11112222-3333-4444-5555-666677778888",
  "role": "administrator",
  "isFamilyCreator": true,
  "accessToken": "<token opaco>",
  "accessTokenExpiresAt": "2026-10-06T15:15:00Z",
  "refreshToken": "<token opaco>"
}
```

Resposta de sucesso — identidade sem família vinculada:
- **HTTP Status:** `200 OK`
```json
{
  "creationGrant": "<token opaco>",
  "expiresAt": "2026-10-06T15:10:00Z"
}
```

#### 5.2.2 `GET /me/session`
- **Autenticação:** Bearer `accessToken`.

Resposta de sucesso:
- **HTTP Status:** `200 OK`
```json
{
  "memberId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "familyId": "11112222-3333-4444-5555-666677778888",
  "role": "administrator",
  "isFamilyCreator": true
}
```
Nunca devolve `accessToken`, `refreshToken` ou qualquer hash/credencial.

#### 5.2.3 `POST /access/refresh`
- **Autenticação:** nenhuma no header `Authorization`; credencial vai no body.
- **Headers específicos:** `X-Installation-Proof`.

Payload de entrada:
```json
{ "refreshToken": "<token opaco>" }
```

Resposta de sucesso:
- **HTTP Status:** `200 OK`
```json
{ "accessToken": "<novo token opaco>", "accessTokenExpiresAt": "2026-10-06T15:30:00Z" }
```

#### 5.2.4 `DELETE /me/session`
- **Autenticação:** Bearer `accessToken`.
- **Resposta de sucesso:** `204 No Content`. Revoga a sessão e o registro de push associado; não remove o membro.

#### Respostas de Erro Padronizadas (RFC 9457 - Problem Details)
Todos os erros utilizam `Content-Type: application/problem+json`.

| HTTP Status | `code` estável | Cenário / Causa | Rotas |
|---|---|---|---|
| `400 Bad Request` | `VALIDATION_FAILED` | Campo obrigatório ausente ou formato inválido | Todas |
| `401 Unauthorized` | `APPLE_PROOF_INVALID` | `identityToken`/`authorizationCode`/`rawNonce` inválidos, expirados ou autenticação cancelada no dispositivo | `POST /access/apple` |
| `401 Unauthorized` | `SESSION_REVOKED` | Refresh token inválido, revogado ou sessão encerrada | `POST /access/refresh` |
| `401 Unauthorized` | `SESSION_EXPIRED` | Access token ausente, inválido ou expirado | `GET /me/session`, `DELETE /me/session` |
| `403 Forbidden` | `ACTION_NOT_ALLOWED` | `creationGrant` usado como se fosse sessão de membro | Rotas protegidas de outras specs |
| `404 Not Found` | `RESOURCE_NOT_FOUND` | Recurso pertence a outra família | Rotas protegidas de outras specs |
| `429 Too Many Requests` | `RATE_LIMIT_EXCEEDED` | Excesso de tentativas de autenticação por origem | `POST /access/apple` |

### 5.3. Estratégia de Concorrência, Idempotência e Falhas
- **Idempotência:** não há `Idempotency-Key` nesta rota. Em caso de resposta perdida após autenticação Apple concluída, o app deve repetir o login nativo (nova prova) ou, se a família já existir, simplesmente tentar `POST /access/apple` novamente — BA-21/`CreateFamily` (em `SPEC-002`) trata a concorrência de criação; esta spec não cria nada persistente além da sessão/grant.
- **Concorrência:** novo acesso Apple bem-sucedido substitui/revoga a sessão anterior do Criador no mesmo commit (RN44, MA-10). `GET /me/session` sempre lê o estado atual do servidor, sem cache que prolongue sessão revogada.
- **Tratamento de Falhas e Rede Intermitente (RNF12, RNF13):** se a chamada a `POST /access/apple` falhar por rede após o login nativo ter sido concluído, o app mantém o botão em estado de carregamento controlado, informa a falha de forma não bloqueante e permite nova tentativa sem repetir o login nativo quando a prova ainda for válida, ou solicitando novo login nativo quando ela tiver expirado.

## 6. Estados de Domínio e Transições

| Estado De | Evento / Ação | Estado Para | Quem Pode Executar | Regras e Validações | Efeitos Colaterais |
|---|---|---|---|---|---|
| Sem sessão | `POST /access/apple` com prova válida e família vinculada | Sessão ativa do Criador | Identidade Apple validada | RN44 | Revoga sessão anterior do mesmo Criador |
| Sem sessão | `POST /access/apple` com prova válida e sem família | `creationGrant` emitido | Identidade Apple validada | BA-21 (expira em 10 min) | Nenhum efeito em dados de família |
| Sessão ativa | `POST /access/refresh` | Sessão ativa (novo access token) | Titular da sessão | Refresh válido e não revogado | Access tokens anteriores ainda dentro dos 15 min continuam válidos |
| Sessão ativa | `DELETE /me/session` | Sem sessão | Titular da sessão | Sessão ativa | Revoga também o registro de push |

## 7. Critérios de Aceitação (BDD Formal)

- **CA-01: [Fluxo Principal - Sucesso com família vinculada]**
  - **DADO QUE** uma identidade Apple já está vinculada a uma família como Criador,
  - **QUANDO** o app enviar `POST /access/apple` com prova válida,
  - **ENTÃO O SISTEMA DEVE** validar a prova e abrir a sessão daquele Criador,
  - **E** retornar HTTP `200 OK` com `SessionResult` contendo `familyId` e `role: administrator`. *(Origem: UC04 passo 5, RN44, RF37/39)*

- **CA-02: [Fluxo Principal - Sucesso sem família vinculada]**
  - **DADO QUE** uma identidade Apple validada não possui família vinculada,
  - **QUANDO** o app enviar `POST /access/apple` com prova válida,
  - **ENTÃO O SISTEMA DEVE** emitir um `creationGrant` restrito à criação de família, sem sessão de membro,
  - **E** retornar HTTP `200 OK` com o grant e seu `expiresAt` (10 minutos, BA-21). *(Origem: UC04 alternativa "sem família", RF37)*

- **CA-03: [Alternativa - Cancelamento ou falha no login nativo]**
  - **DADO QUE** o usuário cancela o login nativo Apple ou a autenticação falha no dispositivo,
  - **QUANDO** o app não receber uma prova válida da Apple,
  - **ENTÃO O SISTEMA DEVE** permanecer em TEL-001 sem conceder sessão ou grant algum,
  - **E** nenhuma chamada a `POST /access/apple` deve ser enviada sem prova. *(Origem: UC04 alternativa "cancelamento ou falha")*

- **CA-04: [Validação - Prova Apple inválida]**
  - **DADO QUE** o backend recebe `identityToken`, `authorizationCode` ou `rawNonce` inválidos, inconsistentes entre si ou com validade expirada,
  - **QUANDO** `POST /access/apple` for processado,
  - **ENTÃO O SISTEMA DEVE** rejeitar a requisição sem emitir sessão ou grant,
  - **E** retornar HTTP `401 Unauthorized` com código `APPLE_PROOF_INVALID`. *(Origem: RNF15, backend-architecture.md §8)*

- **CA-05: [Consistência - Substituição da sessão anterior do Criador]**
  - **DADO QUE** o Criador já possui uma sessão ativa em outro contexto,
  - **QUANDO** ele concluir um novo login Apple com sucesso,
  - **ENTÃO O SISTEMA DEVE** revogar a sessão anterior no mesmo commit que abre a nova,
  - **E** chamadas subsequentes com o `accessToken` antigo devem responder `401 SESSION_REVOKED`. *(Origem: RN44, MA-10, BA-10)*

- **CA-06: [Isolamento Multitenant - Família nunca aceita do cliente]**
  - **DADO QUE** um cliente malicioso envia um `familyId` arbitrário no corpo ou em qualquer parâmetro de `POST /access/apple`,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** ignorar completamente esse valor,
  - **E** derivar `familyId` exclusivamente da associação persistida à identidade Apple validada. *(Origem: RNF06)*

- **CA-07: [Sessão - Consulta do estado atual]**
  - **DADO QUE** existe uma sessão ativa,
  - **QUANDO** o app chamar `GET /me/session` com `accessToken` válido,
  - **ENTÃO O SISTEMA DEVE** retornar `200 OK` com perfil, família, papel e `isFamilyCreator` atuais,
  - **E** nunca incluir tokens, hashes ou segredos no corpo. *(Origem: backend-contracts.md §2)*

- **CA-08: [Sessão - Renovação do access token]**
  - **DADO QUE** o `accessToken` está perto de expirar ou já expirou, mas o `refreshToken` é válido,
  - **QUANDO** o app chamar `POST /access/refresh` com o `refreshToken` e a prova de instalação,
  - **ENTÃO O SISTEMA DEVE** emitir um novo `accessToken` sem invalidar outros ainda dentro dos 15 minutos da mesma sessão,
  - **E** retornar HTTP `200 OK` com o novo token e sua expiração. *(Origem: MA-10, BA-10, RNF22)*

- **CA-09: [Sessão - Revogação explícita]**
  - **DADO QUE** existe uma sessão ativa,
  - **QUANDO** o titular chamar `DELETE /me/session`,
  - **ENTÃO O SISTEMA DEVE** revogar imediatamente a sessão e o registro de push associado,
  - **E** retornar HTTP `204 No Content`, sem remover o membro. *(Origem: backend-contracts.md §2)*

- **CA-10: [Resiliência - Falha de rede após login nativo]**
  - **DADO QUE** o login nativo Apple foi concluído mas a chamada a `POST /access/apple` falha por rede,
  - **QUANDO** o app detectar a falha,
  - **ENTÃO O SISTEMA DEVE** informar a falha de forma não bloqueante, sem apresentar sessão como aberta,
  - **E** permitir nova tentativa assim que a conexão for restabelecida. *(Origem: RNF12, RNF13)*

### Checklist de Cobertura Obrigatória dos CAs:
- [x] Fluxo principal de cada alternativa de UC04 coberto (CA-01, CA-02)
- [x] Fluxos alternativos e exceções do UC mapeados (CA-03, CA-04)
- [x] Recusa explícita para cada perfil sem permissão (RNF07) — não aplicável como matriz de perfil nesta rota (ver seção 4); cobertura equivalente em CA-06 (isolamento de identidade/família)
- [x] Isolamento estrito entre famílias / multitenancy (RNF06) — CA-06
- [x] Ações simultâneas e concorrência tratadas (RNF11) — CA-05 (substituição de sessão)
- [x] Falha de conexão, timeout e preservação de estado (RNF12, RNF13) — CA-10
- [ ] Limites numéricos de campos e validações de fronteira — não aplicável; os três campos de entrada são provas opacas da Apple, sem limites de tamanho de produto a validar

## 8. Observabilidade, Métricas e Auditoria

| Evento | Tipo | Gatilho / Condição | Propriedades Registradas | Destino |
|---|---|---|---|---|
| `apple_sign_in_succeeded` | Métrica / Analytics | `POST /access/apple` concedeu sessão ou grant | `outcome` (`session`\|`creationGrant`), `familyId` quando houver | Analytics |
| `apple_sign_in_rejected` | Log de Segurança | Prova Apple inválida ou excesso de tentativas | `requestId`, `reason`, IP de origem | Log estruturado |
| `session_revoked` | Log de Segurança | Substituição por novo login Apple ou revogação explícita | `sessionId`, `reason` | Log estruturado |

*Nota de Privacidade e Segurança:* `identityToken`, `authorizationCode`, `rawNonce`, `accessToken`, `refreshToken` e o header `X-Installation-Proof` NUNCA são registrados em logs ou eventos de telemetria (RNF08, RNF16).

## 9. Premissas e Esclarecimentos

### 9.1. Premissas
- **P-01:** o app sempre conclui o login nativo Apple (`AuthenticationServices`) antes de chamar `POST /access/apple`; este backend nunca inicia ou medeia a UI do login.
- **P-02:** `GET /me/session`, `POST /access/refresh` e `DELETE /me/session` são infraestrutura de sessão compartilhada por todas as specs futuras que exigem um ator autenticado; esta spec apenas os entrega primeiro, por ser a raiz do Tema 1.

### 9.2. Esclarecimentos e Decisões

| # | Pergunta / Dúvida | Decisão Tomada | Decidido por / Data | Altera a documentação em `docs/`? |
|---|---|---|---|---|
| E-01 | `GET /me/session`, `POST /access/refresh` e `DELETE /me/session` não são vinculados a nenhum UC em `backend-contracts.md` §7. Entram em `SPEC-001`? | Sim, entram em `SPEC-001` — sem eles a sessão emitida por UC04 não seria utilizável (access token de 15 min). | Ana Luísa Coleone / 2026-10-06 | Não |
| E-02 | O TTL do `creationGrant` era só uma proposta em `backend-architecture.md` (dez minutos), sem decisão `BA` confirmada. | Confirmado em 10 minutos; registrado como `BA-21`. | Ana Luísa Coleone / 2026-10-06 | Sim — `docs/architecture/backend-decisions.md` (BA-21, v1.1) e `docs/architecture/backend-architecture.md` (§8) atualizados nesta aprovação. |
| E-03 | RN09 descreve o redirecionamento do Criador para a família existente (passo 5 de UC04), mas só é citada por UC01/UC09 na base funcional. Entra na rastreabilidade de `SPEC-001`? | Não. RN09 fica reservada para `SPEC-002`; `SPEC-001` cita apenas RN44. | Ana Luísa Coleone / 2026-10-06 | Não |
| E-04 | Não havia convenção prévia de nomes de campo/header (`identityToken`, `authorizationCode`, `rawNonce`, `X-Installation-Proof`) nem de códigos de erro estáveis (`APPLE_PROOF_INVALID` etc.) para esta rota. | Aprovados os nomes propostos nesta spec; passam a ser a convenção inicial do módulo `Access` para as specs seguintes do Tema 1. | Ana Luísa Coleone / 2026-10-06 | Não |
| E-05 | `SessionResult` (`backend-contracts.md`) não lista `isFamilyCreator`, mas a UI precisa saber disso para aplicar as proteções do Criador. | Aprovado incluir `isFamilyCreator` em `SessionResult` e em `GetCurrentSession`. | Ana Luísa Coleone / 2026-10-06 | Sim — `docs/architecture/backend-contracts.md` (v1.1) atualizado nesta aprovação. |

## 10. Fases de Implementação e Critérios de Conclusão

| Fase | Objetivo da Entrega | Critérios de Aceite Atendidos | Critério de Prontidão (Definition of Done) | Status |
|---|---|---|---|---|
| **1** | **Núcleo Mínimo:** validação da prova Apple, emissão de sessão/`creationGrant`, isolamento e rejeição explícita. | CA-01, CA-02, CA-03, CA-04, CA-05, CA-06 | Testes unitários e de integração verdes cobrindo os CAs listados. | a fazer |
| **2** | **Sessão utilizável + resiliência:** consulta, renovação e revogação de sessão; tratamento de falha de rede no mobile. | CA-07, CA-08, CA-09, CA-10 | Telas integradas com a API, testes de UI/E2E e UX-spec verificada. | a fazer |
| **3** | **Polimento:** limitação de tentativas e observabilidade. | Rate limiting (`RATE_LIMIT_EXCEEDED`) | Suíte de regressão verde e validação de QA concluída. | a fazer |

### Para cada fase:
- **Fase 1 — Fora desta fase:** o usuário autenticado ainda não consegue manter a sessão por muito tempo (sem refresh) nem encerrá-la explicitamente; TEL-001 mostra erro genérico sem distinguir motivo até a Fase 2 refinar a UX-spec. **Pode ser publicada de forma independente em produção?** Não — depende da Fase 2 para a sessão não cair em 15 minutos.
- **Fase 2 — Fora desta fase:** sem limites de tentativas abusivas. **Pode ser publicada de forma independente em produção?** Sim.
- **Fase 3 — Fora desta fase:** nada além de polimento. **Pode ser publicada de forma independente em produção?** Sim.

## 11. Checklist de Aprovação da Spec (Definition of Ready)

- [x] Todos os códigos citados (`RN`, `RF`, `RNF`, `UC`, `TEL`, `UF`) existem na base funcional vigente.
- [x] A rastreabilidade técnica (`MA-..`, `BA-..`) está alinhada com as diretrizes de arquitetura.
- [x] O contrato de API compartilhado (rotas, payloads JSON, status HTTP e Problem Details) está completo e sem ambiguidades.
- [x] O dicionário de campos define tipos, limites e códigos de erro estáveis para todos os inputs.
- [x] Todo critério de aceitação segue o padrão formal BDD e mapeia um teste automatizável.
- [x] Isolamento entre famílias (RNF06) e recusa por perfil (RNF07) constam explicitamente nos CAs da Fase 1, com a ressalva registrada na seção 7 sobre a natureza desta rota baseada em identidade.
- [x] Nenhuma premissa sem validação ou esclarecimento pendente na seção 9 — todos os E-01 a E-05 foram decididos.
- [x] A UX-spec correspondente está vinculada, revisada e coerente.
- [x] A seção "Fora de questão" elimina riscos de suposições incorretas.
- [x] Não há detalhes efêmeros de implementação que engessem a arquitetura interna dos módulos.
