# Spec 009: Visualizar minhas tarefas

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-19
**Base funcional:** RN 1.18 / RF 1.17 / UC 1.16
**UX-spec:** [UX-009-visualizar-minhas-tarefas.md](UX-009-visualizar-minhas-tarefas.md)
**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 2 — Tarefas e rotina

## 1. Contexto e objetivo

- **Problema / necessidade:** a pessoa precisa enxergar rapidamente o que lhe cabe no dia, sem misturar a consulta pessoal com a visão de acompanhamento da família.
- **Objetivo da entrega:** disponibilizar a consulta diária de tarefas e progresso próprios a todos os perfis e, para adultos, a consulta familiar de tarefas e progresso em qualquer intervalo válido, preservando permissões e isolamento familiar.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Caso de uso | UC11 |
| Regras de negócio | RN16, RN22, RN23, RN26, RN27, RN28, RN33, RN49, RN55, RN60, RN61 |
| Requisitos funcionais | RF11, RF17, RF22, RF49, RF60, RF65, RF66 |
| Requisitos não funcionais | RNF01, RNF02, RNF04, RNF05, RNF06, RNF07, RNF08, RNF09, RNF12, RNF13, RNF14, RNF22 |
| Telas e fluxo | TEL-010, TEL-011, TEL-032, TEL-040, TEL-050, UF-04 |
| Decisões arquiteturais | MA-07, MA-19; BA-07, BA-37 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-feature-catalog.md`, `docs/architecture/mobile-decisions.md`, `docs/architecture/backend-contracts.md` e `docs/architecture/backend-decisions.md`.
- **Depende de:** [SPEC-007-gerenciar-tarefas.md](SPEC-007-gerenciar-tarefas.md), aprovada. Ela fornece a tarefa, os estados e o detalhe consultado.

## 3. Escopo da entrega

### 3.1. Dentro do escopo

- Minhas tarefas em TEL-010 e TEL-040: lista e progresso próprios exclusivamente do dia de referência. TEL-010 inclui apenas tarefas em que o adulto é responsável ou corresponsável.
- Tarefa compartilhada sinalizada por Kids: estado efetivo único `awaitingConfirmation`; na lista pessoal do adulto corresponsável aparece Pendente e na visualização pessoal Kids, Aguardando confirmação, sem alterar progresso, fila administrativa ou ações permitidas.
- Navegação pessoal por data entre a criação da família e o último dia do mês corrente, incluindo dias futuros do mês atual.
- Área Família adulta em TEL-050: progresso familiar e membros para Início/Fim livre; detalhe de membro em TEL-032 e lista complementar em TEL-011 preservam exatamente o intervalo escolhido. A seleção inicial é a semana corrente.
- Filtros familiares `memberId` e status; TEL-011 inclui tarefas sem responsável em Todos. Para Membro, `awaitingConfirmation` é projetado e contado como Pendente, sem mudar o estado canônico.
- Estados vazio, carregando, falha e acesso negado, com autorização e isolamento familiar desde a primeira fase.

### 3.2. Fora do escopo

- Distribuição de carga/sobrecarga, seus gráficos e métricas: SPEC-018.
- Criar, editar, excluir, concluir, reabrir, sinalizar ou validar tarefas: SPEC-007 e SPEC-010 a SPEC-013.
- Relatório PDF, missões, badges, ranking ou alteração de fuso.

### 3.3. Fora de questão

- A consulta pessoal não tem seletor Semana, inclusive para Kids.
- Kids não acessam endpoints, telas, filtros ou dados familiares.
- `GET /family/overview` não devolve carga nesta entrega; a carga será integrada na SPEC-018.
- Uma tarefa, membro ou filtro de outra família não revela existência, título, total ou metadados.

## 4. Perfis, acesso e isolamento

| Perfil | Consulta própria | Consulta familiar | Reação à tentativa indevida |
|---|---|---|---|
| Administrador | Tarefas e progresso próprios do dia | Progresso, lista familiar e detalhe de membro por Dia/Semana | `403 ACTION_NOT_ALLOWED` quando a capacidade não existir |
| Membro | Tarefas e progresso próprios do dia | Mesmas consultas familiares, sem ganhar gestão administrativa | `403 ACTION_NOT_ALLOWED` quando a capacidade não existir |
| Kids | Somente tarefas e progresso próprios do dia | Não acessa | Caminhos ocultos e `403 ACTION_NOT_ALLOWED` na API |

- **Isolamento familiar:** ID de membro ou tarefa de outra família resulta em `404 RESOURCE_NOT_FOUND`, sem dados ou contagens.
- **Autorização:** o backend deriva ator, papel e família da sessão e revalida todos os filtros no servidor; a UI não é a fonte de autorização.

## 5. Contratos e dados

| Rota | Entrada | Resultado | Permissão |
|---|---|---|---|
| `GET /v1/me/tasks` | `referenceDate` (`YYYY-MM-DD`), `cursor` opcional | Tarefas próprias do dia, paginação e `familyCreatedAt` | Todos |
| `GET /v1/me/progress` | `referenceDate` (`YYYY-MM-DD`) | Total, concluídas, progresso próprios do dia e `familyCreatedAt` | Todos |
| `GET /v1/family/overview` | `startDate`, `endDate` juntos ou ambos omitidos | Progresso familiar e membros, `familyCreatedAt`; sem carga. Sem datas, retorna semana corrente recortada | Adulto |
| `GET /v1/family/tasks` | `startDate`, `endDate`, `memberId` e `status` opcionais, `cursor` opcional | Tarefas familiares filtradas e intervalo efetivo, inclusive sem responsável em Todos | Adulto |
| `GET /v1/family/members/{memberId}/tasks` | `startDate`, `endDate`, `cursor` opcional | Tarefas daquele membro e intervalo efetivo | Adulto |

- `startDate` e `endDate` são datas inclusivas, com início menor ou igual a fim, dentro de RN49. A seleção inicial no aplicativo é a semana corrente, recortada nas bordas permitidas. As rotas retornam o intervalo efetivo.
- Nas rotas pessoais, `period` é campo desconhecido e deve ser recusado; a consulta é sempre diária.
- `memberId` deve identificar membro da família do ator. Sem `memberId`, a lista inclui tarefas sem responsável. `status` aceita `pending`, `awaitingConfirmation` (somente Administrador) ou `completed`; Membro que filtra `pending` também recebe `awaitingConfirmation` com `displayStatus: pending`.
- `GET /v1/me/tasks` filtra pelo ator responsável/corresponsável. Cada item devolve `status` canônico e `displayStatus` calculado para a lista pessoal: quando `status` é `awaitingConfirmation`, adulto recebe `displayStatus: pending` e Kids recebe `displayStatus: awaitingConfirmation`; nos demais estados os dois coincidem. Ações, progresso e fila usam `status`, sem segundo estado persistido.
- `GET /v1/me/tasks` e `GET /v1/me/progress` também devolvem `familyCreatedAt` (`YYYY-MM-DD`, data local à família), o limite inferior do carrossel pessoal (RN49). Decisão E-05: nenhum perfil tinha, antes desta entrega, acesso a essa data numa sessão já existente (`GET /v1/family` não a expõe e é bloqueada para Kids); o campo resolve isso simetricamente para os dois perfis, já que ambos chamam essas mesmas rotas.

| HTTP | Código | Situação |
|---:|---|---|
| 400 | `UNKNOWN_FIELD` | Campo incompatível com a rota, inclusive `period` na rota pessoal |
| 403 | `ACTION_NOT_ALLOWED` | Kids ou capacidade adulta inexistente |
| 404 | `RESOURCE_NOT_FOUND` | Recurso ou filtro de outra família/inexistente |
| 422 | `VALIDATION_FAILED` | Data, período ou filtro inválido |
| 503 | `DEPENDENCY_UNAVAILABLE` | Consulta não confirmada; não apresentar vazio como sucesso |

## 6. Critérios de aceitação

- **CA-01: consulta pessoal diária** — **DADO QUE** qualquer perfil possui sessão válida, **QUANDO** abrir Minhas tarefas, **ENTÃO** o sistema mostra o dia atual, somente tarefas em que a pessoa é responsável ou corresponsável e seu progresso diário, **E NÃO** oferece Semana. *(UC11, RN23/RN33/RN61, RF11/RF22)*
- **CA-02: mudança de data pessoal** — **DADO QUE** a pessoa navega no carrossel pessoal, **QUANDO** selecionar data dentro de RN49, **ENTÃO** atualiza apenas lista e progresso daquele dia. *(RN49, RF11, RF17)*
- **CA-03: limites e vazio pessoal** — **DADO QUE** a data está fora do intervalo ou não há tarefas no dia, **QUANDO** a consulta ocorrer, **ENTÃO** a seleção inválida é bloqueada ou é mostrado “Sem tarefas”, sem percentual fictício. *(RN49, RF49)*
- **CA-04: Kids restrito ao próprio dia** — **DADO QUE** a sessão é Kids, **QUANDO** acessar a aba inicial, **ENTÃO** consulta somente suas tarefas/progresso diários, **E** não recebe dados nem caminhos familiares. *(RN27, RF22, RF65)*
- **CA-05: consulta familiar adulta por intervalo** — **DADO QUE** um Administrador ou Membro abre Família, **QUANDO** escolher Início/Fim válido, **ENTÃO** vê progresso familiar e membros do intervalo inclusivo; a seleção inicial é a semana corrente. *(RN60, RN61, RF60)*
- **CA-06: lista familiar e sem responsável** — **DADO QUE** um adulto abre Tarefas da família, **QUANDO** aplicar o intervalo e o filtro Todos, **ENTÃO** vê também tarefas sem responsável, preservando o intervalo ao abrir detalhes. *(UC11, RN60)*
- **CA-07: filtro e detalhe de membro** — **DADO QUE** um adulto seleciona membro ou envia `memberId`, **QUANDO** o membro pertence à família, **ENTÃO** a lista é restringida a ele e TEL-032 preserva membro e exatamente o intervalo livre; voltar restaura a origem. *(RN60, RF66)*
- **CA-08: isolamento familiar** — **DADO QUE** a rota recebe ID de outra família, **QUANDO** o backend validar a requisição, **ENTÃO** responde `404 RESOURCE_NOT_FOUND`, **E** não vaza qualquer dado. *(RNF06, RNF07)*
- **CA-09: erro distinto de vazio** — **DADO QUE** a consulta falha ou retorna indisponível, **QUANDO** a interface tratar a resposta, **ENTÃO** mostra falha recuperável e não “Sem tarefas”. *(RNF12, RNF13)*
- **CA-10: overview sem carga** — **DADO QUE** um adulto consulta `GET /family/overview`, **QUANDO** recebe sucesso, **ENTÃO** a resposta contém somente progresso familiar e membros definidos nesta entrega, **E NÃO** simula distribuição de carga. *(E-02)*

- **CA-11: estado apresentado por perfil sem segundo estado** — **DADO QUE** Kids sinalizou tarefa compartilhada com um adulto,
  - **QUANDO** adulto corresponsável e Kids abrirem suas listas pessoais,
  - **ENTÃO** TEL-010 do adulto DEVE apresentar Pendente e a visualização Kids DEVE apresentar Aguardando confirmação,
  - **E** estado efetivo `awaitingConfirmation`, progresso, fila de validação e permissões permanecem os mesmos. *(RN23/RN55, RF11/RF22/RF24, UC11)*

- **CA-12: estado familiar apresentado por perfil** — **DADO QUE** há tarefas `awaitingConfirmation`, **QUANDO** Membro abre Família ou Tarefas da família, **ENTÃO** elas entram na contagem e no filtro Pendentes; Administrador vê a categoria Aguardando confirmação separada, **E** o estado efetivo, a fila Kids e as permissões permanecem iguais. *(RN23/RN60, RF60, UC11)*

## 7. Observabilidade

| Evento | Gatilho | Dados permitidos |
|---|---|---|
| `task_list_viewed` | Consulta confirmada | `actorId`, `familyId`, `scope` (`own`/`family`/`member`), `period` quando familiar |
| `task_query_denied` | Permissão ou isolamento bloqueou | `requestId`, `actorId`, `code` |
| `task_query_failed` | Falha de dependência | `requestId`, `scope`, `status` |

Não registrar título, observação, foto, tokens ou conteúdo de outra família.

## 8. Premissas e esclarecimentos

| # | Decisão | Situação | Altera `docs/`? |
|---|---|---|---|
| E-01 | Filtros originais chamavam-se `memberId` e `includeUnassigned`; E-06 substitui o segundo na lista atual. | Decidida pela pessoa usuária em 2026-10-06; revisada em 2026-10-27 | Sim |
| E-02 | `GET /family/overview` entrega progresso e membros; carga fica para SPEC-018. | Decidida pela pessoa usuária em 2026-10-06 | Sim |
| E-03 | Minhas tarefas é diária para todos os perfis; a consulta familiar adulta usa intervalo livre conforme E-06. | Decidida pela pessoa usuária em 2026-10-06; revisada em 2026-10-27 | Sim |
| E-04 | Para tarefa compartilhada sinalizada por Kids, a lista do adulto corresponsável apresenta Pendente e a visualização Kids apresenta Aguardando confirmação; o estado efetivo permanece único. | Pessoa usuária / 2026-10-19 | Sim — RN23/RN55, RF11/RF22 e UC11. |
| E-05 | `GET /v1/me/tasks` e `GET /v1/me/progress` passam a devolver `familyCreatedAt` (`YYYY-MM-DD`), derivado direto de `app.families.created_at` (sem lógica nova). Motivo: antes desta decisão, nenhum perfil tinha acesso à data de criação da família numa sessão já existente — `GET /v1/family` não a expõe e, além disso, é bloqueada para Kids — o que impedia o mobile de bloquear client-side as datas do carrossel pessoal anteriores à criação da família (RN49/RF11/RF22), tanto para adulto quanto para Kids. Expor o campo nas duas rotas pessoais resolve simetricamente para os dois perfis, já que ambos as chamam igualmente. | Architect / 2026-10-22 | Sim — RF11/RF22, RN49; `docs/architecture/backend-contracts.md` e `mobile-decisions.md` (MA-19) devem registrar o campo. |
| E-06 | Filtro familiar Início/Fim aceita qualquer intervalo inclusivo válido; TEL-032 herda exatamente esse intervalo. TEL-011 inclui tarefas sem responsável em Todos. | Pessoa usuária / 2026-10-27 | Sim — RN60/RN61, RF60/RF66, UC11. |
| E-07 | Nas consultas familiares de Membro, `awaitingConfirmation` é apresentado e contado como Pendente; Administrador mantém categoria própria. | Pessoa usuária / 2026-10-27 | Sim — RN23/RN60, RF60, UC11. |

**Contrato técnico revisado:** `backend-contracts.md` 1.23 e BA-37/MA-19 definem `status` e `displayStatus`. A projeção foi implementada no backend e no mobile; permissões e fila permanecem pelo estado efetivo.

## 9. Fases de implementação

| Fase | Objetivo | CAs | Prontidão | Status |
|---|---|---|---|---|
| 1 | Consulta própria diária, estado por perfil, validação, autorização e isolamento | CA-01 a CA-04, CA-08, CA-11 | Contrato de projeção reconciliado e testes unitários, integração e interface por perfil verdes | em andamento — backend anterior SCRUM-38 concluído; Mobile pendente (SCRUM-39) |
| 2 | Consulta familiar adulta, filtros, contexto e detalhe de membro | CA-05 a CA-07, CA-10, CA-12 | Testes de intervalo, filtros, perfil e navegação verdes | em implementação — backend e telas integrados; validação visual específica pendente |
| 3 | Falhas, acessibilidade e observabilidade | CA-09 | Estados de erro e telemetria verificados | a fazer |

**Registro de execução (2026-10-19):** SCRUM-38 concluiu a consulta própria diária anterior no backend. A Fase 1 requer verificar a projeção do estado por perfil e a interface Mobile (SCRUM-39).

## 10. Checklist de aprovação

- [x] Dependência SPEC-007 aprovada.
- [x] Regras de acesso, isolamento e validação atribuídas à Fase 1.
- [x] Contratos e filtros sustentados pela base funcional RN 1.18 / RF 1.17 / UC 1.16.
- [x] UX-spec vinculada.
- [x] Decisões E-01 a E-03 refletidas em `docs/`.
- [x] Revisão de 2026-10-19 aprovada com contrato de projeção definido; aprovação anterior de 2026-10-06 preservada no histórico.
