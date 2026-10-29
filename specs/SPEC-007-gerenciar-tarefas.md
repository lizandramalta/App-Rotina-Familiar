# Spec 007: Gerenciar tarefas

**Status:** aprovada
**Autor:** Claude | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06
**Base funcional:** 1.18
**UX-spec:** [UX-007-gerenciar-tarefas.md](UX-007-gerenciar-tarefas.md)
**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 2 - Tarefas e rotina

## 1. Contexto e Objetivo

- **Problema / Necessidade:** antes de qualquer rotina, conclusão ou missão poder existir, a família precisa conseguir criar, editar e excluir a tarefa avulsa — a unidade básica de trabalho doméstico — com responsáveis opcionais e sob as proteções de histórico e de missões já concluídas.
- **Objetivo da entrega:** permitir que Administradores e Membros criem, consultem, editem e excluam tarefas únicas (não recorrentes), incluindo a interação obrigatória com uma sinalização Kids pendente ao editar ou excluir, sem nunca corromper créditos, auditoria ou conquistas preservadas.

## 2. Rastreabilidade e Dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Casos de uso | UC07 |
| Regras de negócio | RN11, RN12, RN13, RN17, RN18, RN19, RN20, RN30, RN38, RN50, RN53, RN58, RN59, RN66, RN67 |
| Requisitos funcionais | RF07, RF08, RF09, RF10, RF15, RF16, RF27, RF58, RF59, RF69, RF70 |
| Requisitos não funcionais | RNF01, RNF02, RNF05, RNF06, RNF07, RNF08, RNF09, RNF10, RNF12, RNF13, RNF14 |
| Telas e fluxos de navegação | TEL-011, TEL-012 (parcial), TEL-013 (parcial), MOD-001, MOD-005, MOD-014, UF-05 (ramo tarefa única), UF-08 (ramo exclusão) |
| Decisões arquiteturais aplicáveis | MA-07 (verdade remota, sem gravação offline); BA-07 (última gravação válida vence; sem idempotência geral nem versão otimista) |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-feature-catalog.md`, `docs/architecture/backend-contracts.md`, `docs/architecture/backend-decisions.md`.
- **Depende de:** [SPEC-002-criar-configurar-familia.md](SPEC-002-criar-configurar-familia.md), aprovada. A família e seu fuso já existem antes de haver tarefas.
- **Dependências externas e infraestrutura:** nenhuma além do banco transacional do backend.

## 3. Escopo da Entrega

### 3.1. Dentro do escopo

- `POST /v1/tasks`: criar tarefa única (não recorrente) com `title`, `weight`, `scheduledDate`, `assigneeIds` opcional e `note` opcional.
- `GET /v1/tasks/{taskId}`: detalhe da tarefa, suporte às telas de edição e exclusão.
- `PATCH /v1/tasks/{taskId}`: editar título, peso, data prevista, responsáveis e observação de uma ocorrência, inclusive quando `completed` e não protegida por missão concluída (RN17); exige `signalResolution` quando o estado atual é `awaitingConfirmation`.
- `DELETE /v1/tasks/{taskId}`: excluir tarefa não concluída; remove vínculo com missão em andamento e recalcula progresso (RF59), concluindo a missão na mesma transação se restarem apenas tarefas concluídas (RN38); remove sinalização Kids corrente sem registrar decisão quando o estado é `awaitingConfirmation`.
- Autorização exclusiva de Administrador/Membro (RN20); Kids bloqueados (RF27/RN19/RNF07).
- Isolamento multitenant (RNF06) em todas as operações.
- TEL-011, TEL-012 (somente as ações Editar e Excluir), TEL-013 (somente o bloco de tarefa única), MOD-001, MOD-005, MOD-014.

### 3.2. Fora do escopo

- Configuração de recorrência/rotina e exclusão em lote "selecionada e futuras" (`POST /v1/routines`, `PATCH /v1/routines/{id}`, `POST /v1/routines/{id}/future-task-deletions`) — UC08/SPEC-008. Nenhuma tarefa criada por esta entrega tem rotina.
- Concluir tarefa (`POST /v1/tasks/{taskId}/completion`) — UC12/SPEC-010.
- Reabrir tarefa (`POST /v1/tasks/{taskId}/reopening`) — UC17/SPEC-011.
- Listagens `GET /v1/me/tasks`, `GET /v1/family/tasks`, `GET /v1/family/members/{id}/tasks` — UC11/SPEC-009.
- Criar ou decidir sinalização Kids (`POST /v1/tasks/{taskId}/signals`, fila de confirmação) — UC15/UC03/SPEC-012/SPEC-013. Esta entrega apenas reage a uma sinalização já existente ao editar/excluir.

### 3.3. Fora de questão

- Não existe campo `description`; o único campo de texto livre adicional é `note` (RN67/RF70), opcional e limitado a 250 caracteres contando espaços.
- Não há `Idempotency-Key` nem controle de versão otimista (`If-Match`/`expectedVersion`) em nenhuma operação (BA-07). Conflito de edição é resolvido por última gravação válida vencer.
- Nenhuma gravação offline/local no mobile (MA-07): falha de rede mantém rascunho em memória e orienta nova tentativa.
- TEL-012 é compartilhada com UC12/UC17: os controles Concluir e Reabrir permanecem ocultos nesta entrega, até que SPEC-010 e SPEC-011 existam.
- MOD-003 (Definir alcance) não se aplica: sem rotinas criadas por esta entrega, não há ramo "selecionada e futuras" a decidir.
- Exclusão é lógica (preserva o registro para auditoria), nunca física.
- `signalResolution` só é exigido quando a tarefa está `awaitingConfirmation`; fora desse estado, o campo é ignorado se enviado, sem gerar erro.

## 4. Perfis, Atores e Regras de Autorização (RBAC)

| Perfil | Pode | Não pode | Reação do sistema |
|---|---|---|---|
| Administrador | Criar, consultar, editar e excluir qualquer tarefa da família, inclusive de outros membros | Excluir tarefa concluída diretamente; alterar dados de missão concluída | `403 ACTION_NOT_ALLOWED` / ação oculta |
| Membro | Igual ao Administrador (RN20 não distingue) | Idem | `403 ACTION_NOT_ALLOWED` / ação oculta |
| Kids | Nenhuma ação de gerenciamento (consulta da própria tarefa pertence a UC11, fora desta spec) | Criar, editar ou excluir qualquer tarefa | `403 ACTION_NOT_ALLOWED` / ação oculta na UI |

- **Isolamento familiar (RNF06):** qualquer tarefa de outra família responde `404 RESOURCE_NOT_FOUND`, sem revelar metadados.
- **Autorização no backend (RNF07):** o backend revalida o perfil em toda chamada, independentemente da ocultação visual no mobile.

## 5. Contrato de Dados, Interface e Validações

### 5.1. Dicionário de campos

| Campo | Tipo | Obrigatório | Validação | Erro de campo |
|---|---|---:|---|---|
| `title` | string | Sim | Após trim, de 1 a 60 caracteres Unicode visíveis, sem caracteres de controle (RN11) | `TITLE_REQUIRED`, `TITLE_INVALID_LENGTH` |
| `weight` | integer | Sim | 1, 2 ou 3 (RN13) | `WEIGHT_REQUIRED`, `WEIGHT_INVALID` |
| `scheduledDate` | string (`YYYY-MM-DD`) | Sim na criação | Qualquer data passada ou futura, sem limite (RN11) | `SCHEDULED_DATE_INVALID` |
| `assigneeIds` | array de uuid | Não | Cada id deve pertencer à mesma família ativa (RN12); `[]` remove todos; ids duplicados no mesmo payload são deduplicados pelo servidor, sem erro | `ASSIGNEE_NOT_IN_FAMILY` |
| `note` | string | Não | Até 250 caracteres contando espaços; `null` remove a observação existente (RN67) | `NOTE_TOO_LONG` |
| `signalResolution` | enum | Condicional | `resetToPending` ou `keepAwaitingConfirmation`; obrigatório quando o estado atual da tarefa é `awaitingConfirmation`, independentemente de quais outros campos mudaram (RN66); ignorado se enviado fora desse estado | `SIGNAL_RESOLUTION_REQUIRED` |

### 5.2. Rotas e respostas

#### Criar tarefa

- **Método e rota:** `POST /v1/tasks`
- **Autenticação:** Bearer Token de sessão ativa (Administrador ou Membro).

```json
{
  "title": "Arrumar os brinquedos",
  "weight": 2,
  "scheduledDate": "2026-10-10",
  "assigneeIds": ["a1b2c3d4-e5f6-7890-abcd-ef1234567890"],
  "note": "Guardar no baú do quarto"
}
```

- **Sucesso:** `201 Created`, `Location: /v1/tasks/{taskId}`.

```json
{
  "id": "e4f5a6b7-c8d9-0123-4567-89abcdef0123",
  "title": "Arrumar os brinquedos",
  "weight": 2,
  "scheduledDate": "2026-10-10",
  "assigneeIds": ["a1b2c3d4-e5f6-7890-abcd-ef1234567890"],
  "note": "Guardar no baú do quarto",
  "status": "pending",
  "routineId": null,
  "createdAt": "2026-10-06T15:00:00Z"
}
```

#### Consultar, editar e excluir

| Rota | Finalidade | Entrada / saída | Acesso |
|---|---|---|---|
| `GET /v1/tasks/{taskId}` | Detalhe da tarefa | Estado atual, origem, campos e capacidades autorizadas | Administrador, Membro |
| `PATCH /v1/tasks/{taskId}` | Editar campos de uma ocorrência | Campos presentes no dicionário 5.1, incluindo `signalResolution` quando aplicável; campos omitidos são preservados | Administrador, Membro; respeita proteção de missão concluída |
| `DELETE /v1/tasks/{taskId}` | Excluir tarefa não concluída | Remove vínculos de missão em andamento e recalcula progresso, fechando a missão se restarem só tarefas concluídas; remove sinalização corrente se houver | Administrador, Membro; não concluída/não protegida |

`PATCH` segue a convenção comum: campos omitidos são preservados, `null` remove apenas campos opcionais (`assigneeIds`, `note`), e a lista de `assigneeIds` enviada substitui a anterior por completo.

### 5.3. Erros, concorrência e resultado incerto

| HTTP | Código | Situação |
|---:|---|---|
| 400 | `UNKNOWN_FIELD` | Campo não reconhecido ou protegido (`status`, créditos, autor, família) |
| 403 | `ACTION_NOT_ALLOWED` | Perfil Kids ou sem permissão de gerenciamento |
| 404 | `RESOURCE_NOT_FOUND` | Tarefa inexistente ou de outra família |
| 409 | `TASK_ALREADY_COMPLETED` | Excluir tarefa `completed` diretamente (RN18) |
| 409 | `MISSION_COMPLETED_PROTECTED` | Editar ou excluir tarefa vinculada a missão concluída (RN58) |
| 409 | `MISSION_WOULD_HAVE_NO_TASKS` | Excluir a última tarefa de uma missão em andamento (RN50/RF59) |
| 422 | `VALIDATION_FAILED` | `title`, `weight`, `scheduledDate`, `note` ou `assigneeIds` inválidos; inclui `fieldErrors` |
| 422 | `SIGNAL_RESOLUTION_REQUIRED` | Editar tarefa `awaitingConfirmation` sem informar `signalResolution` |
| 503 | `DEPENDENCY_UNAVAILABLE` | Persistência incerta; não afirmar reversão da gravação |

- Todas as falhas usam `application/problem+json`, com `type`, `title`, `status`, `code`, `requestId` e `fieldErrors` quando aplicável.
- Não existe `Idempotency-Key`, replay automático nem controle de versão otimista (BA-07). A última gravação válida persistida vence.
- Em resposta perdida de `POST`, `PATCH` ou `DELETE`, o mobile não repete a gravação automaticamente; consulta `GET /v1/tasks/{taskId}` para descobrir o estado antes de orientar nova tentativa.

## 6. Estados de domínio e transições

| Estado de | Evento | Estado para | Autor | Garantias |
|---|---|---|---|---|
| — | `CreateTask` | `pending` | Administrador/Membro | Título, peso e data válidos; sem rotina |
| `pending` ou `awaitingConfirmation` | `DeleteTask` | excluída (lógica) | Administrador/Membro | Remove vínculos de missão em andamento e recalcula progresso; se restarem só tarefas concluídas, `CloseEligibleMissions` (SPEC-014) fecha a missão no mesmo commit; remove sinalização corrente sem decisão se `awaitingConfirmation` |
| `completed` | `DeleteTask` | — | — | Bloqueada com `409 TASK_ALREADY_COMPLETED` (RN18) |
| `pending`, `awaitingConfirmation` ou `completed` não protegida | `EditTask` | mesmo estado (exceto abaixo) | Administrador/Membro | Título/peso/data/responsáveis/observação atualizados; se `completed`, recrédita e recalcula progresso preservando o instante original de conclusão (RN17) |
| `awaitingConfirmation` | `EditTask` com `signalResolution: resetToPending` | `pending` | Administrador/Membro | Descarta a sinalização corrente; a criança pode sinalizar novamente (RN66) |
| `awaitingConfirmation` | `EditTask` com `signalResolution: keepAwaitingConfirmation` | `awaitingConfirmation` | Administrador/Membro | Preserva a sinalização corrente; dados editados ficam disponíveis para a decisão do Administrador (RN66) |
| qualquer, vinculada a missão concluída | `EditTask`/`DeleteTask` | — | — | Bloqueada com `409 MISSION_COMPLETED_PROTECTED` (RN58) |

## 7. Critérios de Aceitação

- **CA-01: criação com sucesso**
  - **DADO QUE** um Administrador ou Membro está ativo na família,
  - **QUANDO** enviar `POST /v1/tasks` com `title`, `weight` e `scheduledDate` válidos,
  - **ENTÃO O SISTEMA DEVE** persistir a tarefa com status inicial `pending`, sem rotina,
  - **E** responder `201 Created` com o recurso canônico. *(UC07, RF07, RN11/13)*

- **CA-02: Kids sem permissão**
  - **DADO QUE** a sessão pertence a um perfil Kids,
  - **QUANDO** tentar criar, editar ou excluir qualquer tarefa,
  - **ENTÃO O SISTEMA DEVE** responder `403 ACTION_NOT_ALLOWED`, sem persistir alteração. *(RF27, RN19, RNF07)*

- **CA-03: isolamento multitenant**
  - **DADO QUE** uma tarefa pertence à "Família B",
  - **QUANDO** um usuário da "Família A" tentar consultar, editar ou excluir essa tarefa,
  - **ENTÃO O SISTEMA DEVE** responder `404 RESOURCE_NOT_FOUND`, sem revelar dados da outra família. *(RNF06)*

- **CA-04: validação de título e peso**
  - **DADO QUE** o título está vazio, tem mais de 60 caracteres visíveis após trim, ou o peso está fora de 1–3,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** recusar com `422 VALIDATION_FAILED` e o `fieldErrors` correspondente. *(RN11, RN13, RF15)*

- **CA-05: editar tarefa concluída não protegida**
  - **DADO QUE** uma tarefa `completed` não está vinculada a missão concluída,
  - **QUANDO** um adulto editar peso, responsáveis ou data prevista,
  - **ENTÃO O SISTEMA DEVE** recalcular crédito e progresso, preservando o instante original de conclusão e registrando auditoria,
  - **E** manter a tarefa como `completed`. *(RN17, RF08)*

- **CA-06: bloqueio de exclusão de tarefa concluída**
  - **DADO QUE** a tarefa está `completed`,
  - **QUANDO** um adulto tentar excluí-la diretamente,
  - **ENTÃO O SISTEMA DEVE** responder `409 TASK_ALREADY_COMPLETED`, sem excluir. *(RN18)*

- **CA-07: proteção de missão concluída**
  - **DADO QUE** a tarefa está vinculada a uma missão concluída,
  - **QUANDO** um adulto tentar editá-la ou excluí-la,
  - **ENTÃO O SISTEMA DEVE** responder `409 MISSION_COMPLETED_PROTECTED`, sem alterar os dados preservados da missão. *(RN58)*

- **CA-08: última tarefa de missão em andamento**
  - **DADO QUE** a tarefa é a única vinculada a uma missão em andamento,
  - **QUANDO** um adulto tentar excluí-la,
  - **ENTÃO O SISTEMA DEVE** responder `409 MISSION_WOULD_HAVE_NO_TASKS`, sem excluir. *(RN50, RF59)*

- **CA-09: exclusão com recálculo de progresso**
  - **DADO QUE** a tarefa não concluída está vinculada a uma missão em andamento com outras tarefas,
  - **QUANDO** um adulto excluí-la,
  - **ENTÃO O SISTEMA DEVE** remover o vínculo e recalcular o progresso da missão. *(RF59)*

- **CA-10: atribuição de responsáveis**
  - **DADO QUE** um adulto edita `assigneeIds`, incluindo `[]` ou ids repetidos no mesmo payload,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** substituir a lista de responsáveis pela enviada, deduplicando ids repetidos sem erro,
  - **E** rejeitar com `422 VALIDATION_FAILED`/`ASSIGNEE_NOT_IN_FAMILY` qualquer id que não pertença à família. *(RN12, RF10)*

- **CA-11: falha de rede preserva rascunho**
  - **DADO QUE** o dispositivo perde conectividade antes de receber a resposta,
  - **QUANDO** o cliente identificar timeout ou indisponibilidade,
  - **ENTÃO O SISTEMA NÃO DEVE** apresentar a alteração como salva,
  - **E** DEVE preservar o conteúdo digitado e permitir nova tentativa explícita. *(RNF12, RNF13)*

- **CA-12: editar tarefa Aguardando confirmação — retornar a Pendente**
  - **DADO QUE** a tarefa está `awaitingConfirmation`,
  - **QUANDO** um adulto salvar uma edição com `signalResolution: "resetToPending"`,
  - **ENTÃO O SISTEMA DEVE** descartar a sinalização corrente e transicionar a tarefa para `pending`,
  - **E** permitir que a criança sinalize novamente. *(RN66, RF69)*

- **CA-13: editar tarefa Aguardando confirmação — manter o estado**
  - **DADO QUE** a tarefa está `awaitingConfirmation`,
  - **QUANDO** um adulto salvar uma edição com `signalResolution: "keepAwaitingConfirmation"`, mesmo alterando somente a observação,
  - **ENTÃO O SISTEMA DEVE** preservar o estado `awaitingConfirmation` e a sinalização corrente,
  - **E** manter os dados editados disponíveis para a decisão do Administrador. *(RN66, RF69)*

- **CA-14: editar sem resolver a sinalização pendente**
  - **DADO QUE** a tarefa está `awaitingConfirmation`,
  - **QUANDO** um adulto salvar uma edição sem informar `signalResolution`,
  - **ENTÃO O SISTEMA DEVE** recusar com `422 VALIDATION_FAILED`/`SIGNAL_RESOLUTION_REQUIRED`, sem persistir a edição. *(RN66, RF69)*

- **CA-15: excluir tarefa Aguardando confirmação**
  - **DADO QUE** a tarefa está `awaitingConfirmation`,
  - **QUANDO** um adulto excluí-la,
  - **ENTÃO O SISTEMA DEVE** remover a sinalização corrente junto com a tarefa, sem registrar confirmação ou recusa e sem pedir `signalResolution`. *(RN66, RF69)*

- **CA-16: observação opcional**
  - **DADO QUE** o campo `note` é enviado com até 250 caracteres contando espaços,
  - **QUANDO** a tarefa for criada ou editada,
  - **ENTÃO O SISTEMA DEVE** persistir a observação,
  - **E** recusar com `422 VALIDATION_FAILED`/`NOTE_TOO_LONG` quando exceder 250 caracteres. *(RN67, RF70)*

- **CA-17: exclusão que deixa apenas tarefas concluídas fecha a missão**
  - **DADO QUE** uma missão em andamento tem tarefas concluídas e uma única tarefa pendente,
  - **QUANDO** um adulto excluir essa tarefa pendente,
  - **ENTÃO O SISTEMA DEVE** remover o vínculo e concluir a missão na mesma transação,
  - **E** registrar participações e badges conforme SPEC-014. *(RN38, RF59)*

## 8. Observabilidade, métricas e auditoria

| Evento | Gatilho | Dados permitidos |
|---|---|---|
| `task_created` | Tarefa criada com sucesso | `taskId`, `familyId`, `hasAssignee`, `hasNote` |
| `task_edited` | Edição persistida | `taskId`, `familyId`, `wasCompleted`, `signalResolution` quando aplicável |
| `task_deleted` | Exclusão confirmada | `taskId`, `familyId`, `hadPendingSignal`, `closedMissionCount` |
| `task_management_denied` | Tentativa bloqueada por permissão ou proteção | `requestId`, `actorId`, `targetFamilyId`, `code` |

Segredos, tokens e dados de autenticação nunca entram em logs ou telemetria. `note` não é registrado em telemetria, apenas sua presença (`hasNote`).

## 9. Premissas e esclarecimentos

| # | Decisão | Situação | Altera `docs/`? |
|---|---|---|---|
| E-01 | Título da tarefa: 1 a 60 caracteres Unicode visíveis após trim, sem caracteres de controle, no mesmo padrão do nome da família. | Decidida em 2026-10-06 | Sim — `docs/01-regras-de-negocio.md` (RN11) 1.6, `docs/02-requisitos.md` (RF07) 1.7 |
| E-02 | Editar tarefa `awaitingConfirmation` exige escolher entre `resetToPending` (descarta sinalização) e `keepAwaitingConfirmation` (mantém); excluir remove a sinalização sem decisão. Exigido em toda edição salva nesse estado, mesmo que só a observação mude. | Decidida em 2026-10-06 | Sim — RN66/RF69 (novos) |
| E-03 | IDs duplicados em `assigneeIds` no mesmo payload são deduplicados silenciosamente pelo servidor, sem erro de validação. | Decidida em 2026-10-06 | Não — comportamento de implementação desta spec |
| E-05 | A exclusão de tarefa não concluída que deixa a missão em andamento apenas com tarefas concluídas conclui a missão na mesma transação, invocando `CloseEligibleMissions` (SPEC-014). | Decidida em 2026-10-19 | Sim — RN38 (1.18), RF59 (1.17), UC07 (1.16) |
| E-04 | Tarefa ganha campo `note` opcional, até 250 caracteres contando espaços, com as mesmas proteções de edição dos demais campos. | Decidida em 2026-10-06 | Sim — RN67/RF70 (novos), `docs/05-modelo-de-dados.md` 1.3, `docs/06-diagrama-de-classes.md` 1.3 |

## 10. Fases de implementação e conclusão

| Fase | Objetivo | CAs | Prontidão | Status |
|---|---|---|---|---|
| 1 | Núcleo: criar e consultar com autorização, isolamento e validação | CA-01, CA-02, CA-03, CA-04, CA-16 | Testes unitários e de integração verdes | em andamento — backend concluído (SCRUM-35); Mobile pendente (SCRUM-37) |
| 2 | Editar e excluir com proteções de missão/conclusão e resolução de sinalização pendente | CA-05 a CA-10, CA-12 a CA-15, CA-17 | Testes de integração e UX-spec verificada | em andamento — backend concluído (SCRUM-35); Mobile pendente (SCRUM-37) |
| 3 | Resiliência de rede | CA-11 | Regressão verde | a fazer |

**Registro de execução (2026-10-10):** SCRUM-35 concluiu o escopo backend das Fases 1 e 2. As fases permanecem em andamento até a entrega Mobile correspondente (SCRUM-37) e sua validação de interface.

- **Fase 1:** não publica edição nem exclusão; apenas criação e consulta. Não deve ser publicada isoladamente, pois TEL-012 precisa das ações da Fase 2 para ser útil.
- **Fase 2:** entrega o CRUD completo da tarefa única, incluindo a interação com sinalização Kids pendente; pode ser publicada junto com a Fase 1.
- **Fase 3:** não muda comportamento funcional; fortalece a experiência de falha de rede.

## 11. Checklist de aprovação

- [x] Códigos funcionais, UX e arquiteturais pesquisados e existentes.
- [x] Dependência SPEC-002 aprovada considerada.
- [x] RBAC e isolamento incluídos na Fase 1.
- [x] Contratos, códigos de erro e recuperação de resposta incerta definidos.
- [x] UX-spec vinculada.
- [x] Base funcional atualizada com limite de título, observação opcional e resolução de sinalização pendente (E-01, E-02, E-04).
- [x] Status autorizado explicitamente como `aprovada` pela pessoa usuária.
