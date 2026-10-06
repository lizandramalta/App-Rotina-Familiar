# Spec 005: Ingressar por convite

**Status:** aprovada

**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06

**Base funcional:** 1.7

**UX-spec:** [UX-005-ingressar-por-convite.md](UX-005-ingressar-por-convite.md)

**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 1 - Acesso, família e perfis

## 1. Contexto e objetivo

- **Problema / necessidade:** um perfil criado por Administrador só obtém acesso pelo convite destinado a ele. Se a sessão for perdida, o mesmo perfil deve ser recuperado sem duplicar histórico, tarefas ou vínculos.
- **Objetivo da entrega:** permitir inspecionar e consumir uma vez um convite disponível mediante senha, criar a sessão única do perfil indicado e recuperar com segurança o resultado de um ingresso cuja resposta se perdeu.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Caso de uso | UC09 |
| Regras de negócio | RN09, RN10, RN45–RN47 |
| Requisitos funcionais | RF42–RF46, RF54, RF68 |
| Requisitos não funcionais | RNF01, RNF04–RNF08, RNF12–RNF14, RNF17–RNF22 |
| Telas e fluxos | TEL-001, TEL-003, TEL-004, TEL-010, TEL-040, MOD-013, UF-02, UF-03 |
| Decisões arquiteturais | MA-07–MA-11, MA-15; BA-07–BA-11, BA-20 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-architecture.md`, `docs/architecture/mobile-feature-catalog.md`, `docs/architecture/mobile-decisions.md`, `docs/architecture/backend-architecture.md`, `docs/architecture/backend-contracts.md` e `docs/architecture/backend-decisions.md`.
- **Depende de:** [SPEC-004-gerar-reenviar-convite.md](SPEC-004-gerar-reenviar-convite.md), aprovada. Ela disponibiliza o convite; esta entrega não emite nem reemite credenciais.
- **Dependências externas e infraestrutura:** Universal Links/AASA e loja para abrir o convite sem app; sessão própria, prova protegida de instalação, armazenamento temporário criptografado da recuperação e Keychain no iOS/iPadOS.

## 3. Escopo da entrega

### 3.1. Dentro do escopo

- Inspecionar o token do link e revelar somente se o convite está disponível, sem nome, foto, família, perfil ou senha.
- Receber senha e provas da tentativa/instalação, validar convite, perfil ativo e vínculo imutável com família/perfil no backend.
- Consumir o convite e criar, atomicamente, uma única sessão do perfil indicado, vinculada à instalação.
- Trocar uma sessão local ativa somente depois de confirmação explícita e ingresso bem-sucedido; preservar o perfil e o histórico anteriores.
- Encaminhar Administradores e Membros para TEL-010 e Kids para TEL-040.
- Recuperar por dez minutos o resultado de ingresso já confirmado quando a resposta foi perdida, exigindo as provas originais e sem novo consumo.
- Tratar convite indisponível, senha incorreta, tentativas abusivas, concorrência, perfil removido, falhas de rede e observabilidade sem segredos.

### 3.2. Fora do escopo

- Criar, editar, remover membro ou emitir/reemitir convite: SPEC-003 e SPEC-004.
- Autenticação e recuperação do Criador por Apple: SPEC-001.
- Transferir membro, família, tarefas, histórico ou vínculos durante a troca de acesso.
- Recuperar senha, reutilizar convite consumido ou aplicar idempotência geral a comandos do produto.
- Enviar pedido de recuperação a Administrador, mensagem automática, e-mail, SMS ou push.

### 3.3. Fora de questão

- A senha do convite não é senha permanente de login e não é armazenada legível.
- A posse do token não autoriza escolher outro perfil ou família; estes vínculos vêm exclusivamente do convite validado.
- Um convite inválido, consumido, revogado ou destinado a perfil removido tem resposta pública neutra e não revela a causa nem dados associados.
- Cancelar MOD-013, falhar antes do commit ou informar senha inválida não encerra a sessão local anterior.
- Falha ou resposta perdida não é apresentada como ingresso concluído; a recuperação específica não equivale a segundo consumo.

## 4. Perfis, atores e regras de autorização

| Situação | Pode | Não pode | Garantia |
|---|---|---|---|
| Pessoa com convite disponível | Inspecionar e ingressar no perfil do convite com a senha correta | Selecionar família, papel ou outro perfil | O backend deriva família e perfil do convite |
| Pessoa com sessão ativa | Confirmar troca e ingressar no perfil do convite | Alterar a sessão anterior antes de sucesso | A sessão anterior é preservada até o commit bem-sucedido |
| Perfil Kids ingressante | Usar as superfícies permitidas de Kids | Receber acesso de adulto por causa do convite | Sessão e navegação usam o papel validado |
| Perfil removido ou convite indisponível | Consultar orientação de recuperação | Ingressar, renovar ou recuperar credenciais | Resposta pública não revela estado nem titularidade |
| Criador sem sessão | Retornar por Sign in with Apple | Recuperar acesso por convite | Apple permanece exclusivo do Criador |

- **Isolamento familiar (RNF06/RNF19):** `familyId`, `memberId`, papel e flag de Criador nunca são recebidos do cliente para definir o ingresso. Eles derivam do convite validado e não são retornados pela inspeção.
- **Autorização (RNF07):** toda sessão resultante é consultada e autorizada pelo backend em operações protegidas; controles visuais não substituem essa validação.
- **Sessão e revogação (RN46, RN47, RNF22):** há uma sessão ativa por perfil/aparelho. Access token dura 15 minutos; refresh token é estável, sem expiração temporal e revogável. Novo convite e remoção revogam o acesso nas condições definidas pela base.

## 5. Contrato de dados, interface e validações

Todas as rotas usam prefixo `/v1`, `Cache-Control: no-store` nas respostas que contenham credenciais e erros `application/problem+json` com `type`, `title`, `status`, `code` e `requestId`. Campos desconhecidos são recusados com `400 UNKNOWN_FIELD`. Tokens, senhas, segredos de tentativa, provas de instalação e credenciais de sessão não entram em logs, auditoria ou telemetria.

### 5.1. Inspeção neutra

- **Método e rota:** `POST /v1/access/invites/inspect`
- **Caso de uso:** `InspectInvite`
- **Entrada:** `{ "token": "opaque-token" }`.
- **Sucesso:** `200 OK` com `{ "status": "available" }`.
- **Indisponível:** `404 INVITE_UNAVAILABLE` para token inválido, consumido, revogado ou associado a perfil removido; não diferencia esses estados nem expõe identidade, família ou papel.
- **Proteções:** `429 RATE_LIMITED` para limites de tentativa; validação e limites também se aplicam à posse do token.

### 5.2. Ingresso

- **Método e rota:** `POST /v1/access/invite-joins`
- **Caso de uso:** `JoinFamilyByInvite`
- **Autenticação opcional:** `Authorization: Bearer <accessToken>` somente quando há sessão local ativa a substituir. Sem sessão atual, a rota é pública sob posse de convite e proteções antiabuso.

| Campo | Tipo | Obrigatório | Validação / uso |
|---|---|---:|---|
| `token` | string opaca | Sim | Identifica o convite; não determina dados vindos do cliente |
| `password` | string | Sim | Comparada ao verificador protegido; nunca persistida legível |
| `attemptId` | UUID | Sim | Identifica a tentativa recuperável |
| `attemptSecret` | string opaca | Sim | Segredo imprevisível da tentativa; só seu verificador é guardado |
| `installationProof` | string opaca | Sim | Prova protegida da instalação; não é apenas um identificador público |
| `switchConfirmed` | boolean | Sim | Deve ser `true` quando uma sessão anterior válida acompanha a chamada; sem sessão anterior, não produz troca |

**Sucesso:** `201 Created` com `SessionResult`: `sessionId`, `memberId`, `familyId`, `role`, `isFamilyCreator`, `accessToken`, `accessTokenExpiresAt` e `refreshToken`.

| HTTP | Código | Situação |
|---:|---|---|
| 400 | `UNKNOWN_FIELD` ou `VALIDATION_FAILED` | Corpo ausente, inválido ou com campos não suportados |
| 401 | `SESSION_INVALID` | Credencial anterior fornecida é inválida ou revogada |
| 404 | `INVITE_UNAVAILABLE` | Convite não pode ser usado, sem discriminar motivo |
| 409 | `ACCESS_SWITCH_CONFIRMATION_REQUIRED` | Há sessão anterior válida, mas `switchConfirmed` não foi confirmado |
| 422 | `INVITE_PASSWORD_INVALID` | Senha não corresponde; convite continua disponível |
| 429 | `RATE_LIMITED` | Limite de inspeção/senha atingido |
| 503 | `JOIN_RESULT_UNCERTAIN` | O resultado não pode ser confirmado na resposta; cliente usa recuperação específica |

### 5.3. Recuperação de ingresso

- **Método e rota:** `POST /v1/access/invite-joins/recover`
- **Caso de uso:** `RecoverInviteJoin`
- **Entrada:** `attemptId`, `attemptSecret` e `installationProof` da tentativa original.
- **Sucesso:** `200 OK` com o mesmo `SessionResult` do ingresso originalmente confirmado.
- **Condições:** somente até dez minutos a partir do commit, com tentativa/instalação compatíveis e sessão ainda ativa. Não recebe senha, não consome novamente o convite e não recupera por identificador público.
- **Erros:** `400 UNKNOWN_FIELD`/`VALIDATION_FAILED`, `404 JOIN_RECOVERY_UNAVAILABLE` para tentativa expirada, incompatível, revogada ou sem resultado recuperável, `429 RATE_LIMITED` e `503 DEPENDENCY_UNAVAILABLE`.

### 5.4. Consistência e falhas

- O backend valida senha antes do lock quando possível e revalida convite, perfil ativo e disponibilidade dentro da transação curta serializada. O mesmo commit consome o convite, cria a sessão, registra a recuperação temporária e, em troca confirmada, encerra a sessão anterior.
- Tentativas concorrentes não criam duas sessões nem dois consumos. A segunda tentativa recebe estado indisponível, sem informações do primeiro ingresso.
- Antes do ingresso, o mobile cria e guarda em Keychain o material da tentativa. Se houver timeout, perda de resposta ou `JOIN_RESULT_UNCERTAIN`, não reenvia o ingresso automaticamente: tenta a recuperação específica.
- Depois de dez minutos, ou sem prova compatível, a orientação é obter novo convite; não há fallback por senha, ID ou consulta genérica de estado.

## 6. Estados de domínio e transições

| Estado | Evento | Estado resultante | Garantia |
|---|---|---|---|
| Convite `available` e perfil ativo | Senha e provas válidas | Convite `consumed` + sessão ativa | Operação única e atômica |
| Convite `available` | Senha incorreta | Convite `available` | Nenhum acesso ou consumo; limites antiabuso preservados |
| Convite `available` | Duas tentativas simultâneas | Um `consumed`; outro indisponível | No máximo um ingresso confirmado |
| Sessão local ativa + convite disponível | Troca confirmada e ingresso válido | Nova sessão ativa; sessão anterior encerrada | Perfil anterior não é removido nem migrado |
| Ingresso confirmado sem resposta entregue | Recuperação comprovada em até 10 min | Mesma sessão retornada | Não há novo consumo |
| Tentativa expirada/revogada/incompatível | Recuperação | Sem alteração | Novo convite necessário |

## 7. Critérios de aceitação

- **CA-01: inspeção neutra de convite disponível**
  - **DADO QUE** uma pessoa possui o token de um convite disponível,
  - **QUANDO** enviar `POST /v1/access/invites/inspect`,
  - **ENTÃO O SISTEMA DEVE** retornar apenas `status: available`,
  - **E** NÃO DEVE revelar nome, foto, família, papel, senha ou outro dado privado. *(UC09, RF42–RF43, RN45–RN46, RNF17–RNF20)*

- **CA-02: ingresso válido cria a sessão do perfil correto**
  - **DADO QUE** o convite está disponível, o perfil está ativo e a senha/provas são válidas,
  - **QUANDO** a pessoa confirmar o ingresso,
  - **ENTÃO O SISTEMA DEVE** consumir o convite e criar uma única sessão vinculada à instalação para a família e perfil definidos pelo convite,
  - **E** retornar `SessionResult` com as permissões do perfil, sem aceitar família, papel ou membro enviados pelo cliente. *(RF42–RF46, RN45–RN47, RNF18–RNF22)*

- **CA-03: senha inválida não consome convite**
  - **DADO QUE** um convite disponível é apresentado com senha incorreta,
  - **QUANDO** o ingresso for processado,
  - **ENTÃO O SISTEMA DEVE** responder `422 INVITE_PASSWORD_INVALID` sem criar sessão,
  - **E** manter o convite disponível, aplicando `429 RATE_LIMITED` quando os limites antiabuso forem atingidos. *(UC09, RF43–RF44, RN46, RNF20–RNF21)*

- **CA-04: indisponibilidade não revela estado nem dados**
  - **DADO QUE** o token é inválido, consumido, revogado ou pertence a perfil removido,
  - **QUANDO** for inspecionado ou usado para ingressar,
  - **ENTÃO O SISTEMA DEVE** responder `404 INVITE_UNAVAILABLE`,
  - **E** não DEVE informar qual condição ocorreu, nem expor dados da família ou do perfil. *(RF43, RN10, RNF06, RNF18–RNF19)*

- **CA-05: concorrência preserva consumo único**
  - **DADO QUE** duas tentativas usam o mesmo convite disponível simultaneamente,
  - **QUANDO** ambas alcançarem a validação de ingresso,
  - **ENTÃO O SISTEMA DEVE** confirmar somente uma sessão e um consumo,
  - **E** tratar a outra tentativa como convite indisponível, sem emitir segunda sessão. *(RF44, RN46, RNF21, BA-08)*

- **CA-06: troca de acesso preserva contexto anterior até sucesso**
  - **DADO QUE** a pessoa abre um convite com sessão local válida,
  - **QUANDO** cancelar MOD-013, falhar a validação ou não confirmar `switchConfirmed`,
  - **ENTÃO O APP DEVE** manter a sessão e os dados locais atuais,
  - **E** somente após ingresso confirmado DEVE limpar o contexto anterior e usar a nova sessão, sem remover ou migrar o perfil antigo. *(RF68, RN09, RN47)*

- **CA-07: recuperação de resposta perdida não cria segundo ingresso**
  - **DADO QUE** o ingresso foi confirmado no servidor, mas a resposta não chegou ao app,
  - **QUANDO** a mesma tentativa e instalação solicitarem recuperação em até dez minutos,
  - **ENTÃO O SISTEMA DEVE** devolver as credenciais da mesma sessão,
  - **E** NÃO DEVE consumir novamente o convite ou criar outra sessão. *(RF46, RN47, RNF12, RNF22, BA-11)*

- **CA-08: recuperação indisponível orienta o próximo caminho correto**
  - **DADO QUE** a janela expirou, as provas não correspondem, o perfil foi removido ou a sessão recuperável foi revogada,
  - **QUANDO** a recuperação for solicitada,
  - **ENTÃO O SISTEMA DEVE** responder `404 JOIN_RECOVERY_UNAVAILABLE` sem expor o motivo,
  - **E** o APP DEVE orientar novo convite para perfil não-Criador e retorno Apple para o Criador. *(UC09, RF46, RN10, RN44, RN47, RNF22)*

- **CA-09: destino respeita o perfil validado**
  - **DADO QUE** o ingresso foi confirmado,
  - **QUANDO** o app montar a navegação inicial,
  - **ENTÃO O APP DEVE** abrir TEL-040 para Kids e TEL-010 para Administrador ou Membro,
  - **E** NÃO DEVE exibir destinos ou capacidades incompatíveis com o papel recebido na sessão. *(UC09, RN06, RNF04, RNF07)*

## 8. Observabilidade e auditoria

| Evento | Gatilho | Dados permitidos |
|---|---|---|
| `invite_inspection_denied` | Token indisponível ou limite atingido | `requestId`, rota, classificação neutra e instante |
| `invite_join_confirmed` | Ingresso confirmado | `sessionId`, `memberId`, `familyId`, papel e instante |
| `invite_join_denied` | Senha inválida, convite indisponível ou troca sem confirmação | `requestId`, rota, código e instante |
| `invite_join_recovery` | Recuperação confirmada ou negada | `requestId`, resultado e instante |

Nunca registrar token, senha, verificadores, `attemptSecret`, prova da instalação, refresh token, access token ou corpo completo das requisições.

## 9. Premissas e decisões

| # | Decisão | Origem | Altera `docs/`? |
|---|---|---|---|
| E-01 | A inspeção é neutra: retorna somente disponibilidade e não exibe identidade, família, perfil ou foto antes do ingresso. | Pessoa usuária, 2026-10-06 | Não — concretiza o “contexto mínimo” já previsto no contrato backend sem mudar o comportamento funcional. |
| E-02 | Esta SPEC fixa schemas e códigos públicos para inspeção, ingresso e recuperação, seguindo as rotas e garantias já previstas pela arquitetura. | Pessoa usuária, 2026-10-06 | Não — detalhamento técnico permitido por BA-20; qualquer alteração de regra exige revisão da base. |
| E-03 | `INVITE_UNAVAILABLE` e `JOIN_RECOVERY_UNAVAILABLE` são respostas neutras para estados indisponíveis, evitando revelar consumo, revogação, remoção ou titularidade. | Decisão da SPEC, 2026-10-06 | Não — preserva RNF06, RNF18 e RNF19. |

Não há esclarecimentos pendentes.

## 10. Fases de implementação e conclusão

| Fase | Objetivo | CAs | Prontidão | Status |
|---|---|---|---|---|
| 1 | Núcleo seguro de acesso: inspeção, validação, consumo, sessão, isolamento, concorrência e recuperação | CA-01 a CA-05, CA-07, CA-08 | Testes unitários e integração com PostgreSQL real verdes; segredos ausentes de logs | a fazer |
| 2 | Jornada mobile: Universal Link, TEL-003/004, MOD-013, Keychain, troca e destinos por perfil | CA-06, CA-08, CA-09 | Testes de UI e integração em iPhone/iPad; UX-spec verificada | a fazer |
| 3 | Regressão e resiliência | CA-03 a CA-08 | Cenários de timeout, recuperação, revogação e acessibilidade verificados | a fazer |

- **Fase 1:** não expõe ingresso produtivo sem consumo atômico, sessão, limites e recuperação segura. Não é publicável isoladamente, pois ainda não há jornada de deep link e senha.
- **Fase 2:** não emite convites nem altera o perfil existente; usa somente as credenciais de SPEC-004. Pode ser publicada junto da Fase 1.
- **Fase 3:** não acrescenta comportamento de produto; consolida cobertura de falhas, segurança e regressão.

## 11. Checklist de aprovação

- [x] Códigos funcionais, UX e arquiteturais pesquisados e existentes.
- [x] Dependência SPEC-004 validada como aprovada.
- [x] Autorização, isolamento, consumo único, validação e recuperação constam da Fase 1.
- [x] Contratos, schemas e erros públicos estão definidos sem aceitar vínculos de família/perfil do cliente.
- [x] UX-spec vinculada e microcopy localizável prevista.
- [x] Esclarecimentos resolvidos pela pessoa usuária em 2026-10-06.
- [x] Status autorizado explicitamente como `aprovada` pela pessoa usuária em 2026-10-06.
