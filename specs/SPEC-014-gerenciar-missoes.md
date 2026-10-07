# Spec 014: Gerenciar missões

**Status:** rascunho
**Autor:** Claude | **Criada em:** 2026-10-07 | **Aprovada por:** | **Em:**
**Base funcional:** 1.12
**UX-spec:** [UX-014-gerenciar-missoes.md](UX-014-gerenciar-missoes.md)
**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 4 - Missões e recompensas

## 1. Contexto e Objetivo

- **Problema / Necessidade:** a família precisa transformar tarefas já cadastradas em uma conquista coletiva sem prazo — a missão — para reconhecer esforço compartilhado com badges e, futuramente, uma recompensa sorteada.
- **Objetivo da entrega:** permitir que Administradores criem e editem missões coletivas vinculando tarefas individuais existentes ou recém-criadas, e que o servidor feche automaticamente a missão, registre participações e conceda badges quando todas as tarefas vinculadas estiverem concluídas, habilitando o resgate posterior.

## 2. Rastreabilidade e Dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Casos de uso | UC05 |
| Regras de negócio | RN16, RN35, RN36, RN37, RN38, RN39, RN40, RN50, RN51, RN53, RN58, RN59, RN64, RN68 |
| Requisitos funcionais | RF28, RF29, RF31, RF32, RF50, RF58, RF71 |
| Requisitos não funcionais | RNF01, RNF05, RNF06, RNF07, RNF08, RNF09, RNF11, RNF12, RNF13, RNF14, RNF22, RNF25 |
| Telas e fluxos de navegação | TEL-020 (parcial — gestão), TEL-021 (parcial — suficiente para editar e consultar), TEL-022, MOD-007, UF-10 |
| Decisões arquiteturais aplicáveis | MA-07 (verdade remota, sem gravação offline); MA-08 (última gravação válida vence, sem versão otimista); MA-11 (DTOs por permissão/projeção Kids); BA-05/BA-08 (transação única, lock por família); BA-14 (participação/badges cumulativos); BA-20 (contratos `/v1`, erros estáveis) |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/backend-contracts.md`, `docs/architecture/backend-decisions.md`, `docs/architecture/mobile-decisions.md`, `docs/architecture/mobile-feature-catalog.md`.
- **Depende de:** [SPEC-007-gerenciar-tarefas.md](SPEC-007-gerenciar-tarefas.md), aprovada — fornece as tarefas vinculáveis e já define `MISSION_COMPLETED_PROTECTED`/`MISSION_WOULD_HAVE_NO_TASKS` do lado da tarefa. [SPEC-010-concluir-tarefa.md](SPEC-010-concluir-tarefa.md), aprovada — já aciona "atualizar... missão... numa transação" ao concluir tarefa; esta spec define esse mecanismo (`CloseEligibleMissions`).
- **Dependências externas e infraestrutura:** nenhuma além do banco transacional do backend.

## 3. Escopo da Entrega

### 3.1. Dentro do escopo

- `POST /v1/missions`: criar missão com `title`, `note` opcional (≤250 car.) e `taskIds` não vazio. Admin apenas.
- `PATCH /v1/missions/{missionId}`: editar `title`/`note`/conjunto completo de `taskIds` de missão em andamento; rejeita deixar `taskIds` vazio.
- `GET /v1/missions/task-options`: tarefas da família elegíveis para vínculo, com busca textual opcional e paginação; qualquer status, inclusive `completed`.
- `GET /v1/missions` e `GET /v1/missions/{missionId}`: leitura mínima (id, title, note, status, taskIds/resumo de tarefas, completedAt, isRedemptionAvailable) para todos os perfis da família, incluindo Kids em projeção simplificada sem dados de gestão.
- Mecanismo interno `CloseEligibleMissions`: ao salvar (criar/editar) ou quando acionado por `CompleteTask` (SPEC-010), fecha a missão se todas as tarefas vinculadas estiverem concluídas — registra `MissionParticipation` por responsável creditado, concede `BadgeAward` nos marcos 5/10/25/50 e habilita `isRedemptionAvailable`, tudo na mesma transação.
- Atalho "+ Nova tarefa" no seletor de tarefas: reaproveita o fluxo e o contrato existentes de `POST /v1/tasks` (SPEC-007), sem nenhuma mudança de contrato; a tarefa criada volta pré-selecionada no rascunho da missão.
- Proteção "uma missão nunca fica sem tarefas" nas duas camadas: bloqueio local no mobile (sem chamar o servidor) e validação/erro estável no backend.
- Autorização exclusiva de Administrador para mutações (RN37); leitura liberada a todos os perfis da família (RNF07).
- Isolamento multitenant (RNF06) em todas as rotas.
- TEL-022 (`MissionEditorView`) e MOD-007 (`MissionTaskPickerView`) completos; TEL-020/021 na fatia mínima descrita acima.

### 3.2. Fora do escopo (desta spec)

- Progresso formatado, lista de participações e exibição de recompensa a todos os perfis, e navegação a partir do marco de badge (TEL-054) — RF30/RF36, UC14/SPEC-016.
- `POST /v1/missions/{id}/reward-acceptance` e roleta — UC16/SPEC-017.
- `GET/POST /v1/reward-items` — UC06/SPEC-015.
- Reversão de participações/badges/recompensa por reabertura de tarefa vinculada — UC17/SPEC-011. Esta spec só fecha missões, nunca as reabre.
- Exibição de badges no perfil (TEL-054, `GetOwnBadges`, `GetBadgeContributions`) — UC10/SPEC-006.

### 3.3. Fora de questão

- Não existe selo configurável por missão; badges seguem exclusivamente os marcos fixos 5/10/25/50 (RN64).
- Missão não tem prazo, vigência ou expiração.
- Vincular uma tarefa não vincula a rotina inteira nem ocorrências futuras (RN51).
- Sem `Idempotency-Key` nem controle de versão otimista (BA-07/MA-08); última gravação válida vence.
- Nenhuma gravação offline no mobile (MA-07).
- O atalho "+ Nova tarefa" não adiciona `missionId` à tarefa nem muda o contrato de `POST /v1/tasks`: o vínculo é sempre lido/gravado do lado da missão (`taskIds`), nunca da tarefa.
- Kids não têm ação de criar, editar, vincular/desvincular tarefas, nem veem participações ou recompensa.

## 4. Perfis, Atores e Regras de Autorização (RBAC)

| Perfil | Pode | Não pode | Reação do sistema |
|---|---|---|---|
| Administrador | Criar, editar e consultar qualquer missão da família | Alterar dados/vínculos de missão concluída (exceto por reabertura de tarefa, fora desta spec) | `409 MISSION_COMPLETED_PROTECTED` |
| Membro | Consultar missões (leitura mínima) | Criar ou editar missão | `403 ACTION_NOT_ALLOWED` / ação oculta na UI |
| Kids | Consultar título, observação, tarefas vinculadas e status, em apresentação simplificada | Criar, editar, vincular/desvincular tarefas; ver participações ou recompensa | `403 ACTION_NOT_ALLOWED` / ação oculta na UI |

- **Isolamento familiar (RNF06):** missão de outra família responde `404 RESOURCE_NOT_FOUND`, sem revelar metadados.
- **Autorização no backend (RNF07):** o backend revalida o perfil em toda chamada, independentemente da ocultação visual no mobile.

## 5. Contrato de Dados, Interface e Validações

### 5.1. Dicionário de campos

| Campo | Tipo | Obrigatório | Validação | Erro de campo |
|---|---|---:|---|---|
| `title` | string | Sim | Após trim, de 1 a 60 caracteres Unicode visíveis, sem caracteres de controle — mesma convenção já aplicada a família (RN01/RF01) e tarefa (RN11/RF07), por precisão sobre RF28/29 (E-01) | `TITLE_REQUIRED`, `TITLE_INVALID_LENGTH` |
| `note` | string | Não | Até 250 caracteres contando espaços; `null` remove a observação existente (RN68/RF71) | `NOTE_TOO_LONG` |
| `taskIds` | array de uuid | Sim | Não vazio (RN50/RF50); cada id deve pertencer à mesma família ativa, em qualquer status, inclusive `completed` (RN36); ids duplicados no mesmo payload são deduplicados pelo servidor, sem erro | `MISSION_TASKS_REQUIRED`, `TASK_NOT_IN_FAMILY` |

### 5.2. Rotas e respostas

#### Criar missão

- **Método e rota:** `POST /v1/missions`
- **Autenticação:** Bearer Token de sessão ativa (Administrador).

```json
{
  "title": "Arrumar o quintal",
  "note": "Antes do churrasco de sábado",
  "taskIds": ["a1b2c3d4-e5f6-7890-abcd-ef1234567890", "b2c3d4e5-f6a7-8901-bcde-f12345678901"]
}
```

- **Sucesso:** `201 Created`, `Location: /v1/missions/{missionId}`. Se todas as tarefas enviadas já estiverem `completed`, a missão nasce `completed` e `CloseEligibleMissions` roda na mesma transação.

```json
{
  "id": "e4f5a6b7-c8d9-0123-4567-89abcdef0123",
  "familyId": "f1a2b3c4-d5e6-7890-abcd-ef1234567890",
  "title": "Arrumar o quintal",
  "note": "Antes do churrasco de sábado",
  "status": "inProgress",
  "taskIds": ["a1b2c3d4-e5f6-7890-abcd-ef1234567890", "b2c3d4e5-f6a7-8901-bcde-f12345678901"],
  "completedAt": null,
  "isRedemptionAvailable": false,
  "createdAt": "2026-10-07T15:00:00Z"
}
```

#### Consultar, selecionar tarefas e editar

| Rota | Finalidade | Entrada / saída | Acesso |
|---|---|---|---|
| `GET /v1/missions` | Lista em andamento/concluídas (leitura mínima) | `id`, `title`, `status`, `taskCount`, `completedTaskCount`, cursor | Todos da família; Kids em projeção simplificada |
| `GET /v1/missions/{missionId}` | Detalhe mínimo | `id`, `familyId`, `title`, `note`, `status`, `taskIds`, `completedAt`, `isRedemptionAvailable` | Todos da família; Kids sem ações/dados de gestão |
| `GET /v1/missions/task-options` | Tarefas elegíveis para vínculo | `query` (busca textual opcional no título), cursor → tarefas de qualquer status | Administrador |
| `PATCH /v1/missions/{missionId}` | Editar título, observação e/ou vínculos de uma missão em andamento | Campos do dicionário 5.1; `taskIds` enviado substitui o conjunto inteiro; pode encerrar a missão quando o resultado deixa só tarefas concluídas | Administrador; em andamento; rejeita `taskIds` vazio |

`PATCH` segue a convenção comum: campos omitidos são preservados, `note: null` remove a observação, e `taskIds` enviado substitui a lista anterior por completo (nunca um merge parcial).

### 5.3. Erros, concorrência e resultado incerto

| HTTP | Código | Situação |
|---:|---|---|
| 400 | `UNKNOWN_FIELD` | Campo não reconhecido ou protegido (`status`, `completedAt`, `participations`, `reward`, autor) |
| 403 | `ACTION_NOT_ALLOWED` | Membro ou Kids tentam criar/editar missão |
| 404 | `RESOURCE_NOT_FOUND` | Missão inexistente ou de outra família |
| 409 | `MISSION_COMPLETED_PROTECTED` | Editar ou alterar vínculos de missão concluída (RN58) |
| 409 | `MISSION_WOULD_HAVE_NO_TASKS` | Edição deixaria `taskIds` vazio (RN50) |
| 422 | `VALIDATION_FAILED` | `title`, `note` ou `taskIds` inválidos; inclui `fieldErrors` (`TITLE_INVALID_LENGTH`, `NOTE_TOO_LONG`, `MISSION_TASKS_REQUIRED`, `TASK_NOT_IN_FAMILY`) |
| 503 | `DEPENDENCY_UNAVAILABLE` | Persistência incerta; não afirmar reversão da gravação |

- Todas as falhas usam `application/problem+json`, com `type`, `title`, `status`, `code`, `requestId` e `fieldErrors` quando aplicável.
- Não existe `Idempotency-Key`, replay automático nem controle de versão otimista (BA-07). A última gravação válida persistida vence.
- `CloseEligibleMissions` é serializado pelo lock por família (BA-08): se duas transações puderem fechar a mesma missão simultaneamente (ex.: edição e conclusão de tarefa concorrentes), apenas uma registra participações e badges; a outra encontra a missão já `completed` e não duplica efeitos.
- Em resposta perdida de `POST`/`PATCH`, o mobile não repete a gravação automaticamente; consulta `GET /v1/missions/{missionId}` para descobrir o estado antes de orientar nova tentativa.

## 6. Estados de Domínio e Transições

| Estado De | Evento / Ação | Estado Para | Quem Pode Executar | Regras e Validações | Efeitos Colaterais |
|---|---|---|---|---|---|
| — | `CreateMission` | `inProgress` | Administrador | Ao menos uma tarefa válida da família | — |
| — | `CreateMission` com todas as tarefas já `completed` | `completed` | Administrador | RN36/RN38 | `CloseEligibleMissions`: participações, badges, `isRedemptionAvailable` |
| `inProgress` | `EditMission` (título/observação/vínculos, restam tarefas não concluídas) | `inProgress` | Administrador | Progresso recalculado | — |
| `inProgress` | `EditMission` (vínculos passam a conter só tarefas concluídas) | `completed` | Administrador | RN35/RN38 | `CloseEligibleMissions` |
| `inProgress` | `CompleteTask` conclui a última tarefa vinculada pendente (gatilho externo, SPEC-010) | `completed` | Adulto que conclui a tarefa | RN38/RF31 | `CloseEligibleMissions` no mesmo commit de `CompleteTask` |
| `completed` | `EditMission` | — | — | Bloqueada com `409 MISSION_COMPLETED_PROTECTED` (RN58) | — |
| `completed` | Reabertura de tarefa vinculada (UC17) | `inProgress` | — | Fora desta spec — apenas referência (SPEC-011) | — |

## 7. Critérios de Aceitação (BDD Formal)

- **CA-01: criação com sucesso**
  - **DADO QUE** um Administrador está ativo na família,
  - **QUANDO** enviar `POST /v1/missions` com `title` e `taskIds` válidos,
  - **ENTÃO O SISTEMA DEVE** persistir a missão com status `inProgress`,
  - **E** responder `201 Created` com o recurso canônico. *(UC05, RF28/29, RN37)*

- **CA-02: Membro ou Kids tentam criar missão**
  - **DADO QUE** o usuário autenticado possui perfil `Membro` ou `Kids`,
  - **QUANDO** enviar `POST /v1/missions`,
  - **ENTÃO O SISTEMA DEVE** recusar sem persistir, respondendo `403 ACTION_NOT_ALLOWED`. *(RNF07, RN37)*

- **CA-03: Membro ou Kids tentam editar missão**
  - **DADO QUE** o usuário autenticado possui perfil `Membro` ou `Kids`,
  - **QUANDO** enviar `PATCH /v1/missions/{missionId}`,
  - **ENTÃO O SISTEMA DEVE** recusar sem persistir, respondendo `403 ACTION_NOT_ALLOWED`. *(RNF07, RN37)*

- **CA-04: isolamento multitenant**
  - **DADO QUE** uma missão pertence à Família B,
  - **QUANDO** um usuário da Família A consultar ou alterar essa missão,
  - **ENTÃO O SISTEMA DEVE** responder `404 RESOURCE_NOT_FOUND`, sem vazar dados. *(RNF06)*

- **CA-05: `taskIds` vazio na criação**
  - **DADO QUE** o payload de criação não inclui `taskIds` ou envia lista vazia,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** recusar com `422 VALIDATION_FAILED`/`MISSION_TASKS_REQUIRED`, sem persistir. *(RN50, RF50)*

- **CA-06: título fora do limite**
  - **DADO QUE** `title` tem menos de 1 ou mais de 60 caracteres Unicode visíveis após trim,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** recusar com `422 VALIDATION_FAILED`/`TITLE_INVALID_LENGTH`. *(E-01)*

- **CA-07: tarefa de outra família**
  - **DADO QUE** um dos `taskIds` enviados pertence a outra família,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** recusar com `422 VALIDATION_FAILED`/`TASK_NOT_IN_FAMILY`, sem revelar a existência da tarefa. *(RNF06)*

- **CA-08: observação acima do limite**
  - **DADO QUE** `note` excede 250 caracteres contando espaços,
  - **QUANDO** a missão for criada ou editada,
  - **ENTÃO O SISTEMA DEVE** recusar com `422 VALIDATION_FAILED`/`NOTE_TOO_LONG`. *(RN68, RF71)*

- **CA-09: edição com sucesso**
  - **DADO QUE** uma missão está `inProgress`,
  - **QUANDO** um Administrador editar título, observação e/ou vínculos com dados válidos,
  - **ENTÃO O SISTEMA DEVE** persistir as mudanças e responder `200 OK` com o recurso atualizado. *(RF28, RN50/51)*

- **CA-10: editar ou alterar vínculos de missão concluída**
  - **DADO QUE** a missão está `completed`,
  - **QUANDO** um Administrador tentar editá-la ou alterar seus vínculos,
  - **ENTÃO O SISTEMA DEVE** recusar com `409 MISSION_COMPLETED_PROTECTED`, sem alterar os dados preservados. *(RN58)*

- **CA-11: remover a última tarefa vinculada sem substituição (backend)**
  - **DADO QUE** a missão em andamento tem uma única tarefa vinculada,
  - **QUANDO** o Administrador enviar `PATCH` removendo essa tarefa sem indicar substituta,
  - **ENTÃO O SISTEMA DEVE** recusar com `409 MISSION_WOULD_HAVE_NO_TASKS`, sem excluir o vínculo. *(RN50, RF50)*

- **CA-12: bloqueio local ao tentar salvar ou editar sem tarefas (mobile)**
  - **DADO QUE** o rascunho de `taskIds` no MOD-007 chega a zero, seja na criação ou ao desmarcar a última tarefa numa edição,
  - **QUANDO** o usuário tentar salvar a missão,
  - **ENTÃO O APLICATIVO NÃO DEVE** chamar o backend,
  - **E** DEVE manter o botão Salvar desabilitado e exibir o motivo (“uma missão precisa de ao menos uma tarefa”). *(RNF01, RN50)*

- **CA-13: fechamento automático ao criar já com todas as tarefas concluídas**
  - **DADO QUE** todas as tarefas selecionadas em `taskIds` já estão `completed`,
  - **QUANDO** a missão for criada,
  - **ENTÃO O SISTEMA DEVE** persistir a missão como `completed`,
  - **E** registrar participações, conceder badges nos marcos atingidos e habilitar `isRedemptionAvailable` na mesma transação. *(RN38, RF31/32)*

- **CA-14: fechamento automático ao desvincular tarefa durante a edição**
  - **DADO QUE** uma missão em andamento tem tarefas concluídas e não concluídas vinculadas,
  - **QUANDO** o Administrador editar e remover todas as tarefas não concluídas, restando só concluídas,
  - **ENTÃO O SISTEMA DEVE** fechar a missão na mesma operação, registrando participações e badges. *(RN35, UC05 alternativas)*

- **CA-15: fechamento acionado pela conclusão de tarefa (SPEC-010)**
  - **DADO QUE** uma missão em andamento tem exatamente uma tarefa pendente,
  - **QUANDO** `CompleteTask` (UC12/SPEC-010) concluir essa tarefa,
  - **ENTÃO O SISTEMA DEVE** invocar `CloseEligibleMissions` no mesmo commit, fechando a missão e registrando participações/badges. *(RN38, RF31)*

- **CA-16: concorrência em fechamentos simultâneos**
  - **DADO QUE** duas operações concorrentes (ex.: edição de vínculos e conclusão de tarefa) poderiam fechar a mesma missão,
  - **QUANDO** ambas forem processadas,
  - **ENTÃO O SISTEMA DEVE** registrar participações e badges uma única vez, sem duplicação, graças ao lock por família. *(RNF11, RNF25, BA-08)*

- **CA-17: falha de rede preserva rascunho**
  - **DADO QUE** o dispositivo perde conectividade antes de receber a resposta,
  - **QUANDO** o cliente identificar timeout ou indisponibilidade,
  - **ENTÃO O SISTEMA NÃO DEVE** apresentar a alteração como salva,
  - **E** DEVE preservar o conteúdo digitado e permitir nova tentativa explícita. *(RNF12/13)*

- **CA-18: atalho "+ Nova tarefa" dentro do seletor**
  - **DADO QUE** o Administrador está no seletor de tarefas da missão (MOD-007),
  - **QUANDO** tocar em "+ Nova tarefa" e concluir a criação pelo fluxo padrão (TEL-013/`POST /v1/tasks`),
  - **ENTÃO O APLICATIVO DEVE** retornar ao seletor com a tarefa recém-criada pré-selecionada no rascunho da missão, sem alterar o contrato de criação de tarefa. *(UC05 fluxo principal)*

- **CA-19: Kids consulta missão em projeção simplificada**
  - **DADO QUE** um perfil Kids está ativo na família,
  - **QUANDO** consultar uma missão da própria família,
  - **ENTÃO O SISTEMA DEVE** retornar título, observação, tarefas vinculadas e status,
  - **E** NÃO DEVE incluir participações, recompensa ou ações de gestão. *(RNF06, UC05)*

- **CA-20: participação e badges nos marcos, uma vez por pessoa**
  - **DADO QUE** uma missão se fecha e dois de seus responsáveis creditados já tinham, respectivamente, 4 e 9 missões anteriores com participação,
  - **QUANDO** `CloseEligibleMissions` registrar a participação de cada um,
  - **ENTÃO O SISTEMA DEVE** conceder o badge `bronze` ao primeiro (atinge 5) e `silver` ao segundo (atinge 10), uma única vez por pessoa/marco,
  - **E** contar a missão uma única vez mesmo que a pessoa seja responsável em várias tarefas vinculadas. *(RN64, RF32)*

## 8. Observabilidade, Métricas e Auditoria

| Evento | Gatilho | Dados permitidos |
|---|---|---|
| `mission_created` | Missão criada com sucesso | `missionId`, `familyId`, `taskCount`, `initialStatus` |
| `mission_edited` | Edição persistida | `missionId`, `familyId`, `taskCountDelta` |
| `mission_closed` | Fechamento automático (criação, edição ou `CompleteTask`) | `missionId`, `familyId`, `participationCount`, `badgesAwardedCount`, `trigger` |
| `mission_management_denied` | Tentativa bloqueada por permissão ou proteção | `requestId`, `actorId`, `targetFamilyId`, `code` |

Segredos, tokens e dados de autenticação nunca entram em logs ou telemetria. `note` não é registrado em telemetria, apenas sua presença (`hasNote`).

## 9. Premissas e Esclarecimentos

| # | Decisão | Situação | Altera `docs/`? |
|---|---|---|---|
| E-01 | Título da missão: 1 a 60 caracteres Unicode visíveis após trim, sem caracteres de controle, mesma convenção de família (RF01) e tarefa (RF07). | Decidida em 2026-10-07 | Não — reaproveita convenção já registrada; apenas precisão sobre RF28/29 nesta spec |
| E-02 | Esta spec implementa `GET /missions` e `GET /missions/{id}` com projeção mínima (para todos os perfis, incluindo Kids simplificado); a experiência completa de acompanhamento (progresso formatado, participações, recompensa a todos, navegação por badge) fica para SPEC-016 (UC14). | Decidida em 2026-10-07 | Não — antecipação de fatia de tela já prevista para UC14, sem mudança de regra |
| E-03 | Códigos de erro `MISSION_TASKS_REQUIRED` e `TASK_NOT_IN_FAMILY`, seguindo o padrão de `fieldErrors` já usado em tarefas/rotinas; proteção equivalente obrigatória no mobile antes de chamar o backend. | Decidida em 2026-10-07 | Não — convenção de contrato desta spec |
| E-04 | `GET /missions/task-options` aceita `query` (busca textual opcional) e `cursor`; retorna tarefas de qualquer status, inclusive `completed`. | Decidida em 2026-10-07 | Não |
| E-05 | `CompleteTask` (SPEC-010, aprovada) passa a invocar `CloseEligibleMissions` definido aqui; não exige reabrir SPEC-010. | Decidida em 2026-10-07 | Não |
| E-06 | Missão ganha campo `note` opcional de até 250 caracteres, mesma régua da observação de tarefa. | Decidida em 2026-10-07 | Sim — RN68/RF71 (novos) em `docs/01-regras-de-negocio.md` 1.11 e `docs/02-requisitos.md` 1.12; `docs/05-modelo-de-dados.md` 1.6; `docs/06-diagrama-de-classes.md` 1.7; `docs/architecture/backend-contracts.md` 1.7 |
| E-07 | Atalho "+ Nova tarefa" no seletor de tarefas da missão, reaproveitando o fluxo de criação já existente (SPEC-007), sem novo endpoint. | Decidida em 2026-10-07 | Sim — UC05 (fluxo principal), `docs/design/screen-map.md` 1.7 e `docs/design/user-flows.md` 1.7 (MOD-007) |
| E-08 | Kids consultam a missão (título, observação, tarefas vinculadas, status) em apresentação simplificada, antecipando essa fatia de UC14 para esta spec. | Decidida em 2026-10-07 | Sim — UC05 passa a citar a consulta por todos os perfis; `docs/design/screen-map.md` 1.7 e `docs/design/user-flows.md` 1.7 |

## 10. Fases de Implementação e Critérios de Conclusão

| Fase | Objetivo da Entrega | Critérios de Aceite Atendidos | Critério de Prontidão (Definition of Done) | Status |
|---|---|---|---|---|
| **1** | **Núcleo mínimo (Core API + Isolamento):** `CreateMission`, `EditMission`, `GetMissionTaskOptions`, `CloseEligibleMissions` (incluindo o gancho a partir de `CompleteTask`), autorização, isolamento e validação. | CA-01 a CA-08, CA-10, CA-11, CA-13 a CA-16, CA-20 | Testes unitários e de integração verdes cobrindo os CAs listados. | a fazer |
| **2** | **Experiência Mobile + Integração:** TEL-022, MOD-007, leitura mínima de TEL-020/021, bloqueio local de "sem tarefas", atalho de criação de tarefa e consulta Kids simplificada. | CA-09, CA-12, CA-18, CA-19 | Telas integradas com a API, testes de UI/E2E e UX-spec verificada. | a fazer |
| **3** | **Polimento e Casos Raros:** resiliência de rede. | CA-17 | Suíte de regressão verde. | a fazer |

- **Fase 1:** não publica nenhuma tela; apenas os endpoints e o mecanismo de fechamento. Não deve ser publicada isoladamente, pois nenhuma UI consome a API ainda.
- **Fase 2:** entrega a gestão completa do Admin e a consulta básica de todos os perfis; pode ser publicada junto com a Fase 1.
- **Fase 3:** não muda comportamento funcional; fortalece a experiência de falha de rede.

## 11. Checklist de Aprovação da Spec (Definition of Ready)

- [x] Todos os códigos citados (`RN`, `RF`, `RNF`, `UC`, `TEL`, `UF`) existem na base funcional vigente (RN68/RF71 incluídos nesta aprovação).
- [x] A rastreabilidade técnica (`MA-..`, `BA-..`) está alinhada com as diretrizes de arquitetura.
- [x] O contrato de API compartilhado está completo e sem ambiguidades.
- [x] O dicionário de campos define tipos, limites e códigos de erro estáveis para todos os inputs.
- [x] Todo critério de aceitação segue o padrão formal BDD e mapeia um teste automatizável.
- [x] Isolamento entre famílias (RNF06) e recusa por perfil (RNF07) constam explicitamente na Fase 1.
- [x] Nenhuma premissa sem decisão registrada na seção 9.
- [x] A UX-spec correspondente está vinculada.
- [x] A seção "Fora de questão" elimina riscos de suposições incorretas.
- [x] Nenhum detalhe efêmero de implementação engessa a arquitetura interna dos módulos.
