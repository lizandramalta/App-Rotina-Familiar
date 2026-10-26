# Spec 011: Reabrir tarefa

**Status:** aprovada
**Autor:** Claude | **Criada em:** 2026-10-07 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-07
**Base funcional:** UC 1.18; RN/RF conforme rastreabilidade
**UX-spec:** [UX-011-reabrir-tarefa.md](UX-011-reabrir-tarefa.md)
**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 2 — Tarefas e rotina

## 1. Contexto e objetivo

- **Problema / necessidade:** uma conclusão registrada por engano, ou que precisa ser desfeita, não pode ser simplesmente excluída — a família precisa de um caminho para retornar a tarefa a Pendente sem corromper carga, progresso ou conquistas já concedidas.
- **Objetivo da entrega:** permitir que Administrador, Membro (em qualquer tarefa acessível) e Kids (na própria tarefa) retornem uma tarefa `completed` para `pending`, desfazendo o crédito de carga/progresso e, quando a tarefa estiver vinculada a uma missão concluída e/ou com recompensa aceita, confirmando explicitamente antes de reabrir a missão e remover seus dados derivados.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos |
|---|---|
| Caso de uso | UC17 |
| Regras | RN38, RN50, RN53, RN55, RN57, RN58, RN59 |
| Requisitos | RF09, RF18, RF19, RF57, RF58, RF59 |
| Não funcionais | RNF01, RNF02, RNF05, RNF06, RNF07, RNF08, RNF09, RNF10, RNF11, RNF12, RNF13, RNF14, RNF22, RNF25 |
| Telas e fluxo | TEL-010, TEL-012, TEL-040, MOD-006, UF-08 |
| Arquitetura | MA-07, MA-08, MA-11; BA-05, BA-07, BA-08, BA-14, BA-20 |

- **Depende de:** [SPEC-010-concluir-tarefa.md](SPEC-010-concluir-tarefa.md), aprovada — fornece `Completion` e o estado `completed` que esta spec reverte. [SPEC-014-gerenciar-missoes.md](SPEC-014-gerenciar-missoes.md), aprovada — fornece `Mission`, `MissionStatus` e `CloseEligibleMissions`, cujo efeito esta spec é a única operação autorizada a reverter (RN58).
- **Fontes consultadas:** `docs/01-regras-de-negocio.md` (RN38/50/53/55/57–59), `docs/02-requisitos.md` (RF09/18/19/57–59, RNF citadas), `docs/03-casos-de-uso.md` (UC17), `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md` (`FamilyTask`, `Completion`, `TaskService`, `Mission`, `MissionService`), `docs/design/screen-map.md` (TEL-012, MOD-006), `docs/design/user-flows.md` (UF-08), `docs/architecture/backend-contracts.md` (`backend-uc17`), `docs/architecture/mobile-feature-catalog.md` (MOD-006), `docs/architecture/backend-decisions.md` (BA-05/07/08/14/20), `docs/architecture/mobile-decisions.md` (MA-07/08/11).
- **Dependências externas e infraestrutura:** nenhuma além do banco transacional do backend.

## 3. Escopo

### 3.1. Dentro do escopo

- `POST /v1/tasks/{taskId}/reopening`: retorna tarefa `completed` para `pending`, mantendo os responsáveis existentes.
- Reversão do crédito de carga (dia e semana) de todos os responsáveis da conclusão desfeita, invalidando a `Completion` vigente (`undoneAt`/`undoneBy`) sem apagar o histórico da conclusão original (RF18/19/57).
- Recalcular o progresso das missões em andamento vinculadas à tarefa.
- Quando a tarefa estiver vinculada a ao menos uma missão `completed` e/ou com recompensa aceita: exigir confirmação explícita (`confirm: true`) antes de persistir; ao confirmar, retornar a(s) missão(ões) para `inProgress` e remover recompensa aceita, participações e badges derivados dela, na mesma transação, sem preservar histórico desses dados (RN38/53/58).
- Autorização: Administrador e Membro em qualquer tarefa acessível da família; Kids somente na própria tarefa, como responsável.
- Em TEL-010/TEL-040, o círculo reabre quando permitido; o restante da linha abre o detalhe. Após a ação, lista e progresso consultam o servidor; MOD-006 mantém a mesma confirmação.
- Isolamento multitenant (RNF06) e consistência sob concorrência (RNF11/25, lock por família BA-08).

### 3.2. Fora do escopo (desta spec)

- Exclusão de tarefa — já coberta por [SPEC-007-gerenciar-tarefas.md](SPEC-007-gerenciar-tarefas.md) (RF59). Esta spec só garante que `Completion.undoneAt` fique marcada corretamente para que a exclusão posterior não desconte o peso novamente (RN59).
- Sinalização, confirmação ou recusa de tarefa Kids (`pending` ↔ `awaitingConfirmation`) — SPEC-012/SPEC-013. Reabertura só se aplica a tarefa `completed`.
- Resgate de recompensa (`POST /v1/missions/{id}/reward-acceptance`) — UC16/SPEC-017, ainda não criada. O campo `Mission.reward` existe no modelo, mas hoje nunca é preenchido; a remoção de recompensa definida aqui (RN53/58) fica sem efeito observável até SPEC-017 existir.
- Visualização de carga diária/semanal (UC13/SPEC-018, não criada) e relatório PDF (UC18/SPEC-019). Esta spec só garante que os dados subjacentes de carga e progresso fiquem corretos para quando essas entregas existirem.
- Qualquer tela ou indicador de carga/progresso em TEL-012 além da ação Reabrir.

### 3.3. Fora de questão (anti-requisitos)

- Não há reabertura parcial: a tarefa tem estado único, e a reabertura autorizada vale para todos os responsáveis (RN55).
- Não há escolha de quais responsáveis mantêm o crédito; a reversão é total.
- Reabertura nunca preserva o histórico de participações, badges ou recompensa removidos (RN58) — é destrutiva por definição; a única forma de restaurá-los é concluir a tarefa novamente e deixar `CloseEligibleMissions` (SPEC-014) rodar de novo.
- Kids não reabre tarefa de outra pessoa, mesmo quando é um dos vários responsáveis junto com um adulto — só a própria tarefa.
- Não existe `Idempotency-Key` nem controle de versão otimista (BA-07); a última gravação válida persistida vence.
- Reabertura não se aplica a tarefa `pending` ou `awaitingConfirmation`.

## 4. Perfis, atores e regras de autorização (RBAC)

| Perfil | Pode | Não pode | Reação do sistema |
|---|---|---|---|
| Administrador | Reabrir qualquer tarefa `completed` acessível da família | Reabrir tarefa de outra família | `404 RESOURCE_NOT_FOUND` |
| Membro | Igual ao Administrador (RN57 não distingue) | Idem | Idem |
| Kids | Reabrir a própria tarefa `completed` (responsável) | Reabrir tarefa de terceiro, mesmo compartilhada | `403 ACTION_NOT_ALLOWED` / ação oculta na UI |

- **Isolamento familiar (RNF06):** tarefa de outra família responde `404 RESOURCE_NOT_FOUND`, sem revelar metadados.
- **Autorização no backend (RNF07):** o backend revalida perfil e vínculo de responsável em toda chamada, independentemente da ocultação visual no mobile.

## 5. Contrato de dados e interface

### 5.1. Rota

- **Método e rota:** `POST /v1/tasks/{taskId}/reopening`
- **Autenticação:** Bearer Token de sessão ativa (Administrador, Membro ou Kids responsável pela tarefa).
- **Corpo (opcional):**

```json
{ "confirm": true }
```

`confirm` ausente ou `false` equivale a não confirmado. Nenhum outro campo é aceito.

### 5.2. Comportamento e respostas

1. Tarefa não está `completed` (`pending` ou `awaitingConfirmation`) → recusa com `409 TASK_NOT_COMPLETED`, nada persiste.
2. Tarefa `completed`, sem nenhuma missão `completed` nem recompensa aceita vinculada → executa imediatamente, independentemente do valor de `confirm`, respondendo `200 OK`.
3. Tarefa `completed`, vinculada a ao menos uma missão `completed` e/ou recompensa aceita:
   - sem `confirm: true` → recusa com `409 MISSION_REOPEN_REQUIRES_CONFIRMATION`, nada persiste; o corpo lista as missões afetadas para o mobile apresentar MOD-006;
   - com `confirm: true` → executa, reabrindo a(s) missão(ões) e removendo participações, badges e recompensa aceita derivados dela(s), na mesma transação, respondendo `200 OK`.

#### Sucesso (`200 OK`)

```json
{
  "task": {
    "id": "e4f5a6b7-c8d9-0123-4567-89abcdef0123",
    "title": "Arrumar os brinquedos",
    "status": "pending",
    "assigneeIds": ["a1b2c3d4-e5f6-7890-abcd-ef1234567890"]
  },
  "affectedResources": {
    "missionsReopened": [
      { "id": "f1a2b3c4-d5e6-7890-abcd-ef1234567890", "title": "Arrumar o quintal", "status": "inProgress" }
    ],
    "participationsRemoved": 2,
    "badgesRemoved": [
      { "memberId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890", "tier": "bronze" }
    ],
    "rewardRemoved": false
  }
}
```

`task` traz a projeção canônica já usada por `GET /v1/tasks/{taskId}` (SPEC-007), com `status: "pending"`. Quando a reabertura não afeta nenhuma missão, `affectedResources` vem com as listas vazias e `rewardRemoved: false`.

#### Recusa por confirmação pendente (`409 MISSION_REOPEN_REQUIRES_CONFIRMATION`)

```json
{
  "type": "https://api.rotinafamiliar.app/problems/mission-reopen-requires-confirmation",
  "title": "Confirmação necessária",
  "status": 409,
  "code": "MISSION_REOPEN_REQUIRES_CONFIRMATION",
  "requestId": "...",
  "missionsAffected": [
    { "id": "f1a2b3c4-d5e6-7890-abcd-ef1234567890", "title": "Arrumar o quintal" }
  ],
  "hasAcceptedReward": false
}
```

#### Erros padronizados

| HTTP | Código | Situação |
|---:|---|---|
| 403 | `ACTION_NOT_ALLOWED` | Kids tentando reabrir tarefa que não é própria |
| 404 | `RESOURCE_NOT_FOUND` | Tarefa inexistente ou de outra família |
| 409 | `TASK_NOT_COMPLETED` | Tarefa `pending` ou `awaitingConfirmation` |
| 409 | `MISSION_REOPEN_REQUIRES_CONFIRMATION` | Afeta missão concluída e/ou recompensa aceita, sem `confirm: true` |
| 503 | `DEPENDENCY_UNAVAILABLE` | Persistência incerta; não afirmar reversão da gravação |

Todas as falhas usam `application/problem+json`, com `type`, `title`, `status`, `code`, `requestId` e extensões específicas (`missionsAffected`, `hasAcceptedReward`) quando aplicável.

### 5.3. Concorrência e resultado incerto

- Não existe `Idempotency-Key` nem controle de versão otimista (BA-07); a última gravação válida persistida vence.
- A reabertura é serializada pelo lock por família (BA-08): duas requisições concorrentes de reabertura da mesma tarefa — a segunda encontra a tarefa já `pending` e responde `409 TASK_NOT_COMPLETED`, sem duplicar a reversão de crédito nem o fechamento de missão.
- Em resposta perdida, o mobile não repete a gravação automaticamente; consulta `GET /v1/tasks/{taskId}` para descobrir o estado antes de orientar nova tentativa (RNF12/13, MA-08).

## 6. Estados de domínio e transições

| Estado De | Evento | Estado Para | Quem pode executar | Regras | Efeitos colaterais |
|---|---|---|---|---|---|
| `completed` | `reopening` sem impacto de missão | `pending` | Admin/Membro/Kids (próprio) | RN55/57 | Retira crédito de carga do dia/semana; recalcula progresso de missões em andamento |
| `completed` | `reopening` com impacto, sem `confirm` | `completed` (inalterado) | idem | RN57/58 | `409`, nada persiste |
| `completed` | `reopening` com impacto, `confirm: true` | `pending` | idem | RN38/53/58 | Retira crédito; missão(ões) voltam a `inProgress`; remove participações, badges e recompensa aceita derivados |
| `pending` / `awaitingConfirmation` | `reopening` | — | — | RN57 | `409 TASK_NOT_COMPLETED`, nada persiste |

## 7. Critérios de aceitação (BDD)

- **CA-01: reabertura direta sem impacto de missão**
  **DADO QUE** um Administrador, Membro ou Kids (responsável) solicita reabrir uma tarefa `completed` sem vínculo a missão concluída nem recompensa aceita,
  **QUANDO** enviar `POST /v1/tasks/{taskId}/reopening`,
  **ENTÃO O SISTEMA DEVE** retornar a tarefa para `pending` mantendo os responsáveis e retirar o crédito do dia e da semana de todos eles,
  **E** responder `200 OK` com a tarefa canônica e `affectedResources` vazio. *(UC17, RN55/57, RF18/19)*

- **CA-02: confirmação exigida quando há impacto de missão**
  **DADO QUE** a tarefa `completed` está vinculada a uma missão `completed` e/ou com recompensa aceita,
  **QUANDO** a reabertura for solicitada sem `confirm: true`,
  **ENTÃO O SISTEMA DEVE** recusar com `409 MISSION_REOPEN_REQUIRES_CONFIRMATION`, sem persistir nenhuma alteração,
  **E** listar as missões afetadas no corpo da resposta. *(RN57/58)*

- **CA-03: reabertura confirmada reverte dados da missão**
  **DADO QUE** o mesmo cenário do CA-02,
  **QUANDO** a reabertura for reenviada com `confirm: true`,
  **ENTÃO O SISTEMA DEVE** retornar a tarefa para `pending`, retornar a(s) missão(ões) para `inProgress` e remover recompensa aceita, participações e badges derivados dela(s), tudo na mesma transação,
  **E** responder `200 OK` com `affectedResources` preenchido, sem preservar histórico desses dados removidos. *(RN38/53/58, UC17)*

- **CA-04: Kids reabre a própria tarefa**
  **DADO QUE** um perfil Kids é responsável por uma tarefa `completed`,
  **QUANDO** solicitar sua reabertura,
  **ENTÃO O SISTEMA DEVE** processá-la com as mesmas regras de CA-01/CA-02/CA-03. *(UC17 — atores)*

- **CA-05: Kids tenta reabrir tarefa de terceiro**
  **DADO QUE** um perfil Kids não é responsável pela tarefa `completed`,
  **QUANDO** tentar reabri-la,
  **ENTÃO O SISTEMA DEVE** recusar sem persistir, respondendo `403 ACTION_NOT_ALLOWED`,
  **E** a ação não deve ser exibida na interface Kids para essa tarefa. *(RNF07)*

- **CA-06: tarefa não concluída**
  **DADO QUE** a tarefa está `pending` ou `awaitingConfirmation`,
  **QUANDO** a reabertura for solicitada,
  **ENTÃO O SISTEMA DEVE** recusar com `409 TASK_NOT_COMPLETED`, sem alterar o estado. *(RN57)*

- **CA-07: isolamento multitenant**
  **DADO QUE** a tarefa pertence a outra família,
  **QUANDO** qualquer usuário tentar reabri-la,
  **ENTÃO O SISTEMA DEVE** responder `404 RESOURCE_NOT_FOUND`, sem revelar metadados. *(RNF06)*

- **CA-08: concorrência em reaberturas simultâneas**
  **DADO QUE** duas requisições de reabertura da mesma tarefa concorrem,
  **QUANDO** a segunda for processada após a primeira já ter confirmado,
  **ENTÃO O SISTEMA DEVE** responder `409 TASK_NOT_COMPLETED` à segunda, sem duplicar a reversão de crédito nem o fechamento de missão. *(RNF11/25, BA-08)*

- **CA-09: falha de rede e resposta perdida**
  **DADO QUE** o dispositivo perde conectividade antes de receber a resposta,
  **QUANDO** o cliente identificar timeout ou indisponibilidade,
  **ENTÃO O SISTEMA NÃO DEVE** apresentar a reabertura como concluída,
  **E** DEVE consultar `GET /v1/tasks/{taskId}` antes de permitir nova tentativa explícita. *(RNF12/13, MA-08)*

## 8. Observabilidade

| Evento | Gatilho | Dados permitidos |
|---|---|---|
| `task_reopened` | Reabertura persistida | `taskId`, `familyId`, `actorId`, `missionsReopenedCount`, `hadAcceptedReward` |
| `task_reopen_confirmation_required` | Resposta `409 MISSION_REOPEN_REQUIRES_CONFIRMATION` | `taskId`, `familyId`, `requestId` |
| `task_reopen_denied` | Tentativa bloqueada por permissão ou estado | `requestId`, `actorId`, `targetFamilyId`, `code` |

Segredos, tokens e dados de autenticação nunca entram em logs ou telemetria.

## 9. Premissas e decisões

| # | Decisão | Situação | Altera `docs/`? |
|---|---|---|---|
| E-01 | O mobile não pré-calcula o impacto de missão: a 1ª chamada de `reopening` (sem `confirm`) já tenta aplicar; se houver impacto, o servidor recusa com `409 MISSION_REOPEN_REQUIRES_CONFIRMATION` e devolve as missões afetadas, sem persistir nada; o mobile reenvia com `confirm: true` para efetivar. Evita estender o contrato já aprovado de `GET /v1/tasks/{taskId}` (SPEC-007) e mantém o servidor como única fonte de verdade (MA-07/08). | Decidida pela pessoa usuária em 2026-10-07 | Não — mecânica de contrato desta spec, comportamento já previsto em RN57/58/UC17 |
| P-01 | Embora SPEC-018 (visualizar carga) ainda não exista, a reversão de crédito definida aqui já deve manter os dados de carga corretos para quando essa tela for implementada. | Premissa | Não |
| P-02 | `Mission.reward` nunca é preenchido antes de SPEC-017 existir; `rewardRemoved` sempre será `false` até lá. | Premissa | Não |

## 10. Fases de implementação

| Fase | Objetivo | CAs atendidos | Prontidão | Status |
|---|---|---|---|---|
| **1** | Núcleo (API, RBAC, isolamento, fluxo de confirmação, concorrência) | CA-01 a CA-08 | Testes unitários e de integração verdes | a fazer |
| **2** | Mobile (TEL-010/TEL-040 círculo, TEL-012 ação Reabrir, MOD-006, Kids escopo próprio) | CA-01 a CA-05 integrados à UI | Telas integradas, UX-spec verificada | a fazer |
| **3** | Resiliência de rede | CA-09 | Suíte de regressão verde | a fazer |

- **Fase 1** não publica nenhuma tela; só o endpoint. Pode ser publicada isoladamente (nenhuma UI nova depende dela ainda).
- **Fase 2** entrega a ação completa no TEL-010/TEL-012/TEL-040. Deve sair junto com a Fase 1.
- **Fase 3** não muda comportamento funcional.

## 11. Checklist de aprovação

- [x] Todos os códigos citados (`RN`, `RF`, `RNF`, `UC`, `TEL`, `MOD`, `UF`) existem na base funcional vigente (1.13).
- [x] A rastreabilidade técnica (`MA-..`, `BA-..`) está alinhada com as diretrizes de arquitetura.
- [x] O contrato de API está completo e sem ambiguidades, incluindo o mecanismo de confirmação (E-01).
- [x] Todo critério de aceitação segue o padrão BDD e mapeia um teste automatizável.
- [x] Isolamento entre famílias (RNF06) e recusa por perfil (RNF07) constam explicitamente na Fase 1.
- [x] Nenhuma premissa sem decisão registrada na seção 9.
- [x] A UX-spec correspondente está vinculada.
- [x] A seção "Fora de questão" elimina riscos de suposições incorretas.
- [x] Status `aprovada` autorizado pela pessoa usuária em 2026-10-07.
