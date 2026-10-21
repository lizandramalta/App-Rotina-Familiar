# Backend — contratos de API e rastreabilidade

**Versão:** 1.18 · **Base funcional:** RN 1.18 / RF 1.17 / UC 1.16 · **Arquitetura backend:** 1.4\
**Data:** 2026-10-21\
**Situação:** `GetOwnProfile`/`UpdateOwnProfile`/`GetOwnBadges`/`GetBadgeContributions` materializados na API e OpenAPI (SPEC-006 Fase 1); ampliações de onboarding ainda exigem implementação e atualização da OpenAPI

[Arquitetura](backend-architecture.md) · [Decisões](backend-decisions.md) · [Catálogo mobile](mobile-feature-catalog.md) · [UC](../03-casos-de-uso.md) · [Índice](../DOCUMENTACAO.md)

## 1. Convenções comuns

Base `/v1`, HTTPS, JSON com propriedades em inglês. UUIDs identificam recursos, sem substituir autorização. Datas civis são strings `YYYY-MM-DD`; instantes ISO 8601 UTC. Enum de papel: `administrator`, `member`, `kids`; tarefa: `pending`, `awaitingConfirmation`, `completed`. Peso inteiro 1–3; frequência 1/7/14/21/28 dias. Campos não reconhecidos e campos protegidos em comandos são rejeitados, evitando atribuição indevida em massa.

Middleware resolve token/prova de instalação e constrói `ActorContext`; os casos de uso revalidam autorização, inclusive depois de esperar lock. A família vem da sessão, nunca de `familyId` aceito como autorização no body. GET por recurso sempre inclui escopo familiar/titularidade; recurso de outra família responde como indisponível sem revelar seus dados.

Access token vai em `Authorization: Bearer ...`; prova da instalação em header privado próprio, ambos removidos dos logs. Refresh, senha, provas Apple e segredo de recuperação vão somente no body de rotas específicas, com `no-store`. Cliente não envia créditos, pontuação, concessões, flag de Criador, instante de conclusão nem autor da operação.

`PATCH` preserva campos omitidos; `null` remove apenas campos explicitamente opcionais; `assigneeIds: []` remove todos os responsáveis quando permitido. A última gravação válida persistida vence, sem versão esperada. Listas substituídas são completas e sem duplicatas. Criar tarefa única e criar rotina são comandos distintos, embora compartilhem o formulário mobile.

| Resultado | Semântica |
|---|---|
| `200` | Consulta ou alteração confirmada com estado canônico |
| `201` | Recurso criado; ID devolvido. Rotina pode ter preparação de ocorrências ainda pendente |
| `202` | Consulta depende de materialização incompleta; retornar `preparing` e `Retry-After`, sem totais enganadores |
| `204` | Operação confirmada sem corpo, quando não exige invalidações adicionais |
| `400` | Formato inválido ou campos desconhecidos |
| `401` | Credencial inválida/expirada ou sessão revogada; código distingue renovação possível de revogação |
| `403` | Sessão válida sem capacidade para a operação; não exige limpar todas as credenciais |
| `404` | Recurso não disponível ao ator, inclusive outra família |
| `409` | Estado atual impede comando: já concluída, missão protegida/vazia, resgate existente, convite indisponível |
| `422` | Valores semanticamente inválidos, como frequência não suportada ou período de consulta proibido |
| `413` / `415` | Upload excedido / formato de mídia não aceito |
| `429` | Proteção de tentativas, com tempo de espera quando aplicável |
| `503` | Dependência indisponível; não afirmar que gravação incerta foi desfeita |

Erros usam `application/problem+json`, com `type`, `title`, `status`, `code`, `requestId` e, quando útil, `fieldErrors`. `code` estável orienta o texto localizado do app; não retornar stack/SQL/segredos. Request ID serve diagnóstico, não replay de operação. Códigos de conflito não implementam controle de versão otimista. [Problem Details — RFC 9457](https://www.rfc-editor.org/rfc/rfc9457.html).

GETs e polling podem ser repetidos; POST/PATCH/DELETE do usuário não são reenviados automaticamente. Se a resposta se perder, consultar recurso. Sem ID recebido, criação pode continuar incerta; o servidor não promete identificar a tentativa por igualdade de conteúdo. `202` não é confirmação de conclusão de uma tarefa ou de resgate.

## 2. Acesso e criação de família

Rotas públicas não autorizam leitura geral do perfil; respostas de inspeção do convite são mínimas e protegidas contra tentativas. Todas as rotas desta seção têm schemas específicos e limites de requisição.

| Método e caminho | Caso de uso de aplicação | Entrada / resultado | Acesso |
|---|---|---|---|
| `POST /access/apple` | `SignInWithApple` | Prova Apple, contexto da tentativa e instalação → sessão do Criador ou `creationGrant` | Prova Apple válida |
| `POST /families` | `CreateFamily` | `creationGrant`, `creatorName`, `creatorNickname` opcional, `name`, `timeZoneId` opcional (padrão `America/Sao_Paulo`), `initialMembers` opcional e `creatorPhotoMediaId` opcional; prova da instalação no header → família, Criador, membros iniciais, ciclo semanal inicial e sessão | Grant restrito à criação |
| `POST /access/invites/inspect` | `InspectInvite` | Token → disponibilidade e contexto mínimo para ingresso, sem senha/dados privados | Posse do token e limites de tentativas |
| `POST /access/invite-joins` | `JoinFamilyByInvite` | Token, senha, provas de instalação/tentativa; sessão anterior opcional e troca confirmada → sessão nova | Convite válido; antiga só é encerrada com sucesso |
| `POST /access/invite-joins/recover` | `RecoverInviteJoin` | `attemptId`, segredo da tentativa e prova original → credenciais daquele ingresso | Janela de dez minutos e sessão ainda ativa |
| `POST /access/refresh` | `RefreshSession` | Refresh + prova da instalação → novo access token | Sessão ativa e perfil ativo |
| `GET /me/session` | `GetCurrentSession` | Perfil, família, papel, flag `isFamilyCreator`, capacidades e IDs; nunca hashes | Sessão ativa |
| `DELETE /me/session` | `RevokeOwnSession` | Revoga sessão e dispositivo push; sem remover membro | Sessão ativa; contrato técnico de encerramento |

`creationGrant` não cria um quarto perfil. Seu prazo técnico não altera a ausência de expiração temporal de convite/refresh. Para criação concorrente, associação única à identidade Apple impede segunda família; retomar Apple permite descobrir a família criada após resposta perdida.

`initialMembers` é uma lista completa, possivelmente vazia, de `{name, role}`. `role` aceita somente `administrator`, `member` ou `kids`; IDs, convite, sessão e flag de Criador não vêm do cliente. O servidor valida todos os itens antes da escrita e cria família, Criador, membros iniciais, ciclo, eventual vínculo da foto e sessão em um único commit. Falha em qualquer item não deixa família ou perfis parciais. A resposta `201` preserva `family`, `member` (Criador) e `session`, e acrescenta `initialMembers: [{id, name, role}]`; não emite convites. `creatorPhotoMediaId` referencia somente mídia antecipada `READY`, de finalidade `profilePhoto`, vinculada ao mesmo grant e instalação. O grant consumido impede novo vínculo; em caso de resposta perdida, o cliente consulta a identidade pelo Apple, sem repetir a criação.

`SessionResult` contém `sessionId`, `memberId`, `familyId`, `role`, `isFamilyCreator`, `accessToken`, `accessTokenExpiresAt` e `refreshToken` no ingresso/recuperação. `GetCurrentSession` devolve `memberId`, `familyId`, `role` e `isFamilyCreator`, sem credenciais. Refresh não precisa devolver novamente o segredo estável.

Códigos públicos do ingresso: `INVITE_UNAVAILABLE` (404, neutro para token inválido, consumido, revogado ou perfil indisponível), `INVITE_PASSWORD_INVALID` (422, convite continua disponível), `ACCESS_SWITCH_CONFIRMATION_REQUIRED` (409), `SESSION_INVALID` (401, credencial anterior inválida), `RATE_LIMITED` (429, com `Retry-After`), `JOIN_RESULT_UNCERTAIN` (503, usar a recuperação) e `JOIN_RECOVERY_UNAVAILABLE` (404, neutro). Campos desconhecidos recebem `400 UNKNOWN_FIELD`; `familyId`, `memberId` e papel nunca são aceitos do cliente. Limites de entrada do ingresso e da recuperação: `token` até 256 caracteres, `password` até 64, `attemptSecret` de 16 a 256 e `installationProof` até 512, para que o cliente gere segredos com entropia suficiente e o scrypt não receba entradas desproporcionais. Limites e mecanismo em [BA-29–BA-34](backend-decisions.md#42-decisões-de-implementação-da-spec-005-ingresso-por-convite).

Troca confirmada não é endpoint para transferir membro. Uma sessão anterior de outra família pode ser encerrada por seu próprio titular como parte da troca, sem conceder acesso cruzado aos dados. Falha antes do commit preserva ambas as identidades; commit com resposta perdida exige recuperação, conforme a arquitetura.

## 3. Família, membros e perfil

| Método e caminho | Caso de uso de aplicação | Campos / resposta | Permissão |
|---|---|---|---|
| `GET /family` | `GetFamily` | `id`, `name`, `timeZoneId` confirmados | Adulto da família |
| `PATCH /family` | `UpdateFamily` | `name` → família confirmada; campo omitido não grava | Admin |
| `GET /family/settings` | `GetFamilySettings` | `timeZoneId`, `scheduledTimeZoneChange` (`{timeZoneId, effectiveAt}` ou `null`) e `limits` (`{startsAt, endsAt, timeZoneId, isTransition}`) | Admin |
| `POST /family/time-zone-changes/preview` | `PreviewFamilyTimeZoneChange` | `timeZoneId`, `application` → `proposedTimeZoneId`, `application`, `effectiveAt`, `effectiveLimits` e `isTransition`; recusa o fuso já vigente com `422 TIME_ZONE_UNCHANGED` | Admin; só lê, a liquidação de ciclos vencidos é feita em memória |
| `POST /family/time-zone-changes` | `ChangeFamilyTimeZone` | `timeZoneId`, `application: immediate \| nextCycle` → mesmo formato de `GET /family/settings`; recusa o fuso já vigente com `422 TIME_ZONE_UNCHANGED`; nova solicitação válida substitui a programada | Admin; revalidar papel e limites no commit |
| `GET /family/members` | `ListFamilyMembers` | `cursor` opaco opcional → `{items, nextCursor}`; até 20 perfis por página, em ordem estável | Adulto |
| `GET /family/members/{memberId}` | `GetMemberDetail` | Dados públicos do perfil e capacidades administrativas do ator | Adulto da família |
| `POST /family/members` | `CreateMember` | Nome administrativo/papel permitido → perfil ainda sem sessão | Admin |
| `PATCH /family/members/{memberId}` | `UpdateMember` | Nome administrativo; sem apelido/foto pessoal/identidade Apple | Admin |
| `POST /family/members/{memberId}/role-changes` | `ChangeMemberRole` | Papel/modo desejado, validando transições e Criador | Admin; Kids sai do modo antes de promoção |
| `POST /me/administration-exit` | `LeaveAdministration` | Rebaixar próprio Admin para Membro | Admin não Criador |
| `DELETE /family/members/{memberId}` | `RemoveMember` | Remoção lógica, revogação e recursos afetados | Admin; nunca Criador |
| `POST /family/members/{memberId}/invites` | `IssueMemberInvite` | Nova emissão/reenvio → link/senha transitórios | Admin; não Criador nem removido |
| `GET /me/profile` | `GetOwnProfile` | Nome, apelido, foto, total de participações, marcos e próximo marco | Titular, inclusive Kids |
| `PATCH /me/profile` | `UpdateOwnProfile` | `nickname`, `photoMediaId` opcionais/nulos | Titular; sem alteração de papel |
| `GET /me/badges` | `GetOwnBadges` | Marcos cumulativos do titular | Titular |
| `GET /me/badges/{awardId}` | `GetBadgeContributions` | Marco, data e missões contribuintes | Titular do marco |

Consulta de apelido público não expõe seu formulário/configuração a outros membros. `CreateMember` não gera convite automaticamente: criação do perfil e emissão são passos distintos do UC02, evitando duplicar membro ao repetir emissão. Reenviar é a mesma operação de emissão de novas credenciais, não leitura das anteriores.

Ao voltar de TEL-056 para TEL-002, o cliente carrega a família existente e seus membros. Prosseguir sem diferenças não chama rota de escrita. Se o nome mudou, usa `PATCH /family`; inclusões posteriores usam `POST /family/members`, ajustes de membros usam as rotas de SPEC-003 e fuso posterior usa a prévia/confirmação de `/family/time-zone-changes`. Essas operações exigem sessão de Administrador e revalidação após lock; nenhuma volta chama `POST /families`. Cada comando confirmado é independente, e o cliente consulta o estado após falha incerta antes de oferecer nova ação.

`PATCH /family` aceita somente `name`, com a mesma validação do nome na criação, e retorna `200` com `id`, `name` e `timeZoneId` confirmados. `familyId`, fuso, Criador e membros no corpo são campos protegidos/desconhecidos. O cliente não envia o PATCH quando o nome não mudou.

Preview de fuso é apenas leitura de suporte a MOD-012. A gravação pode refletir novo ciclo se o limite temporal avançar; devolver limites efetivos, sem assumir que preview reservou estado.

`GetOwnProfile`/`UpdateOwnProfile`/`GetOwnBadges`/`GetBadgeContributions` operam exclusivamente sobre o titular da sessão; nenhuma das quatro rotas aceita `memberId`. `UpdateOwnProfile` trata `nickname` e `photoMediaId` como campos independentes e opcionais — omitir um preserva seu valor vigente, `null` remove a configuração; os dois podem ser enviados juntos na mesma transação (se a foto for inválida, nenhuma das duas alterações persiste). `nickname` segue RN63 (até 20 caracteres não-espaço após trim, sem caracteres de controle) e responde `422 VALIDATION_FAILED`/`NICKNAME_INVALID_LENGTH` quando excede o limite — por consistência com os demais campos de comprimento do contrato (`TITLE_INVALID_LENGTH`, `WEIGHT_INVALID`, `FREQUENCY_DAYS_INVALID`), não `400` como uma versão anterior da SPEC-006 chegou a registrar. `photoMediaId`, quando enviado, é revalidado como `READY`, do titular e com `finalidade: profilePhoto`, usando os mesmos códigos `PHOTO_MEDIA_NOT_READY`/`PHOTO_MEDIA_NOT_OWNED`/`PHOTO_MEDIA_PURPOSE_MISMATCH` de `SignalTask`. Campos protegidos (`role`, `familyId`, `kidsMode`, `isFamilyCreator`, `appleUserID`, `status`, `concededAt`, `contributingMissionIds`) respondem `400 UNKNOWN_FIELD`, sem persistir — a rota administrativa `PATCH /family/members/{memberId}` já recusa `nickname`/`photoMediaId` pelo mesmo motivo, sem alteração nesta entrega. `GetOwnBadges`/`GetBadgeContributions` leem `app.mission_participations`/`app.badges`/`app.member_badges`/`app.badge_participations` (escritos exclusivamente por `CloseEligibleMissions`, SPEC-014); `totalParticipations: 0` devolve `nextTier` apontando para `bronze` (5), sem conceder badge simulado, e `nextTier` é `null` ao atingir `diamond` (50). `GetBadgeContributions` com `awardId` de outro titular — da mesma família ou de outra — responde `404 RESOURCE_NOT_FOUND`, sem distinguir os casos (RNF06). Kids opera as quatro rotas nos mesmos termos de um adulto (RF65), sem exposição administrativa. Para SPEC-006.

## 4. Tarefas, rotinas, Kids e indicadores

| Método e caminho | Caso de uso de aplicação | Campos / resposta | Permissão |
|---|---|---|---|
| `GET /me/tasks` | `GetOwnTasks` | `referenceDate`, cursor → tarefas do dia em que o ator é responsável ou corresponsável, com `status` canônico e `displayStatus` da lista pessoal | Todos |
| `GET /family/tasks` | `GetFamilyTasks` | `period`, `referenceDate`, `memberId` opcional, `includeUnassigned` opcional, cursor | Adulto |
| `GET /family/members/{memberId}/tasks` | `GetMemberTasks` | Período da origem e cursor | Adulto |
| `GET /tasks/{taskId}` | `GetTaskDetail` | Estado atual, origem, capacidades e detalhes autorizados | Adulto; Kids apenas responsável |
| `POST /tasks` | `CreateTask` | `title` (1–60 car.), `weight`, `scheduledDate`, `assigneeIds`, `note` (opcional, ≤250 car.) → tarefa única | Adulto |
| `PATCH /tasks/{taskId}` | `EditTask` | Campos editáveis de uma ocorrência, incluindo data e `note`; `signalResolution` (`resetToPending` \| `keepAwaitingConfirmation`) obrigatório quando o estado atual é `awaitingConfirmation` | Adulto; respeitar proteção |
| `DELETE /tasks/{taskId}` | `DeleteTask` | Exclusão individual e vínculos afetados; remove sinalização Kids corrente sem registrar decisão | Adulto; não concluída/não protegida |
| `POST /tasks/{taskId}/completion` | `CompleteTask` | Sem corpo → estado canônico; mantém responsáveis ou atribui o ator adulto se a tarefa não os tiver; tarefa com responsável Kids somente Admin | Adulto; Admin para tarefa Kids |
| `POST /tasks/{taskId}/reopening` | `ReopenTask` | Comando explícito → conclusão desfeita, missões/recompensas/badges afetados | Adulto; Kids somente tarefa própria |
| `POST /routines` | `CreateRoutine` | Título, peso, responsáveis, `note` opcional, `startDate`, `frequencyDays`; sem `endDate` → rotina e materialização | Adulto |
| `GET /routines/{routineId}` | `GetRoutine` | Configuração, versão vigente e progresso de materialização | Adulto |
| `PATCH /routines/{routineId}` | `UpdateFutureRoutine` | `fromTaskId`, configuração/data inicial/frequência; a ocorrência de origem e futuras elegíveis | Adulto |
| `POST /routines/{routineId}/future-task-deletions` | `DeleteFutureRoutineTasks` | `fromTaskId` → ocorrência de origem e futuras elegíveis, preservadas e fim de geração | Adulto |
| `POST /tasks/{taskId}/signals` | `SignalTask` | `photoMediaId` opcional → sinalização corrente | Kids responsável e tarefa pendente |
| `GET /kids/signals` | `GetKidsReviewQueue` | Sinalizações pendentes paginadas, da mais antiga para a mais recente | Admin |
| `GET /kids/signals/{signalId}` | `GetKidsSignal` | Tarefa, autor, foto opcional e estado da sinalização corrente | Admin |
| `POST /kids/signals/{signalId}/decision` | `DecideKidsSignal` | `decision: confirm \| reject` → tarefa/resultado canônico | Admin |
| `GET /me/progress` | `GetOwnProgress` | Totais próprios do dia; sem carga familiar | Todos |
| `GET /family/overview` | `GetFamilyOverview` | Progresso familiar e membros num snapshot; sem carga | Adulto |
| `GET /family/load` | `GetFamilyLoad` | Distribuição por membro e totais, sem ranking | Adulto |

Nas rotas familiares, `period` aceita `day` ou `week`; `referenceDate` é a data selecionada, validada pelo limite de consulta RN49. As rotas pessoais são sempre diárias e não aceitam `period`. `memberId` restringe a lista familiar a um membro da família do ator; `includeUnassigned` inclui ou exclui tarefas sem responsável. O servidor devolve intervalo nominal e efetivo nas consultas familiares. `GET /tasks/{id}` resolve criação fora do carrossel quando o ator pode consultar aquela tarefa; isso não cria novo calendário de navegação. Cadastro/edição não bloqueiam passado, meses futuros ou datas anteriores à família.

Em `GET /me/tasks`, cada item mantém `status: pending | awaitingConfirmation | completed` como estado efetivo. `displayStatus` usa os mesmos três valores: quando `status` é `awaitingConfirmation`, retorna `pending` para adulto responsável/corresponsável e `awaitingConfirmation` para Kids responsável; nos demais casos coincide com `status`. É projeção calculada para a lista pessoal, sem segundo estado persistido. Detalhe, fila de avaliação, permissões e progresso continuam usando `status` canônico. A consulta pessoal não inclui tarefas de outros responsáveis nem tarefas sem responsável.

`GET /family/load?period=day|week&referenceDate=YYYY-MM-DD` exige sessão adulta e retorna `200 OK` com `{ period, referenceDate, effectivePeriod: { startsOn, endsOn, timeZoneId, isTransition }, totalLoad, members }`. Cada entrada de `members` contém `memberId` ou `null` para crédito histórico removido, `displayName` ("Membro removido" quando `memberId` é nulo), `load` e `participationPercent` (nulo se `totalLoad` for zero). A consulta soma crédito válido pela data da conclusão, sem multiplicar joins; tarefas pendentes/aguardando confirmação não entram e reabertura remove o crédito original. `401 SESSION_EXPIRED`, `403 INSUFFICIENT_PERMISSIONS` para Kids, `422 VALIDATION_FAILED` para `period`/`referenceDate` inválidos ou fora do intervalo e `503 DEPENDENCY_UNAVAILABLE` para snapshot não confirmado. Não aceita `familyId`, ordenação de ranking nem limiar de sobrecarga.

O servidor não aceita perfil responsável, autor da conclusão ou escolha de atribuição no comando. O ator vem da sessão; a conclusão mantém responsáveis existentes ou atribui o ator adulto se não houver nenhum. Tarefa com ao menos um responsável Kids só aceita conclusão manual de Administrador; Membro recebe `403 ACTION_NOT_ALLOWED`. Se já estiver concluída, a transação não duplica créditos e responde `409 TASK_ALREADY_COMPLETED`; o cliente reconcilia silenciosamente consultando o estado canônico. Reabrir missão concluída remove recompensa aceita, participações e badges derivados no mesmo commit. Conclusão manual administrativa encerra a pendência Kids e preserva sinalização/foto para auditoria acessível apenas a Administradores. `signalId` é identidade de domínio que protege uma decisão contra outra sinalização mais recente, não versão geral de edição.

`SignalTask` exige ator com papel `kids` e revalida, na mesma transação, que o ator consta em `assigneeIds` e que a tarefa está `pending`; caso contrário responde `403 ACTION_NOT_ALLOWED` (ator não é Kids), `404 RESOURCE_NOT_FOUND` (tarefa indisponível, de outra família, ou da qual o Kids não é responsável — sem distinguir os casos) ou `409 TASK_NOT_PENDING` (tarefa já `awaitingConfirmation` ou `completed`). `photoMediaId`, quando enviado, é revalidado como `READY`, do titular e com `finalidade: taskSignal`, usando os mesmos códigos `PHOTO_MEDIA_NOT_READY`/`PHOTO_MEDIA_NOT_OWNED`/`PHOTO_MEDIA_PURPOSE_MISMATCH` de `UpdateOwnProfile`. Sucesso retorna `201 Created` com a tarefa canônica e a sinalização criada (`signal.id`, correspondente ao `signalId` usado por `DecideKidsSignal`). Para SPEC-012.

`GetKidsReviewQueue` retorna exclusivamente sinalizações ainda correntes em `awaitingConfirmation`, ordenadas por `signaledAt` crescente e `signalId` crescente, com cursor opaco associado a essa ordenação. `GetKidsSignal` só expõe sinalização corrente da família do Administrador; sinalização resolvida não integra histórico navegável e responde `404 RESOURCE_NOT_FOUND` nessa rota. A foto `taskSignal` pode ser transmitida somente ao Administrador da mesma família enquanto estiver vinculada a sinalização corrente avaliável; Membro/Kids recebem `403 ACTION_NOT_ALLOWED` e recursos de outra família respondem `404`, sem URL pública ou assinada.

`DecideKidsSignal` recebe somente `decision: confirm | reject`. Sob a mesma transação/lock de tarefa e família, `confirm` muda `awaitingConfirmation` para `completed`, registra o Administrador e cria crédito dos responsáveis finais; `reject` muda para `pending`, sem crédito ou efeito em missão. Ambos atualizam missões quando aplicável. Se outra decisão ou `CompleteTask` administrativo já retirou a sinalização do estado corrente, a rota responde `200 OK` com a tarefa canônica, `decisionOutcome` (`confirmed`, `rejected` ou `closedByManualCompletion`) e `applied: false`; não há escrita, erro visual obrigatório, crédito ou efeito duplicado. Na primeira decisão válida, retorna o mesmo formato com `applied: true`. Resposta perdida continua exigindo consulta antes de nova ação explícita. Para SPEC-013.

`CreateRoutine` e `UpdateFutureRoutine` usam `422 VALIDATION_FAILED` com `fieldErrors` estáveis: `FREQUENCY_DAYS_INVALID` para `frequencyDays` fora de 1/7/14/21/28, `START_DATE_INVALID` para `startDate` fora de `YYYY-MM-DD` e `ROUTINE_SOURCE_TASK_INVALID` quando `fromTaskId` não identifica uma ocorrência da rotina solicitada dentro da família do ator. Um `fromTaskId` de outra família é indisponível e responde `404`. Não existe `endDate` nesses comandos. `EditTask` rejeita com `422 VALIDATION_FAILED`/`SIGNAL_RESOLUTION_REQUIRED` qualquer gravação sobre tarefa `awaitingConfirmation` sem `signalResolution`, independentemente de quais campos mudaram. `resetToPending` transiciona a tarefa para `pending` e descarta a sinalização corrente; `keepAwaitingConfirmation` preserva o estado e a sinalização corrente com os dados editados. `DeleteTask` sobre tarefa `awaitingConfirmation` remove a sinalização corrente junto da tarefa, sem gerar `CONFIRMED`/`REJECTED`.

`TaskMutationResult` contém `task` e `affectedResources` com IDs/tipos e períodos a invalidar. Na conclusão implementada, `affectedResources` devolve, nesta ordem, `{type: "task", id}`, `{type: "ownTasks", referenceDate}` e `{type: "ownProgress", referenceDate}`; `referenceDate` é a data civil agendada da tarefa. `familyOverview`, fila Kids, missão, badges e relatório corrente entram quando essas projeções forem materializadas. Recursos sem permissão não têm dados privados devolvidos; pode-se invalidar uma área por tipo sem expor seus registros. Exclusões retornam ID removido, vínculos alterados e resumo dos registros preservados.

Consultas paginadas usam ordenação estável com ID como desempate e cursor opaco vinculado ao filtro. Página não determina totais. Em listas que mudam entre páginas, app recarrega ao receber invalidação; snapshot de relatório não depende dessas páginas. Limite de página é operacional, não limite de tarefas cadastráveis.

## 5. Missões, recompensa, relatório e reconhecimento

| Método e caminho | Caso de uso de aplicação | Campos / resposta | Permissão |
|---|---|---|---|
| `GET /missions` | `ListMissions` | Em andamento/concluídas, progresso e recompensa | Todos |
| `GET /missions/{missionId}` | `GetMissionDetail` | Título, `note`, vínculos individuais, participações e resgate; projeção Kids restrita | Todos da família |
| `GET /missions/task-options` | `GetMissionTaskOptions` | Ocorrências persistidas, filtros e paginação; sem selecionar rotina inteira | Admin |
| `POST /missions` | `CreateMission` | Título, `note` opcional (≤250 car.) e `taskIds` não vazio; sem prazo nem selo | Admin |
| `PATCH /missions/{missionId}` | `EditMission` | Título, `note` e/ou conjunto completo de `taskIds`; pode encerrar missão; rejeita `taskIds` vazio | Admin; em andamento |
| `GET /reward-items` | `ListRewardItems` | Catálogo predefinido + itens personalizados da família, com título, descrição e origem | Admin |
| `POST /reward-items` | `AddRewardItem` | `title` obrigatório + `details` opcional → item elegível | Admin |
| `POST /missions/{missionId}/reward-acceptance` | `AcceptMissionReward` | `rewardItemId` → `200` com missão canônica e snapshot do aceite único | Admin; concluída/sem resgate |
| `GET /reports/weekly-snapshot` | `GetWeeklyReportSnapshot` | Data/semana ou ciclo selecionado → JSON consistente, nunca PDF binário | Adulto |
| `GET /me/weekly-recognitions` | `ListOwnWeeklyRecognitions` | Lista de resultados finalizados próprios | Titular, inclusive Kids |
| `GET /me/weekly-recognitions/{recognitionId}` | `GetOwnWeeklyRecognition` | Pontos, contagem, empate, período/fuso preservados | Titular reconhecido |
| `PUT /me/push-device` | `RegisterPushDevice` | Token APNs/ambiente → dispositivo da sessão atual | Sessão ativa |
| `POST /me/weekly-recognitions/{recognitionId}/opening` | `RecordRecognitionOpening` | Registra primeira abertura de forma monotônica | Titular; não comprova leitura/envio |

`GET /reward-items` devolve os seis itens predefinidos de RN42 e somente os personalizados da família da sessão. `POST /reward-items` aceita `{ "title": string, "details"?: string }`: normaliza o título com `trim`, rejeita vazio, caracteres de controle e mais de 60 caracteres não-espaço; aceita descrição opcional de até 255 caracteres contando espaços. A unicidade é por família sobre o título normalizado, sem distinguir maiúsculas/minúsculas; colisão retorna `422 REWARD_TITLE_ALREADY_EXISTS`. Os demais erros de campo usam `422 VALIDATION_FAILED` com `fieldErrors` estáveis (`title` ou `details`). Sucesso retorna `201 Created` com o item canônico e sua origem `custom`. Uma resposta perdida é recuperável por nova consulta do catálogo, sem criar outro item quando o título normalizado já existir.

`POST /missions/{missionId}/reward-acceptance` aceita somente `{ "rewardItemId": "uuid" }`, sem `familyId`, resultado de sorteio ou campos de recompensa controlados pelo cliente. Em uma transação, revalida sessão, papel, escopo familiar, missão concluída, ausência de aceite e elegibilidade do item no catálogo da família; ao confirmar, retorna `200 OK` com a projeção canônica da missão e o snapshot da recompensa aceita. Missão fora do escopo familiar retorna `404 RESOURCE_NOT_FOUND`; perfil não administrador retorna `403 INSUFFICIENT_PERMISSIONS`; `rewardItemId` inválido ou não elegível retorna `422 REWARD_ITEM_NOT_ELIGIBLE`, sem revelar a origem de outro item. Missão ainda não resgatável retorna `409 MISSION_REWARD_REDEMPTION_UNAVAILABLE`; se já houver aceite, inclusive por concorrência, retorna `409 MISSION_REWARD_ALREADY_ACCEPTED`. Após resposta perdida, o cliente consulta a missão antes de oferecer nova tentativa; não há retentativa automática nem endpoint para registrar sorteio ou recusa.

Registrar rota estática `task-options` sem ambiguidade com `{missionId}`. Não há endpoints de sorteio, recusa de resultado da roleta, concessão manual de badge, edição de missão concluída ou envio de WhatsApp. Ausência de endpoints de editar/excluir item de recompensa respeita o escopo de consulta/adição do UC06. Nenhum endpoint permite um cliente comum disparar/finalizar apuração.

Resumo Kids de missão pode mostrar títulos/estados coletivos necessários ao UC14, mas não carga, PDF, dados administrativos nem mídia Kids de outro titular. Link para detalhe de tarefa permanece autorizado separadamente.

`GET /reports/weekly-snapshot?referenceDate=YYYY-MM-DD` exige sessão adulta; resolve a semana segunda–domingo no fuso da família e retorna `period`, `timeZoneId`, `isTransition`, `generatedAt`, `isPartial`, totais e linhas. Rejeita semana futura ou sem interseção com a família com `422 VALIDATION_FAILED`; Kids recebem `403 INSUFFICIENT_PERMISSIONS`; indisponibilidade retorna `503 DEPENDENCY_UNAVAILABLE`. Linhas históricas de perfil removido usam `memberId: null` e `displayName: "Membro removido"`, sem dados pessoais. `FinalizeWeeklyHighlight` é job com chave família/ciclo: persiste uma vez resultado sem vencedor ou reconhecimentos empatados e intenções de notificação. `GET /me/weekly-recognitions` retorna somente resultados finalizados do titular; `GET /me/weekly-recognitions/{recognitionId}` responde `404 RESOURCE_NOT_FOUND` quando não pertence ao titular; `POST /me/weekly-recognitions/{recognitionId}/opening` é monotônico e não comprova leitura/envio. Datas/pontos vêm do snapshot final, não de nova soma. Mensagem editável e abertura WhatsApp são locais; o backend não registra “enviado” por abrir o aplicativo externo.

## 6. Mídia e rotas operacionais

| Método e caminho | Contrato | Acesso |
|---|---|---|
| `POST /onboarding/media` | Upload multipart de foto inicial com `creationGrant`, `purpose: profilePhoto` e arquivo → `mediaId`, estado e dimensões; prova de instalação no header | Grant válido da identidade Apple sem família, vinculado à instalação; sem Bearer de membro |
| `POST /media` | Upload multipart, `purpose: profilePhoto \| taskSignal` → `mediaId`, estado e dimensões | Titular; `taskSignal` exige somente que o ator tenha papel Kids — o upload não recebe nem valida `taskId` |
| `GET /media/{mediaId}/content` | Streaming privado, tipo/tamanho corretos e sem cache compartilhado | Sessão ativa e leitura permitida pela finalidade/vínculo |
| `GET /health/live` | Estado mínimo do processo | Operação; sem detalhes internos |
| `GET /health/ready` | Prontidão da função API/worker | Infraestrutura autorizada |

Perfil recebe `photoMediaId`; sinalização recebe `photoMediaId` opcional. Ambos revalidam que a mídia está pronta, é do titular/da família e tem finalidade compatível. URL arbitrária no body não substitui esse contrato. Antes de vínculo, só quem enviou pode consultar sua mídia. R2 é privado e credenciais S3 nunca aparecem no retorno.

`POST /onboarding/media` reserva mídia privada sem `familyId` ou `memberId`: associa o registro ao grant válido e à prova da instalação, sem criar perfil/sessão nem permitir leitura familiar. O upload respeita o processamento e os limites da foto de perfil. `POST /families` revalida esse vínculo antes e dentro da transação; mídia ausente, não pronta, de outro grant/instalação ou de outra finalidade recebe `422 VALIDATION_FAILED`, com `fieldErrors.creatorPhotoMediaId` (`PHOTO_MEDIA_NOT_READY`, `PHOTO_MEDIA_NOT_OWNED` ou `PHOTO_MEDIA_PURPOSE_MISMATCH`, conforme o caso). Omitir a referência cria a família sem foto. Grant vencido ou substituído exige novo upload para o novo grant; mídia sem vínculo entra na limpeza após 24 horas. A imagem escolhida permanece localmente para prévia até a criação confirmada.

O grant e a prova de instalação do upload são segredos: não entram em logs, URLs ou telemetria; resposta usa `Cache-Control: no-store`. A rota retorna `401 CREATION_GRANT_INVALID` para grant ausente, vencido ou não associado à instalação e mantém `413 MEDIA_TOO_LARGE`/`415 MEDIA_FORMAT_UNSUPPORTED` para arquivo inválido. `GET /media/{mediaId}/content` só passa a servir a foto antecipada depois do vínculo e da autorização por sessão.

A revalidação de contexto de tarefa (estado `pending`, titularidade do responsável) acontece exclusivamente no vínculo via `SignalTask`, nunca no upload: `POST /media` com `purpose: taskSignal` não amarra a mídia a um `taskId` (SPEC-012). Reutilizar em outra sinalização uma mídia já vinculada não é um fluxo válido: cada sinalização recebe seu próprio `photoMediaId`, revalidado no momento do vínculo.

Página de Universal Link e `/.well-known/apple-app-site-association` são artefatos HTTP de integração, fora do prefixo da API. Não consomem convite nem autenticam o visitante. Página orienta loja e nova abertura do link após instalar, sem prometer deferred deep linking. URLs/domínio reais serão configuração de implantação.

## 7. Rastreabilidade UC para backend

Cada linha cobre um objetivo funcional completo, não apenas uma rota. RF/RN permanecem definidos na especificação vinculada; o catálogo mobile identifica TEL/MOD/UF. As referências abaixo destacam as garantias centrais.

| UC | Aplicação / módulos | Garantia principal | Base funcional |
|---|---|---|---|
| <a id="backend-uc01"></a>[UC01](../03-casos-de-uso.md#uc01) | `UploadOnboardingPhoto`, `CreateFamily`, `GetFamily`, `UpdateFamily`, `ChangeFamilyTimeZone` / Access, Family, Media, Recognition | Criação conjunta do Criador e membros iniciais, foto antecipada protegida, edição posterior sem recriação e fuso selecionável | RF01/02/38/39/40/48/67; RN01/07/09/28/44/63/65 |
| <a id="backend-uc02"></a>[UC02](../03-casos-de-uso.md#uc02) | `CreateMember`, `UpdateMember`, `ChangeMemberRole`, `LeaveAdministration`, `RemoveMember`, `IssueMemberInvite` | Proteção do Criador, remoção seletiva, novas credenciais e revogação | RF02–06/40/41/54; RN01–10/45–47 |
| <a id="backend-uc03"></a>[UC03](../03-casos-de-uso.md#uc03) | `DecideKidsSignal` / Kids, Tasks, Missions | Primeira decisão válida, confirmação creditada a todos os responsáveis | RF25/26/55/56; RN22–26/54/55 |
| <a id="backend-uc04"></a>[UC04](../03-casos-de-uso.md#uc04) | `SignInWithApple` / Access | Prova validada; sessão única do Criador ou grant restrito | RF37/39; RN44; RNF15/16/22 |
| <a id="backend-uc05"></a>[UC05](../03-casos-de-uso.md#uc05) | `CreateMission`, `EditMission`, `CloseEligibleMissions` | Ao menos uma tarefa, participação e marcos na transação | RF28/29/31/32/50/58; RN35–40/50/51/58/64 |
| <a id="backend-uc06"></a>[UC06](../03-casos-de-uso.md#uc06) | `ListRewardItems`, `AddRewardItem` / Rewards | Predefinidas + família; só Admin adiciona; título normalizado único e descrição opcional | RF33/34; RN41/42 |
| <a id="backend-uc07"></a>[UC07](../03-casos-de-uso.md#uc07) | `CreateTask`, `EditTask`, `DeleteTask` / Tasks | Datas livres, título ≤60, observação ≤250, edição de concluída não protegida, resolução de sinalização pendente, auditoria, missão não vazia e fechamento da missão (`CloseEligibleMissions`) quando a exclusão deixa só tarefas concluídas | RF07–10/15/16/27/58/59/69/70; RN11–13/17–20/50/58/59/66/67 |
| <a id="backend-uc08"></a>[UC08](../03-casos-de-uso.md#uc08) | `CreateRoutine`, `UpdateFutureRoutine`, `MaterializeRoutineOccurrences` | Frequências fixas, observação opcional, horizonte e origem estável; proteger passado/conquistas | RF13/14/70; RN14/16–18/67 |
| <a id="backend-uc09"></a>[UC09](../03-casos-de-uso.md#uc09) | `InspectInvite`, `JoinFamilyByInvite`, `RecoverInviteJoin`, `RefreshSession` | Consumo único, prova de instalação e troca sem remoção | RF42–46/54/68; RN09/10/45–47 |
| <a id="backend-uc10"></a>[UC10](../03-casos-de-uso.md#uc10) | `GetOwnProfile`, `UpdateOwnProfile`, `GetOwnBadges`, `GetBadgeContributions` | Titularidade, câmera/galeria na UI e marcos por participação | RF48/62/65; RN63/64 |
| <a id="backend-uc11"></a>[UC11](../03-casos-de-uso.md#uc11) | `GetOwnTasks`, `GetFamilyTasks`, `GetMemberTasks`, `GetOwnProgress`, `GetFamilyOverview` | Consulta própria diária apenas de responsáveis, com apresentação do estado por perfil; Dia/Semana familiar adulta e carrossel | RF11/17/22/24/49/60/65/66; RN23/26/27/33/49/55/60/61 |
| <a id="backend-uc12"></a>[UC12](../03-casos-de-uso.md#uc12) | `CompleteTask` / Tasks, Kids, Missions | Direta, mantém responsáveis ou atribui adulto sem responsável; crédito integral e tarefa Kids só Admin | RF12/26/47/56; RN21–23/30/48/55/56 |
| <a id="backend-uc13"></a>[UC13](../03-casos-de-uso.md#uc13) | `GetFamilyLoad` / Insights | Carga pelo instante da conclusão, sem duplicação por joins | RF18–21/56/57/66; RN28/30/31/33/34/57/61 |
| <a id="backend-uc14"></a>[UC14](../03-casos-de-uso.md#uc14) | `ListMissions`, `GetMissionDetail` / Missions | Tarefas distintas; reabertura confirmada remove recompensa e dados derivados; projeção Kids | RF30/31/36/58/62/65; RN35–39/43/51–53/58/64 |
| <a id="backend-uc15"></a>[UC15](../03-casos-de-uso.md#uc15) | `UploadMedia`, `SignalTask` / Media, Kids | Foto opcional; sinalizar não conclui nem credita; `404`/`409` protegem titularidade e estado `pending` | RF23/24/55/56; RN21–26/54/55 |
| <a id="backend-uc16"></a>[UC16](../03-casos-de-uso.md#uc16) | `AcceptMissionReward` / Rewards, Missions | Sorteio local, um aceite remoto | RF35/51–53; RN42/43/52/53; RNF23 |
| <a id="backend-uc17"></a>[UC17](../03-casos-de-uso.md#uc17) | `ReopenTask` / Tasks, Missions, Rewards | Perfil com acesso à tarefa; confirmação se missão concluída/recompensa; retirar crédito uma vez e reverter dados derivados | RF57–59; RN55/57–59 |
| <a id="backend-uc18"></a>[UC18](../03-casos-de-uso.md#uc18) | `GetWeeklyReportSnapshot` / Reports, Insights | Snapshot consistente adulto para PDF local | RF61; RN62; RNF26/27 |
| <a id="backend-uc19"></a>[UC19](../03-casos-de-uso.md#uc19) | `FinalizeWeeklyHighlight`, `GetOwnWeeklyRecognition`, `DeliverRecognitionNotification` | Ciclo encerrado, positivos/empates, resultado preservado e outbox | RF63/64; RN28/30/65; RNF26/27 |

## 8. Cobertura não funcional

| RNF | Obrigação no backend |
|---|---|
| RNF01–05 | Estados/erros compreensíveis e projeções acessíveis; UI final continua responsabilidade mobile |
| RNF06/07 | Escopo por família, papel, titularidade, whitelist de campos e revalidação no lock |
| RNF08 | TLS e credenciais privadas, incluindo conexão com banco |
| RNF09–11/25 | Transações, unicidade, histórico de tarefas e reversão consistente de dados derivados de missão |
| RNF12/13 | Resultado incerto explícito, limites de processamento e preparação consultável |
| RNF14 | Dependências internas e contratos que preservam módulos |
| RNF15/16 | Validação oficial Apple e proteção da identidade |
| RNF17–21 | Segredos imprevisíveis/protegidos, limitação de tentativas e consumo único |
| RNF22 | Sessão única revogável, prova de instalação, refresh estável e recuperação restrita |
| RNF23 | Aceite de recompensa consistente sob concorrência |
| RNF24 | R2 privado, leitura autorizada por finalidade e revogação |
| RNF26 | Snapshot para PDF, resultado semanal único e fila persistente |
| RNF27 | Perfil por titularidade, PDF adulto e compartilhamento explícito no cliente |

O documento OpenAPI 3.1 é gerado pelos schemas HTTP em `/docs/json`, e a interface interativa fica em `/docs`. A projeção `displayStatus` de `GET /me/tasks` já consta da OpenAPI; as demais ampliações aqui descritas só constarão depois de implementadas. Cada rota implementada mantém schema, segurança e respostas compatíveis com o recorte entregue.

## Histórico

| Versão | Data | Alteração |
|---|---|---|
| 1.18 | 2026-10-21 | `GetOwnProfile`, `UpdateOwnProfile` (com `nickname`), `GetOwnBadges` e `GetBadgeContributions` materializados na API e OpenAPI (SPEC-006 Fase 1, CA-01 a CA-12; SCRUM-51). `NICKNAME_INVALID_LENGTH` corrigido para `422` (E-03 da SPEC-006), por consistência com os demais campos de comprimento do contrato. |
| 1.17 | 2026-10-19 | `GET /me/tasks` passa a devolver `status` e `displayStatus` por perfil na resposta e na OpenAPI (SPEC-009 Fase 1, CA-01/04/08/11; SCRUM-107). As ampliações de onboarding continuam pendentes. |
| 1.16 | 2026-10-19 | UC07: `DeleteTask` fecha a missão via `CloseEligibleMissions` quando restam só tarefas concluídas (RN38/RF59; SPEC-014/SPEC-007). Contrato alvo de criação atômica com membros/foto antecipada, edição da família existente e `displayStatus` pessoal; distingue essas ampliações das rotas já implementadas. |
| 1.15 | 2026-10-10 | Consolida os contratos de SPEC-015 a SPEC-020 com as rotas materializadas de família, convites, sessão e tarefas, incluindo OpenAPI executável, paginação de membros e `CompleteTask`. |
| 1.14 | 2026-10-10 | `FinalizeWeeklyHighlight` e as consultas próprias de reconhecimento detalhados: resultado único, empate, outbox e titularidade. Para SPEC-020. |
| 1.13 | 2026-10-10 | `GetWeeklyReportSnapshot` detalhado: `referenceDate`, validação de semana, projeção de removido e erros estáveis. Para SPEC-019. |
| 1.12 | 2026-10-10 | `GetFamilyLoad` detalhado: snapshot Dia/Semana, período efetivo/fuso, membros removidos históricos, totais, percentuais e erros estáveis. Para SPEC-018. |
| 1.11 | 2026-10-10 | `AcceptMissionReward` detalhado: `200` canônico, validações transacionais, códigos estáveis de conflito e de item inelegível, e recuperação por consulta após resposta perdida. Para SPEC-017. |
| 1.10 | 2026-10-10 | `ListRewardItems` e `AddRewardItem` detalhados: catálogo inicial, título normalizado único por família, descrição opcional (≤255) e recuperação por consulta após resposta perdida. Para SPEC-015. |
| 1.9 | 2026-10-08 | `GetKidsReviewQueue`, `GetKidsSignal` e `DecideKidsSignal` detalhados: fila pendente ordenada por antiguidade, foto privada de sinalização corrente, decisão atômica e retorno canônico silencioso (`applied: false`) para decisão/conclusão concorrente já resolvida. Para SPEC-013. |
| 1.8 | 2026-10-07 | `SignalTask` detalhado: ator Kids, revalidação de titularidade/estado (`403 ACTION_NOT_ALLOWED`, `404 RESOURCE_NOT_FOUND`, `409 TASK_NOT_PENDING`), resposta `201 Created` com `signal.id`. `POST /media` com `purpose: taskSignal` passa a ser aceito, validando somente o papel Kids no upload; contexto de tarefa é revalidado só no vínculo. Para SPEC-012. |
| 1.7 | 2026-10-07 | `CreateMission`/`EditMission` ganham `note` opcional (≤250 car.); `GetMissionDetail` expõe `note`; `EditMission` explicita rejeição de `taskIds` vazio. Para SPEC-014. |
| 1.5 | 2026-10-06 | Conclusão de tarefa com responsável Kids exige Administrador; `TASK_ALREADY_COMPLETED` reconcilia concorrência sem duplicar crédito; sinalização/foto pendente é auditável só por Admin. Para SPEC-010. |
| 1.4 | 2026-10-06 | Rotas pessoais de UC11 ficam diárias; rotas familiares adultas usam `period`, `memberId` e `includeUnassigned`; overview não inclui carga nesta entrega. Para SPEC-009. |
| 1.3 | 2026-10-06 | Contratos de rotina passam a aceitar `note`, explicitam a ausência de `endDate`, o alcance inclusivo de `fromTaskId` e os erros `FREQUENCY_DAYS_INVALID`, `START_DATE_INVALID` e `ROUTINE_SOURCE_TASK_INVALID`. Para SPEC-008. |
| 1.2 | 2026-10-06 | `CreateTask`/`EditTask` ganham `note` opcional (≤250 car.); `EditTask` ganha `signalResolution` obrigatório sobre tarefa `awaitingConfirmation`; `DeleteTask` remove a sinalização corrente. Para SPEC-007. |
| 1.1 | 2026-10-06 | `SPEC-001`: `SessionResult` e `GetCurrentSession` passam a expor `isFamilyCreator`, necessário para o cliente aplicar as proteções do Criador. |
| 1.0 | 2026-10-05 | Contratos `/v1`, autenticação, projeções, erros, cobertura UC01–UC19 e RNF01–27. |
