# Spec 013: Validar conclusão de tarefa Kids

**Status:** rascunho

**Autor:** Codex | **Criada em:** 2026-10-08 | **Aprovada por:** | **Em:**

**Base funcional:** 1.14

**UX-spec:** [UX-013-validar-conclusao-kids.md](UX-013-validar-conclusao-kids.md)

**Projetos envolvidos:** ambos

**Tema do backlog:** Tema 3 - Participação Kids

## 1. Contexto e Objetivo

- **Problema / Necessidade:** após uma criança sinalizar uma tarefa própria pela SPEC-012, a família precisa de uma avaliação administrativa única que conclua a tarefa ou a devolva a Pendente. Sem essa capacidade, a tarefa permanece indefinidamente em `awaitingConfirmation`, sem crédito, progresso ou avanço em missões.
- **Objetivo da entrega:** permitir que qualquer Administrador consulte a fila da própria família, avalie uma sinalização Kids com foto opcional e confirme ou recuse a realização de forma transacional, privada e silenciosamente reconciliável sob concorrência.

## 2. Rastreabilidade e Dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Caso de uso | UC03 |
| Regras de negócio | RN22, RN23, RN24, RN25, RN26, RN30, RN35, RN54, RN55, RN56 |
| Requisitos funcionais | RF25, RF26, RF55, RF56 |
| Requisitos não funcionais | RNF01, RNF02, RNF04, RNF05, RNF06, RNF07, RNF08, RNF09, RNF10, RNF11, RNF12, RNF13, RNF14, RNF22, RNF24, RNF25 |
| Telas e fluxos de navegação | TEL-015, TEL-016, UF-07 (ramo Administrador) |
| Decisões arquiteturais aplicáveis | MA-07, MA-08, MA-09, MA-11, MA-16; BA-05, BA-07, BA-08, BA-16, BA-20 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/backend-architecture.md`, `docs/architecture/backend-contracts.md`, `docs/architecture/backend-decisions.md`, `docs/architecture/mobile-decisions.md` e `docs/architecture/mobile-feature-catalog.md`.
- **Depende de (specs pré-requisito):** [SPEC-012-sinalizar-tarefa-kids.md](SPEC-012-sinalizar-tarefa-kids.md), aprovada, que cria a sinalização e reserva seu `signalId`; [SPEC-010-concluir-tarefa.md](SPEC-010-concluir-tarefa.md), aprovada, que pode encerrar a pendência por conclusão manual; [SPEC-014-gerenciar-missoes.md](SPEC-014-gerenciar-missoes.md), aprovada, para o efeito de conclusão sobre missões.
- **Dependências externas e infraestrutura:** PostgreSQL transacional e Cloudflare R2 privado já adotado para a foto opcional. Não cria integração externa nova.

## 3. Escopo da Entrega

### 3.1. Dentro do escopo

- `GET /v1/kids/signals`: fila paginada de sinalizações correntes em `awaitingConfirmation`, exclusiva de Administradores e ordenada da mais antiga para a mais recente, com `signalId` como desempate estável.
- `GET /v1/kids/signals/{signalId}`: detalhe administrativo somente da sinalização ainda corrente, com tarefa, responsáveis, criança que sinalizou, instante e presença de foto.
- `POST /v1/kids/signals/{signalId}/decision`, com `decision: confirm | reject`:
  - confirmar conclui a tarefa para todos os responsáveis finais, registra o Administrador e atualiza crédito e missões na mesma transação;
  - recusar devolve a tarefa a `pending`, registra a decisão e não gera crédito, progresso ou avanço de missão.
- Reconciliação silenciosa: se a sinalização já foi decidida ou encerrada por conclusão manual, o comando retorna `200 OK` com o estado canônico, sem repetir efeitos e sem apresentar conflito ao mobile.
- Autorização de leitura privada de `taskSignal` via `GET /v1/media/{mediaId}/content` somente ao Administrador da mesma família enquanto a sinalização estiver corrente e avaliável.
- Persistência administrativa de eventos de sinalização, decisão ou encerramento manual, sem criar histórico navegável no app nesta entrega.

### 3.2. Fora do escopo

- Criar a sinalização, capturar/enviar/revisar foto e a experiência Kids de TEL-041/MOD-011 — SPEC-012.
- Conclusão manual de tarefa com responsável Kids — SPEC-010.
- Edição, exclusão e resolução de sinalização durante edição de tarefa — SPEC-007.
- Reabertura de tarefa, notificações, histórico navegável de sinalizações e qualquer ação de Membro/Kids na fila administrativa.

### 3.3. Fora de questão (Anti-requisitos / Suposições descartadas)

- Membro e Kids não podem listar, abrir, decidir nem ler foto de sinalização.
- A ausência de foto não bloqueia a confirmação.
- Não há conclusão parcial, divisão do peso, segunda confirmação nem escolha de responsáveis ao confirmar.
- Sinalização resolvida não permanece em `GET /kids/signals` e não recebe tela de histórico.
- O mobile não reenvia automaticamente comandos; o sucesso silencioso para um comando tardio não reaplica a decisão nem altera o histórico.

## 4. Perfis, Atores e Regras de Autorização (RBAC)

| Perfil | Pode | Não pode | Reação do sistema a tentativa não autorizada |
|---|---|---|---|
| **Administrador** | Listar/abrir sinalização corrente da própria família, ler sua foto privada e confirmar/recusar | Acessar outra família; criar nova sinalização por esta rota | `404 RESOURCE_NOT_FOUND` para outro recurso; ação disponível apenas quando corrente |
| **Membro** | — | Fila, detalhe, decisão e foto de sinalização | `403 ACTION_NOT_ALLOWED` / ação ausente na UI |
| **Kids** | — | Fila, detalhe, decisão e foto de sinalização | `403 ACTION_NOT_ALLOWED` / ação ausente na UI |

- **Isolamento multitenant familiar (RNF06):** `signalId`, tarefa ou mídia de outra família respondem `404 RESOURCE_NOT_FOUND`, sem revelar existência, foto ou metadados.
- **Revalidação (RNF07):** papel, família, sinalização corrente e vínculo da mídia são revalidados no backend dentro do comando, mesmo que a UI oculte ações não permitidas.

## 5. Contrato de Dados, Interface e Validações

### 5.1. Dicionário de campos

| Campo | Tipo | Obrigatório? | Validação | Erro |
|---|---|---|---|---|
| `signalId` (path) | UUID | Sim | Identifica sinalização da família do ator | `RESOURCE_NOT_FOUND` |
| `decision` | enum | Sim | Exatamente `confirm` ou `reject`; body sem campos adicionais | `VALIDATION_FAILED` / `UNKNOWN_FIELD` |
| `cursor` | string opaca | Não | Cursor emitido para a mesma ordenação/filtro | `VALIDATION_FAILED` |

### 5.2. Contratos compartilhados

Todos exigem sessão válida e usam `/v1`.

- **`GET /kids/signals`** — retorna somente sinalizações correntes da família do Administrador, ordenadas por `signaledAt` crescente e `signalId` crescente. Cada item contém `signalId`, resumo da tarefa, criança que sinalizou, `signaledAt` e `hasPhoto`; usa cursor opaco.
- **`GET /kids/signals/{signalId}`** — retorna uma sinalização corrente com tarefa, responsáveis, criança que sinalizou, `signaledAt`, `hasPhoto` e capacidades de decisão. Sinalização que já não esteja corrente responde `404 RESOURCE_NOT_FOUND`, porque não há histórico navegável.
- **`POST /kids/signals/{signalId}/decision`** — recebe `{ "decision": "confirm" }` ou `{ "decision": "reject" }` e retorna `200 OK` com `task`, `decisionOutcome` (`confirmed`, `rejected` ou `closedByManualCompletion`) e `applied`.
  - Na primeira decisão válida, `applied` é `true`.
  - Se já houve confirmação, recusa ou conclusão manual, `applied` é `false`; o status é `200 OK` e `task` traz o estado canônico. Não há segunda escrita, crédito, evento de decisão ou confirmação da interface.

Erros seguem RFC 9457: `401 SESSION_EXPIRED`, `403 ACTION_NOT_ALLOWED`, `404 RESOURCE_NOT_FOUND`, `400 UNKNOWN_FIELD`, `422 VALIDATION_FAILED` e `429 RATE_LIMIT_EXCEEDED`. O retorno silencioso de decisão já resolvida é uma exceção deliberada aos conflitos de estado, definida por esta SPEC.

### 5.3. Concorrência, idempotência e falhas

- O comando é serializado com a atualização da tarefa e das missões afetadas. A primeira transição válida aplica seus efeitos uma única vez.
- Não existe `Idempotency-Key` nem reenvio automático. Em resposta perdida, o app consulta fila/detalhe/tarefa antes de oferecer nova ação.
- A resposta bem-sucedida tardia elimina ruído visual, mas nunca mascara falha de rede: sem resposta, o app não anuncia sucesso.
- Falha de leitura da foto não altera a tarefa; a tela apresenta falha e permite sair/atualizar, sem liberar acesso alternativo à mídia.

## 6. Estados de Domínio e Transições

| Estado De | Evento | Estado Para | Quem | Efeitos |
|---|---|---|---|---|
| `awaitingConfirmation` | Confirmar | `completed` | Administrador | Registra `confirmed`/quem confirmou, cria conclusão `kidsConfirmation`, credita responsáveis finais e atualiza missões |
| `awaitingConfirmation` | Recusar | `pending` | Administrador | Registra `rejected`; não cria crédito, progresso ou efeito em missão |
| `awaitingConfirmation` | Conclusão manual | `completed` | Administrador (SPEC-010) | Registra `closedByManualCompletion`; preserva evidência administrativa |
| `pending` ou `completed` após decisão anterior | Decisão tardia | Mantém estado canônico | Administrador | `200 OK`, `applied: false`, nenhuma escrita adicional |

## 7. Critérios de Aceitação (BDD Formal)

- **CA-01: fila administrativa ordenada**
  - **DADO QUE** um Administrador possui sinalizações correntes na própria família,
  - **QUANDO** consultar `GET /v1/kids/signals`,
  - **ENTÃO O SISTEMA DEVE** devolver somente sinalizações `awaitingConfirmation`, em ordem da mais antiga para a mais recente,
  - **E** usar `signalId` como desempate estável. *(UC03, RN24)*

- **CA-02: detalhe e foto privada**
  - **DADO QUE** um Administrador abre uma sinalização corrente da própria família,
  - **QUANDO** consultar seu detalhe e houver foto,
  - **ENTÃO O SISTEMA DEVE** devolver tarefa, responsáveis, criança, instante e capacidade de leitura da foto,
  - **E** autorizar o streaming somente para esse Administrador da família. *(RF25, RF55, RN54, RNF24)*

- **CA-03: confirmação única**
  - **DADO QUE** a tarefa está `awaitingConfirmation`,
  - **QUANDO** um Administrador enviar `decision: confirm`,
  - **ENTÃO O SISTEMA DEVE** concluí-la para todos os responsáveis finais e registrar quem confirmou,
  - **E** creditar o peso integral uma vez por responsável e atualizar missões na mesma transação. *(UC03, RN22–26, RN30, RN35, RN55–56)*

- **CA-04: recusa sem crédito**
  - **DADO QUE** a tarefa está `awaitingConfirmation`,
  - **QUANDO** um Administrador enviar `decision: reject`,
  - **ENTÃO O SISTEMA DEVE** devolvê-la a `pending`,
  - **E** não criar crédito, progresso concluído nem efeito em missão. *(UC03, RN24, RN26)*

- **CA-05: autorização e isolamento**
  - **DADO QUE** o ator é Membro, Kids ou pertence a outra família,
  - **QUANDO** tentar listar, abrir, decidir ou ler foto de uma sinalização,
  - **ENTÃO O SISTEMA DEVE** recusar Membro/Kids com `403 ACTION_NOT_ALLOWED` e recurso externo com `404 RESOURCE_NOT_FOUND`,
  - **E** não revelar metadados nem conteúdo privado. *(RNF06, RNF07, RNF24)*

- **CA-06: concorrência silenciosa**
  - **DADO QUE** outro Administrador já decidiu ou uma conclusão manual encerrou a pendência,
  - **QUANDO** um Administrador enviar uma decisão tardia para o mesmo `signalId`,
  - **ENTÃO O SISTEMA DEVE** responder `200 OK` com a tarefa canônica e `applied: false`,
  - **E** não duplicar decisão, conclusão, crédito ou efeito em missão. *(RN23–24, RNF11, MA-08)*

- **CA-07: falha ou resposta perdida**
  - **DADO QUE** o mobile não receba resposta da decisão,
  - **QUANDO** identificar timeout ou indisponibilidade,
  - **ENTÃO O SISTEMA NÃO DEVE** apresentar a decisão como concluída,
  - **E** o app DEVE consultar o estado atual antes de permitir uma nova ação explícita. *(RNF12–13, MA-07–08)*

## 8. Observabilidade, Métricas e Auditoria

| Evento | Tipo | Propriedades seguras |
|---|---|---|
| `kids_signal_confirmed` | Métrica/auditoria | `signalId`, `taskId`, `familyId`, `confirmedBy`, sem foto |
| `kids_signal_rejected` | Métrica/auditoria | `signalId`, `taskId`, `familyId`, `rejectedBy`, sem foto |
| `kids_signal_decision_reconciled` | Métrica | `signalId`, `decisionOutcome`, sem conteúdo privado |
| `kids_signal_access_denied` | Log de segurança | `requestId`, `actorId`, código, sem foto/token |

## 9. Premissas e Esclarecimentos

### 9.1. Premissas

- **P-01:** `signalId` é a identidade estável criada pela SPEC-012 e protege a decisão contra uma sinalização posterior.
- **P-02:** fotos de sinalização ficam privadas no R2; o backend transmite conteúdo apenas após revalidar finalidade, família e capacidade administrativa.

### 9.2. Decisões confirmadas

| # | Decisão | Decidido por / Data | Altera `docs/`? |
|---|---|---|---|
| E-01 | Decisão tardia retorna sucesso canônico e silencioso, sem nova confirmação nem efeitos duplicados. | Pessoa usuária / 2026-10-08 | Sim — `backend-contracts.md` |
| E-02 | Não haverá histórico navegável de sinalizações no app; a fila contém somente pendências. O registro administrativo permanece persistido. | Pessoa usuária / 2026-10-08 | Não |
| E-03 | A fila é ordenada da sinalização mais antiga para a mais recente. | Pessoa usuária / 2026-10-08 | Sim — `backend-contracts.md` |

## 10. Fases de Implementação e Critérios de Conclusão

| Fase | Objetivo | Critérios atendidos | Prontidão | Status |
|---|---|---|---|---|
| **1** | API, transação, RBAC, isolamento, mídia privada e concorrência | CA-01 a CA-06 | Testes unitários e de integração verdes; contrato atualizado | a fazer |
| **2** | TEL-015/TEL-016 e integração mobile acessível | CA-01, CA-02, CA-05, CA-06 | Testes de UI e UX-spec verificada | a fazer |
| **3** | Resiliência e observabilidade | CA-07 | Regressão e telemetria verificadas | a fazer |

- **Fora da Fase 1:** não há superfície mobile nova; a capacidade é verificável apenas pela API.
- **Publicação independente:** Fase 1 não deve ser publicada isoladamente; Fase 2 completa o ciclo visível ao Administrador.

## 11. Checklist de Aprovação da Spec (Definition of Ready)

- [x] Códigos funcionais e de design existem na base vigente.
- [x] Dependência SPEC-012 está aprovada.
- [x] Contrato, concorrência, autorização e isolamento foram definidos.
- [x] UX-spec correspondente foi criada como rascunho.
- [x] Decisões E-01 a E-03 estão registradas.
- [ ] Status `aprovada` autorizado explicitamente para esta SPEC e UX-spec.
