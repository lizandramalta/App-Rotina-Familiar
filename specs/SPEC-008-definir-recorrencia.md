# Spec 008: Definir recorrência de rotina

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Reaprovada em:** 2026-10-27
**Base funcional:** RN 1.21 / RF 1.20 / UC 1.20 (revisada em 2026-10-27, E-05 a E-14)
**UX-spec:** [UX-008-definir-recorrencia.md](UX-008-definir-recorrencia.md)
**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 2 — Tarefas e rotina

## 1. Contexto e objetivo

- **Problema / necessidade:** uma tarefa única não representa responsabilidades que se repetem. A família precisa configurar uma rotina sem perder a autonomia e o histórico de cada ocorrência.
- **Objetivo da entrega:** permitir que Administradores e Membros criem, consultem, atualizem e encerrem a geração futura de uma rotina, com ocorrências independentes, materialização confiável e preservação do passado.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Casos de uso | UC08 |
| Regras de negócio | RN11, RN12, RN13, RN14, RN16, RN17, RN18, RN19, RN20, RN67 |
| Requisitos funcionais | RF13, RF14, RF15, RF16, RF27, RF70 |
| Requisitos não funcionais | RNF01, RNF02, RNF05, RNF06, RNF07, RNF08, RNF09, RNF12, RNF13, RNF14, RNF22, RNF25 |
| Telas e fluxos de navegação | TEL-012, TEL-013, MOD-002, MOD-003, UF-05 |
| Decisões arquiteturais aplicáveis | MA-07; BA-07, BA-08 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-architecture.md`, `docs/architecture/mobile-feature-catalog.md`, `docs/architecture/backend-contracts.md` e `docs/architecture/backend-decisions.md`.
- **Depende de:** [SPEC-007-gerenciar-tarefas.md](SPEC-007-gerenciar-tarefas.md), aprovada. Ela fornece os campos, a consulta da ocorrência e as proteções individuais de tarefa.
- **Dependências externas e infraestrutura:** banco transacional e o processamento de materialização do backend; não há serviço externo adicional.

## 3. Escopo da entrega

### 3.1. Dentro do escopo

- `POST /v1/routines` para criar a configuração de rotina e iniciar a materialização das ocorrências.
- `GET /v1/routines/{routineId}` para consultar configuração, versão vigente e progresso de materialização.
- `PATCH /v1/routines/{routineId}` para alterar título, peso, responsáveis e observação da ocorrência de origem indicada por `fromTaskId` e das futuras elegíveis.
- `POST /v1/routines/{routineId}/future-task-deletions` para encerrar a geração no alcance que começa na ocorrência de origem e preserva os registros obrigatórios.
- Frequências diária, ou a cada 7, 14, 21 ou 28 dias; início livre; título, peso, responsáveis opcionais e observação opcional.
- Materialização até o fim do mês seguinte no fuso familiar, reposição diária e complemento em consulta sem duplicação.
- Autorização, isolamento familiar, validações e respostas de falha desde a primeira fase.

### 3.2. Fora do escopo

- Criar ou editar tarefa única, concluir, reabrir, sinalizar ou validar tarefa Kids: SPEC-007, SPEC-010, SPEC-011, SPEC-012 e SPEC-013.
- Listagens de tarefas e indicadores: SPEC-009 e SPEC-018.
- Missões, recompensas, alteração de fuso, recorrência mensal, intervalos arbitrários e uma tela para definir data final.

### 3.3. Fora de questão

- Não existe `endDate` obrigatório, opcional ou aceito no contrato. O horizonte de materialização não encerra uma rotina.
- Não há frequência mensal, semanal arbitrária, intervalo zero ou frequência fora de 1/7/14/21/28.
- “Selecionada e futuras” inclui a ocorrência indicada por `fromTaskId`; não inclui passado, ocorrências concluídas nem registros protegidos por missão concluída.
- “Selecionada e futuras” não altera `startDate`, `frequencyDays` nem a data prevista já gravada de cada ocorrência abrangida, mesmo após edição individual; ela substitui edições individuais anteriores dos campos permitidos nas futuras abrangidas (E-05, E-06).
- “Selecionada e futuras” não altera o estado das ocorrências; a escolha do RN66 vale somente para a edição individual (E-08). As futuras são as ocorrências com `original_date` igual ou posterior ao da origem (E-09).
- A configuração recorrente não conclui, reabre ou altera automaticamente outras ocorrências já preservadas.
- Não há `Idempotency-Key`, replay automático de gravação ou controle de versão otimista. A última gravação válida persistida vence; materialização usa origem estável e transação para não duplicar ocorrências.
- O mobile não grava rotinas offline. Em falha, preserva apenas o rascunho local e aguarda nova ação explícita.

## 4. Perfis, atores e autorização

| Perfil | Pode | Não pode | Reação à tentativa não autorizada |
|---|---|---|---|
| Administrador | Criar, consultar, alterar e encerrar geração futura de qualquer rotina da família | Alterar passado, concluídas ou dados protegidos | `403 ACTION_NOT_ALLOWED`; entrada oculta na UI |
| Membro | As mesmas ações de rotina da família, respeitando alcance e proteções | Alterar passado, concluídas ou dados protegidos | `403 ACTION_NOT_ALLOWED`; entrada oculta na UI |
| Kids | Consultar apenas as próprias ocorrências pelos fluxos de consulta aplicáveis, fora desta entrega | Criar, editar ou excluir rotina/ocorrências | `403 ACTION_NOT_ALLOWED`; ações e caminhos ocultos |

- **Isolamento familiar (RNF06):** uma rotina ou ocorrência de outra família responde `404 RESOURCE_NOT_FOUND`, sem existência, contagem ou metadados.
- **Autorização no backend (RNF07):** toda rota revalida sessão, papel, família e estado atual após adquirir qualquer lock ou iniciar transação.

## 5. Contrato de dados, interface e validações

### 5.1. Dicionário de campos

| Campo | Tipo | Obrigatório | Validação | Código de erro |
|---|---|---:|---|---|
| `title` | string | Sim ao criar; opcional ao alterar | 1–60 caracteres Unicode visíveis após `trim`, sem caracteres de controle | `TITLE_REQUIRED`, `TITLE_INVALID_LENGTH` |
| `weight` | integer | Sim ao criar; opcional ao alterar | 1, 2 ou 3 | `WEIGHT_REQUIRED`, `WEIGHT_INVALID` |
| `assigneeIds` | array de UUID | Não | Todos pertencem à família; lista vazia remove responsáveis; duplicados são deduplicados | `ASSIGNEE_NOT_IN_FAMILY` |
| `note` | string ou `null` | Não | Até 250 caracteres contando espaços; `null` remove a observação | `NOTE_TOO_LONG` |
| `startDate` | string | Sim ao criar; não aceito ao alterar (`400 UNKNOWN_FIELD`) | Data civil `YYYY-MM-DD`, passada ou futura, sem limite de produto | `START_DATE_INVALID` |
| `frequencyDays` | integer | Sim ao criar; não aceito ao alterar (`400 UNKNOWN_FIELD`) | Somente 1, 7, 14, 21 ou 28 | `FREQUENCY_DAYS_INVALID` |
| `fromTaskId` | UUID | Sim em alteração e encerramento futuro | Ocorrência da rotina na família do ator; define o primeiro registro alcançado. ID de outra família é indisponível | `ROUTINE_SOURCE_TASK_INVALID` |

Campos omitidos em `PATCH` são preservados; campos desconhecidos ou protegidos são recusados. Não existe `endDate`.

### 5.2. Rotas e respostas

#### Criar rotina

- **Método e rota:** `POST /v1/routines`
- **Autenticação:** Bearer de Administrador ou Membro ativo.

```json
{
  "title": "Separar recicláveis",
  "weight": 2,
  "assigneeIds": ["a1b2c3d4-e5f6-7890-abcd-ef1234567890"],
  "note": "Lavar as embalagens antes",
  "startDate": "2026-10-10",
  "frequencyDays": 7
}
```

- **Sucesso:** `201 Created`, com a configuração canônica e sua situação de materialização. Uma rotina salva pode retornar `materializationState: "pending"`; isso não confirma que todas as ocorrências já estão disponíveis.

#### Consultar, atualizar e encerrar geração futura

| Rota | Finalidade | Entrada | Sucesso |
|---|---|---|---|
| `GET /v1/routines/{routineId}` | Consultar rotina | — | Configuração, versão vigente e progresso de materialização |
| `PATCH /v1/routines/{routineId}` | Atualizar selecionada e futuras | `fromTaskId` e, opcionalmente, `title`, `weight`, `assigneeIds`, `note` | `200` com `{ routine, updatedTaskIds, preservedTaskIds }` (E-13) |
| `POST /v1/routines/{routineId}/future-task-deletions` | Encerrar geração selecionada e futura | `fromTaskId` | `200` com `{ routineId, deletedTaskIds, preservedTaskIds, generationEnded }` (E-13) |

Uma consulta dependente de materialização incompleta pode devolver `202 Accepted`, com estado `preparing` e `Retry-After`. A interface mantém o estado de preparação e não apresenta totais como finais.

### 5.3. Erros, concorrência e falhas

| HTTP | Código | Situação |
|---:|---|---|
| 400 | `UNKNOWN_FIELD` | Campo desconhecido, protegido ou `endDate` enviado; `startDate`/`frequencyDays` enviados em alteração |
| 403 | `ACTION_NOT_ALLOWED` | Perfil Kids ou capacidade revogada |
| 404 | `RESOURCE_NOT_FOUND` | Rotina/ocorrência inexistente ou de outra família |
| 409 | `MISSION_COMPLETED_PROTECTED` | A ocorrência de origem está protegida por missão concluída; futuras protegidas são apenas preservadas (E-10) |
| 409 | `MISSION_WOULD_HAVE_NO_TASKS` | O encerramento deixaria uma missão em andamento sem tarefas; nada é excluído (E-11) |
| 422 | `VALIDATION_FAILED` | Campo inválido; inclui os códigos da tabela 5.1 em `fieldErrors` |
| 503 | `DEPENDENCY_UNAVAILABLE` | Persistência ou materialização incerta; não afirmar reversão |

- Erros usam `application/problem+json` com `type`, `title`, `status`, `code`, `requestId` e `fieldErrors` quando aplicável.
- O backend serializa as escritas necessárias, revalida estado/permissão e usa chave de origem estável para impedir duplicação de ocorrências.
- Em resposta perdida, o mobile não reenvia `POST`/`PATCH`/`POST` de encerramento automaticamente; consulta o estado antes de orientar nova tentativa. Sem ID retornado na criação, informa que a criação pode estar incerta e preserva o rascunho.

## 6. Estados de domínio e transições

| Estado | Evento | Resultado | Autor | Garantias |
|---|---|---|---|---|
| inexistente | `CreateRoutine` | rotina ativa + materialização iniciada | Administrador/Membro | Configuração válida, sem `endDate`, ocorrências com origem estável |
| ativa, materialização pendente | processamento/consulta | ativa, progresso atualizado | sistema | Processa em lotes; não duplica nem apresenta total final prematuramente |
| ativa | `UpdateFutureRoutine` | nova configuração a partir de `fromTaskId` | Administrador/Membro | Inclui origem e futuras elegíveis; preserva passado, concluídas e protegidas |
| ativa | `DeleteFutureRoutineTasks` | geração encerrada no alcance permitido | Administrador/Membro | Inclui origem e futuras elegíveis; preserva registros obrigatórios |
| qualquer | tentativa Kids ou família alheia | sem mudança | Kids/terceiro | `403` ou `404`, sem vazamento |

## 7. Critérios de aceitação

- **CA-01: criar rotina válida**
  - **DADO QUE** um Administrador ou Membro ativo informa título, peso, início, frequência válida e responsáveis opcionais,
  - **QUANDO** enviar `POST /v1/routines`,
  - **ENTÃO O SISTEMA DEVE** salvar a rotina com observação opcional e sem exigir data final,
  - **E** responder `201 Created` com a configuração e o estado de materialização. *(UC08, RN14, RF13)*

- **CA-02: validar frequência e início**
  - **DADO QUE** `frequencyDays` não é 1, 7, 14, 21 ou 28, ou `startDate` não é uma data civil válida,
  - **QUANDO** o comando for processado,
  - **ENTÃO O SISTEMA DEVE** recusar com `422 VALIDATION_FAILED`,
  - **E** devolver respectivamente `FREQUENCY_DAYS_INVALID` ou `START_DATE_INVALID` em `fieldErrors`. *(RN14, RF13/14)*

- **CA-03: Kids sem permissão**
  - **DADO QUE** a sessão pertence a Kids,
  - **QUANDO** tentar criar, atualizar ou encerrar uma rotina,
  - **ENTÃO O SISTEMA DEVE** rejeitar sem persistir alteração,
  - **E** responder `403 ACTION_NOT_ALLOWED`. *(RN19, RF27, RNF07)*

- **CA-04: isolamento multitenant**
  - **DADO QUE** a rotina ou ocorrência pertence a outra família,
  - **QUANDO** um usuário tentar consultá-la ou usá-la como origem,
  - **ENTÃO O SISTEMA DEVE** responder `404 RESOURCE_NOT_FOUND`,
  - **E** não revelar dados, contagem ou metadados. *(RNF06)*

- **CA-05: materializar sem duplicação**
  - **DADO QUE** uma rotina válida começa no passado, dentro ou depois do horizonte,
  - **QUANDO** o backend materializar ou completar em consulta,
  - **ENTÃO O SISTEMA DEVE** respeitar o início, processar em lotes quando necessário e materializar até o fim do mês seguinte,
  - **E** não duplicar uma ocorrência após retentativa. *(RN14, RF13)*

- **CA-06: ocorrências independentes**
  - **DADO QUE** uma rotina tenha mais de uma ocorrência,
  - **QUANDO** uma ocorrência for consultada ou concluída por fluxo posterior,
  - **ENTÃO O SISTEMA DEVE** preservar identificação e estado próprios,
  - **E** não alterar as demais só por pertencerem à mesma rotina. *(RN16, UC08)*

- **CA-07: atualizar selecionada e futuras**
  - **DADO QUE** uma ocorrência válida de rotina foi indicada em `fromTaskId`,
  - **QUANDO** um adulto atualizar a rotina,
  - **ENTÃO O SISTEMA DEVE** aplicar a configuração à ocorrência indicada e às futuras elegíveis,
  - **E** preservar o passado, concluídas e dados protegidos por missão concluída,
  - **E** substituir edições individuais anteriores dos campos permitidos nas ocorrências futuras abrangidas,
  - **E** manter data inicial, frequência e a data prevista já gravada de cada ocorrência, mesmo após edição individual; `startDate` ou `frequencyDays` enviados são recusados com `400 UNKNOWN_FIELD`, sem mudança,
  - **E** não alterar o estado das ocorrências abrangidas; `signalResolution` enviado é recusado com `400 UNKNOWN_FIELD`. *(RN17, RN66, RF13)*

- **CA-08: encerrar geração futura preservando registros**
  - **DADO QUE** uma ocorrência válida de rotina foi indicada em `fromTaskId`,
  - **QUANDO** um adulto encerrar a geração futura,
  - **ENTÃO O SISTEMA DEVE** alcançar a ocorrência indicada e as futuras elegíveis,
  - **E** não excluir diretamente ocorrências concluídas ou protegidas,
  - **E** recusar sem mudança, com `409 MISSION_WOULD_HAVE_NO_TASKS`, quando deixaria uma missão em andamento sem tarefas,
  - **E** encerrar a geração da rotina, sem criar novas ocorrências. *(RN18, RN38, RNF09)*

- **CA-09: origem inválida**
  - **DADO QUE** `fromTaskId` identifica uma ocorrência da família do ator, mas não da rotina solicitada,
  - **QUANDO** ocorrer atualização ou encerramento futuro,
  - **ENTÃO O SISTEMA DEVE** recusar sem mudança,
  - **E** responder `422 VALIDATION_FAILED` com `ROUTINE_SOURCE_TASK_INVALID`. *(RNF06, RNF09)*

- **CA-10: preparação e resposta perdida**
  - **DADO QUE** a materialização esteja incompleta ou a resposta de uma gravação se perca,
  - **QUANDO** o mobile receber `202` ou não puder confirmar a persistência,
  - **ENTÃO O SISTEMA NÃO DEVE** exibir sucesso ou totais finais como confirmados,
  - **E** DEVE preservar o rascunho e permitir consulta/nova tentativa explícita sem replay automático. *(RNF12, RNF13, MA-07)*

## 8. Observabilidade e auditoria

| Evento | Gatilho | Dados permitidos |
|---|---|---|
| `routine_created` | Configuração persistida | `routineId`, `familyId`, `frequencyDays`, `hasAssignee`, `hasNote` |
| `routine_materialization_progressed` | Lote confirmado | `routineId`, `familyId`, `horizonDate`, `state` |
| `routine_updated` | Selecionada e futuras persistidas | `routineId`, `familyId`, `fromTaskId` |
| `routine_generation_ended` | Encerramento futuro confirmado | `routineId`, `familyId`, `fromTaskId`, `preservedCount` |
| `routine_management_denied` | Permissão, isolamento ou estado bloqueou ação | `requestId`, `actorId`, `code` |

Segredos, tokens, conteúdo da observação e dados de outras famílias nunca são registrados.

## 9. Premissas e esclarecimentos

| # | Decisão | Situação | Altera `docs/`? |
|---|---|---|---|
| E-01 | A configuração de rotina aceita `note` opcional, com o mesmo limite de 250 caracteres da tarefa. | Decidida em 2026-10-06 | Sim — RN14/RN67, RF13/RF70, DER, classes e contratos |
| E-02 | “Selecionada e futuras” inclui a ocorrência indicada por `fromTaskId`. | Decidida em 2026-10-06 | Sim — RN17, RF13, UC08, design e contratos |
| E-03 | Validações de rotina usam `FREQUENCY_DAYS_INVALID`, `START_DATE_INVALID` e `ROUTINE_SOURCE_TASK_INVALID`. | Decidida em 2026-10-06 | Sim — contratos backend |
| E-04 | Não há data final obrigatória nem campo `endDate`; o horizonte de materialização não encerra a rotina. | Confirmada pela base vigente em 2026-10-06 | Sim — RN14, RF13, UC08, UX e contratos foram explicitados |
| E-05 | “Selecionada e futuras” não altera a repetição: `startDate` e `frequencyDays` não são aceitos no `PATCH`; somente título, peso, responsáveis e observação mudam. | Decidida em 2026-10-27 | Sim — RN17 1.20, RF13 1.19, UC08 1.19 e contratos 1.21 |
| E-06 | “Selecionada e futuras” substitui edições individuais anteriores das ocorrências futuras abrangidas. | Decidida em 2026-10-27 | Sim — RN17 1.20, RF13 1.19, UC08 1.19 e contratos 1.21 |
| E-07 | A data prevista fica somente leitura no alcance “selecionada e futuras”; em “somente esta tarefa” (edição individual, SPEC-007) ela continua editável. | Decidida em 2026-10-27 | Sim — RN17 1.20, UC08 1.19; apresentação na UX-008 |
| E-08 | “Selecionada e futuras” altera somente dados e não muda o estado das ocorrências; a escolha entre Pendente e Aguardando confirmação (RN66, MOD-014) vale somente para a edição individual. | Decidida em 2026-10-27 | Sim — RN66 1.20, UC07 1.19 e contratos 1.21 |
| E-09 | As futuras são as ocorrências com `original_date` igual ou posterior ao da origem, inclusive as que tiveram a data prevista alterada individualmente. | Decidida em 2026-10-27 | Sim — contratos 1.21 |
| E-10 | Origem protegida por missão concluída responde `409 MISSION_COMPLETED_PROTECTED` sem mudança; futuras protegidas são preservadas e listadas em `preservedTaskIds`. | Decidida em 2026-10-27 | Sim — contratos 1.21 |
| E-11 | O encerramento que deixaria uma missão em andamento sem tarefas responde `409 MISSION_WOULD_HAVE_NO_TASKS` sem mudança, como na exclusão individual. | Decidida em 2026-10-27 | Sim — contratos 1.21 |
| E-12 | Encerrar a geração marca a rotina como inativa (`is_active=false`, `deactivated_at`); ela não materializa novas ocorrências e as anteriores à origem permanecem. | Decidida em 2026-10-27 | Sim — contratos 1.21 |
| E-13 | Respostas `200`: alteração → `{ routine, updatedTaskIds, preservedTaskIds }`; encerramento → `{ routineId, deletedTaskIds, preservedTaskIds, generationEnded }`. | Decidida em 2026-10-27 | Sim — contratos 1.21 |
| E-14 | A edição “selecionada e futuras” preserva a data prevista já gravada de cada ocorrência abrangida, inclusive quando alterada individualmente; a substituição de edições anteriores limita-se aos campos permitidos. | Decidida em 2026-10-27 | Sim — RN17 1.21, RF13 1.20, UC08 1.20 e contratos 1.22 |

## 10. Fases de implementação e conclusão

| Fase | Objetivo | CAs | Prontidão | Status |
|---|---|---|---|---|
| 1 | Criar/consultar rotina, validações, autorização, isolamento e materialização segura | CA-01 a CA-06 | Testes unitários e de integração verdes, incluindo famílias distintas e retentativas | a fazer |
| 2 | Alterar e encerrar selecionada e futuras, preservando histórico | CA-07 a CA-09 | Transações e testes de proteção de missão/conclusão verdes | a fazer |
| 3 | Integrar UX, preparação e resposta incerta | CA-10 | UX-spec verificada e testes de interface/regressão verdes | a fazer |

- **Fase 1:** não oferece edição/encerramento futuro na UI; não deve ser publicada isoladamente.
- **Fase 2:** disponibiliza o comportamento completo de rotina junto da Fase 1.
- **Fase 3:** não altera regras de domínio; fortalece a experiência de materialização e falha.

## 11. Checklist de aprovação

- [x] Códigos funcionais, UX e arquiteturais pesquisados e existentes.
- [x] Dependência SPEC-007 aprovada.
- [x] Autorização, isolamento e validação atribuídos à Fase 1.
- [x] Contratos, erros e resultado incerto definidos.
- [x] UX-spec vinculada.
- [x] Decisões E-01 a E-04 refletidas na base documental 1.8.
- [x] Status `aprovada` autorizado em 2026-10-06; esclarecimento E-14 e prévia técnica do SCRUM-45 confirmados pela pessoa usuária em 2026-10-27.
