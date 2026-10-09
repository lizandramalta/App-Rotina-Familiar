# Backend — contratos de API e rastreabilidade

**Versão:** 1.13 · **Base funcional:** 1.14 · **Arquitetura backend:** 1.3\
**Data:** 2026-10-09\
**Situação:** contrato arquitetural materializado pela documentação OpenAPI da API

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
| `POST /families` | `CreateFamily` | `creationGrant`, `creatorName`, `creatorNickname` opcional, `name`, `timeZoneId` opcional (padrão `America/Sao_Paulo`) e prova da instalação no header → família, Criador, ciclo semanal inicial e sessão. O grant só vale para a instalação que o recebeu | Grant restrito à criação |
| `POST /access/invites/inspect` | `InspectInvite` | Token → disponibilidade e contexto mínimo para ingresso, sem senha/dados privados | Posse do token e limites de tentativas |
| `POST /access/invite-joins` | `JoinFamilyByInvite` | Token, senha, provas de instalação/tentativa; sessão anterior opcional e troca confirmada → sessão nova | Convite válido; antiga só é encerrada com sucesso |
| `POST /access/invite-joins/recover` | `RecoverInviteJoin` | `attemptId`, segredo da tentativa e prova original → credenciais daquele ingresso | Janela de dez minutos e sessão ainda ativa |
| `POST /access/refresh` | `RefreshSession` | Refresh + prova da instalação → novo access token | Sessão ativa e perfil ativo |
| `GET /me/session` | `GetCurrentSession` | Perfil, família, papel, flag `isFamilyCreator`, capacidades e IDs; nunca hashes | Sessão ativa |
| `DELETE /me/session` | `RevokeOwnSession` | Revoga sessão e dispositivo push; sem remover membro | Sessão ativa; contrato técnico de encerramento |

`creationGrant` não cria um quarto perfil. Seu prazo técnico não altera a ausência de expiração temporal de convite/refresh. Para criação concorrente, associação única à identidade Apple impede segunda família; retomar Apple permite descobrir a família criada após resposta perdida.

`SessionResult` contém `sessionId`, `memberId`, `familyId`, `role`, `isFamilyCreator`, `accessToken`, `accessTokenExpiresAt` e `refreshToken` no ingresso/recuperação. `GetCurrentSession` devolve `memberId`, `familyId`, `role` e `isFamilyCreator`, sem credenciais. Refresh não precisa devolver novamente o segredo estável.

Códigos públicos do ingresso: `INVITE_UNAVAILABLE` (404, neutro para token inválido, consumido, revogado ou perfil indisponível), `INVITE_PASSWORD_INVALID` (422, convite continua disponível), `ACCESS_SWITCH_CONFIRMATION_REQUIRED` (409), `SESSION_INVALID` (401, credencial anterior inválida), `RATE_LIMITED` (429, com `Retry-After`), `JOIN_RESULT_UNCERTAIN` (503, usar a recuperação) e `JOIN_RECOVERY_UNAVAILABLE` (404, neutro). Campos desconhecidos recebem `400 UNKNOWN_FIELD`; `familyId`, `memberId` e papel nunca são aceitos do cliente. Limites de entrada do ingresso e da recuperação: `token` até 256 caracteres, `password` até 64, `attemptSecret` de 16 a 256 e `installationProof` até 512, para que o cliente gere segredos com entropia suficiente e o scrypt não receba entradas desproporcionais. Limites e mecanismo em [BA-29–BA-34](backend-decisions.md#42-decisões-de-implementação-da-spec-005-ingresso-por-convite).

Troca confirmada não é endpoint para transferir membro. Uma sessão anterior de outra família pode ser encerrada por seu próprio titular como parte da troca, sem conceder acesso cruzado aos dados. Falha antes do commit preserva ambas as identidades; commit com resposta perdida exige recuperação, conforme a arquitetura.

## 3. Família, membros e perfil

| Método e caminho | Caso de uso de aplicação | Campos / resposta | Permissão |
|---|---|---|---|
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

Preview de fuso é apenas leitura de suporte a MOD-012. A gravação pode refletir novo ciclo se o limite temporal avançar; devolver limites efetivos, sem assumir que preview reservou estado.

## 4. Tarefas, rotinas, Kids e indicadores

| Método e caminho | Caso de uso de aplicação | Campos / resposta | Permissão |
|---|---|---|---|
| `GET /me/tasks` | `GetOwnTasks` | `referenceDate`, cursor → tarefas próprias do dia | Todos |
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
| `GET /kids/signals` | `GetKidsReviewQueue` | Sinalizações pendentes paginadas | Admin |
| `GET /kids/signals/{signalId}` | `GetKidsSignal` | Tarefa, autor, foto opcional e estado da sinalização | Admin |
| `POST /kids/signals/{signalId}/decision` | `DecideKidsSignal` | `decision: confirm \| reject` → tarefa/decisão | Admin; sinalização ainda corrente |
| `GET /me/progress` | `GetOwnProgress` | Totais próprios do dia; sem carga familiar | Todos |
| `GET /family/overview` | `GetFamilyOverview` | Progresso familiar e membros num snapshot; sem carga | Adulto |
| `GET /family/load` | `GetFamilyLoad` | Distribuição por membro e totais, sem ranking | Adulto |

Nas rotas familiares, `period` aceita `day` ou `week`; `referenceDate` é a data selecionada, validada pelo limite de consulta RN49. As rotas pessoais são sempre diárias e não aceitam `period`. `memberId` restringe a lista familiar a um membro da família do ator; `includeUnassigned` inclui ou exclui tarefas sem responsável. O servidor devolve intervalo nominal e efetivo nas consultas familiares. `GET /tasks/{id}` resolve criação fora do carrossel quando o ator pode consultar aquela tarefa; isso não cria novo calendário de navegação. Cadastro/edição não bloqueiam passado, meses futuros ou datas anteriores à família.

O servidor não aceita perfil responsável, autor da conclusão ou escolha de atribuição no comando. O ator vem da sessão; a conclusão mantém responsáveis existentes ou atribui o ator adulto se não houver nenhum. Tarefa com ao menos um responsável Kids só aceita conclusão manual de Administrador; Membro recebe `403 ACTION_NOT_ALLOWED`. Se já estiver concluída, a transação não duplica créditos e responde `409 TASK_ALREADY_COMPLETED`; o cliente reconcilia silenciosamente consultando o estado canônico. Reabrir missão concluída remove recompensa aceita, participações e badges derivados no mesmo commit. Conclusão manual administrativa encerra a pendência Kids e preserva sinalização/foto para auditoria acessível apenas a Administradores. `signalId` é identidade de domínio que protege uma decisão contra outra sinalização mais recente, não versão geral de edição.

`SignalTask` exige ator com papel `kids` e revalida, na mesma transação, que o ator consta em `assigneeIds` e que a tarefa está `pending`; caso contrário responde `403 ACTION_NOT_ALLOWED` (ator não é Kids), `404 RESOURCE_NOT_FOUND` (tarefa indisponível, de outra família, ou da qual o Kids não é responsável — sem distinguir os casos) ou `409 TASK_NOT_PENDING` (tarefa já `awaitingConfirmation` ou `completed`). `photoMediaId`, quando enviado, é revalidado como `READY`, do titular e com `finalidade: taskSignal`, usando os mesmos códigos `PHOTO_MEDIA_NOT_READY`/`PHOTO_MEDIA_NOT_OWNED`/`PHOTO_MEDIA_PURPOSE_MISMATCH` de `UpdateOwnProfile`. Sucesso retorna `201 Created` com a tarefa canônica e a sinalização criada (`signal.id`, correspondente ao `signalId` usado por `DecideKidsSignal`). Para SPEC-012.

`CreateRoutine` e `UpdateFutureRoutine` usam `422 VALIDATION_FAILED` com `fieldErrors` estáveis: `FREQUENCY_DAYS_INVALID` para `frequencyDays` fora de 1/7/14/21/28, `START_DATE_INVALID` para `startDate` fora de `YYYY-MM-DD` e `ROUTINE_SOURCE_TASK_INVALID` quando `fromTaskId` não identifica uma ocorrência da rotina solicitada dentro da família do ator. Um `fromTaskId` de outra família é indisponível e responde `404`. Não existe `endDate` nesses comandos. `EditTask` rejeita com `422 VALIDATION_FAILED`/`SIGNAL_RESOLUTION_REQUIRED` qualquer gravação sobre tarefa `awaitingConfirmation` sem `signalResolution`, independentemente de quais campos mudaram. `resetToPending` transiciona a tarefa para `pending` e descarta a sinalização corrente; `keepAwaitingConfirmation` preserva o estado e a sinalização corrente com os dados editados. `DeleteTask` sobre tarefa `awaitingConfirmation` remove a sinalização corrente junto da tarefa, sem gerar `CONFIRMED`/`REJECTED`.

`TaskMutationResult` contém `task` e `affectedResources` com IDs/tipos e períodos a invalidar. `familyOverview`, progresso pessoal, fila Kids, missão, badges e relatório corrente são recarregados quando afetados. Recursos sem permissão não têm dados privados devolvidos; pode-se invalidar uma área por tipo sem expor seus registros. Exclusões retornam ID removido, vínculos alterados e resumo dos registros preservados.

Consultas paginadas usam ordenação estável com ID como desempate e cursor opaco vinculado ao filtro. Página não determina totais. Em listas que mudam entre páginas, app recarrega ao receber invalidação; snapshot de relatório não depende dessas páginas. Limite de página é operacional, não limite de tarefas cadastráveis.

## 5. Missões, recompensa, relatório e reconhecimento

| Método e caminho | Caso de uso de aplicação | Campos / resposta | Permissão |
|---|---|---|---|
| `GET /missions` | `ListMissions` | Em andamento/concluídas, progresso e recompensa | Todos |
| `GET /missions/{missionId}` | `GetMissionDetail` | Título, `note`, vínculos individuais, participações e resgate; projeção Kids restrita | Todos da família |
| `GET /missions/task-options` | `GetMissionTaskOptions` | Ocorrências persistidas, filtros e paginação; sem selecionar rotina inteira | Admin |
| `POST /missions` | `CreateMission` | Título, `note` opcional (≤250 car.) e `taskIds` não vazio; sem prazo nem selo | Admin |
| `PATCH /missions/{missionId}` | `EditMission` | Título, `note` e/ou conjunto completo de `taskIds`; pode encerrar missão; rejeita `taskIds` vazio | Admin; em andamento |
| `GET /reward-items` | `ListRewardItems` | Catálogo predefinido + personalizado da família | Admin |
| `POST /reward-items` | `AddRewardItem` | Título da recompensa coletiva → item elegível | Admin |
| `POST /missions/{missionId}/reward-acceptance` | `AcceptMissionReward` | `rewardItemId` → aceite único com snapshot do item | Admin; concluída/sem resgate |
| `GET /reports/weekly-snapshot` | `GetWeeklyReportSnapshot` | Data/semana ou ciclo selecionado → JSON consistente, nunca PDF binário | Adulto |
| `GET /me/weekly-recognitions` | `ListOwnWeeklyRecognitions` | Lista de resultados finalizados próprios | Titular, inclusive Kids |
| `GET /me/weekly-recognitions/{recognitionId}` | `GetOwnWeeklyRecognition` | Pontos, contagem, empate, período/fuso preservados | Titular reconhecido |
| `PUT /me/push-device` | `RegisterPushDevice` | Token APNs/ambiente → dispositivo da sessão atual | Sessão ativa |
| `POST /me/weekly-recognitions/{recognitionId}/opening` | `RecordRecognitionOpening` | Registra primeira abertura de forma monotônica | Titular; não comprova leitura/envio |

Registrar rota estática `task-options` sem ambiguidade com `{missionId}`. Não há endpoints de sorteio, recusa de resultado da roleta, concessão manual de badge, edição de missão concluída ou envio de WhatsApp. Ausência de endpoints de editar/excluir item de recompensa respeita o escopo de consulta/adição do UC06. Nenhum endpoint permite um cliente comum disparar/finalizar apuração.

Resumo Kids de missão pode mostrar títulos/estados coletivos necessários ao UC14, mas não carga, PDF, dados administrativos nem mídia Kids de outro titular. Link para detalhe de tarefa permanece autorizado separadamente.

O snapshot de relatório inclui `period`, `timeZoneId`, `isTransition`, `generatedAt`, `isPartial`, totais e linhas. Datas/pontos do reconhecimento vêm do snapshot final, não de nova soma. Mensagem editável e abertura WhatsApp são locais; o backend não registra “enviado” por abrir o aplicativo externo.

## 6. Mídia e rotas operacionais

| Método e caminho | Contrato | Acesso |
|---|---|---|
| `POST /media` | Upload multipart, `purpose: profilePhoto \| taskSignal` → `mediaId`, estado e dimensões | Titular; `taskSignal` exige somente que o ator tenha papel Kids — o upload não recebe nem valida `taskId` |
| `GET /media/{mediaId}/content` | Streaming privado, tipo/tamanho corretos e sem cache compartilhado | Sessão ativa e leitura permitida pela finalidade/vínculo |
| `GET /health/live` | Estado mínimo do processo | Operação; sem detalhes internos |
| `GET /health/ready` | Prontidão da função API/worker | Infraestrutura autorizada |

Perfil recebe `photoMediaId`; sinalização recebe `photoMediaId` opcional. Ambos revalidam que a mídia está pronta, é do titular/da família e tem finalidade compatível. URL arbitrária no body não substitui esse contrato. Antes de vínculo, só quem enviou pode consultar sua mídia. R2 é privado e credenciais S3 nunca aparecem no retorno.

A revalidação de contexto de tarefa (estado `pending`, titularidade do responsável) acontece exclusivamente no vínculo via `SignalTask`, nunca no upload: `POST /media` com `purpose: taskSignal` não amarra a mídia a um `taskId` (SPEC-012). Reutilizar em outra sinalização uma mídia já vinculada não é um fluxo válido: cada sinalização recebe seu próprio `photoMediaId`, revalidado no momento do vínculo.

Página de Universal Link e `/.well-known/apple-app-site-association` são artefatos HTTP de integração, fora do prefixo da API. Não consomem convite nem autenticam o visitante. Página orienta loja e nova abertura do link após instalar, sem prometer deferred deep linking. URLs/domínio reais serão configuração de implantação.

## 7. Rastreabilidade UC para backend

Cada linha cobre um objetivo funcional completo, não apenas uma rota. RF/RN permanecem definidos na especificação vinculada; o catálogo mobile identifica TEL/MOD/UF. As referências abaixo destacam as garantias centrais.

| UC | Aplicação / módulos | Garantia principal | Base funcional |
|---|---|---|---|
| <a id="backend-uc01"></a>[UC01](../03-casos-de-uso.md#uc01) | `CreateFamily`, `ChangeFamilyTimeZone` / Access, Family, Recognition | Criador único, fuso selecionável e aplicação imediata/próximo ciclo | RF01/38/39/67; RN01/09/28/44/65 |
| <a id="backend-uc02"></a>[UC02](../03-casos-de-uso.md#uc02) | `CreateMember`, `UpdateMember`, `ChangeMemberRole`, `LeaveAdministration`, `RemoveMember`, `IssueMemberInvite` | Proteção do Criador, remoção seletiva, novas credenciais e revogação | RF02–06/40/41/54; RN01–10/45–47 |
| <a id="backend-uc03"></a>[UC03](../03-casos-de-uso.md#uc03) | `DecideKidsSignal` / Kids, Tasks, Missions | Primeira decisão válida, confirmação creditada a todos os responsáveis | RF25/26/55/56; RN22–26/54/55 |
| <a id="backend-uc04"></a>[UC04](../03-casos-de-uso.md#uc04) | `SignInWithApple` / Access | Prova validada; sessão única do Criador ou grant restrito | RF37/39; RN44; RNF15/16/22 |
| <a id="backend-uc05"></a>[UC05](../03-casos-de-uso.md#uc05) | `CreateMission`, `EditMission`, `CloseEligibleMissions` | Ao menos uma tarefa, participação e marcos na transação | RF28/29/31/32/50/58; RN35–40/50/51/58/64 |
| <a id="backend-uc06"></a>[UC06](../03-casos-de-uso.md#uc06) | `ListRewardItems`, `AddRewardItem` / Rewards | Predefinidas + família; só Admin adiciona | RF33/34; RN41/42 |
| <a id="backend-uc07"></a>[UC07](../03-casos-de-uso.md#uc07) | `CreateTask`, `EditTask`, `DeleteTask` / Tasks | Datas livres, título ≤60, observação ≤250, edição de concluída não protegida, resolução de sinalização pendente, auditoria e missão não vazia | RF07–10/15/16/27/58/59/69/70; RN11–13/17–20/50/58/59/66/67 |
| <a id="backend-uc08"></a>[UC08](../03-casos-de-uso.md#uc08) | `CreateRoutine`, `UpdateFutureRoutine`, `MaterializeRoutineOccurrences` | Frequências fixas, observação opcional, horizonte e origem estável; proteger passado/conquistas | RF13/14/70; RN14/16–18/67 |
| <a id="backend-uc09"></a>[UC09](../03-casos-de-uso.md#uc09) | `InspectInvite`, `JoinFamilyByInvite`, `RecoverInviteJoin`, `RefreshSession` | Consumo único, prova de instalação e troca sem remoção | RF42–46/54/68; RN09/10/45–47 |
| <a id="backend-uc10"></a>[UC10](../03-casos-de-uso.md#uc10) | `UpdateOwnProfile`, `GetOwnBadges`, `GetBadgeContributions` | Titularidade, câmera/galeria na UI e marcos por participação | RF48/62/65; RN63/64 |
| <a id="backend-uc11"></a>[UC11](../03-casos-de-uso.md#uc11) | `GetOwnTasks`, `GetFamilyTasks`, `GetMemberTasks`, `GetOwnProgress`, `GetFamilyOverview` | Consulta própria diária; Dia/Semana familiar adulta e carrossel; Kids só projeção própria | RF11/17/22/49/60/65/66; RN26/27/33/49/60/61 |
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

O documento OpenAPI 3.1 é gerado pelos schemas HTTP em `/docs/json`, e a interface interativa fica em `/docs`. Cada rota implementada mantém schema, segurança e respostas compatíveis com este contrato; a documentação executável não substitui esta fonte para comportamento, autorização ou regras de domínio.

## Histórico

| Versão | Data | Alteração |
|---|---|---|
| 1.13 | 2026-10-09 | Códigos públicos e garantias do ingresso por convite (inspeção, ingresso e recuperação), `Retry-After` em `429` e referência a BA-29–BA-34. Sem mudança de comportamento. Para SPEC-005 / SCRUM-32. |
| 1.12 | 2026-10-08 | `ListFamilyMembers` passa a definir cursor opaco, ordenação estável, páginas de até 20 perfis e `{items, nextCursor}`; cursor malformado recebe `422 VALIDATION_FAILED` com `CURSOR_INVALID`. Para SPEC-003 / SCRUM-27. |
| 1.11 | 2026-10-08 | Contrato passa a registrar a documentação OpenAPI 3.1 executável em `/docs/json` e a interface Swagger em `/docs`; sem alteração de comportamento dos endpoints. |
| 1.10 | 2026-10-08 | Formatos de resposta de `GetFamilySettings`, `PreviewFamilyTimeZoneChange` e `ChangeFamilyTimeZone`, e o código `TIME_ZONE_UNCHANGED`. Sem mudança de comportamento. Para SPEC-002 / SCRUM-21. |
| 1.9 | 2026-10-08 | `CreateFamily` passa a declarar `creatorName` e `creatorNickname` (nome e apelido do Criador, RF01/RF48), o ciclo semanal inicial na mesma transação e a conferência da prova da instalação contra o grant. Alinha o contrato ao que a SPEC-002 já aprovou; sem mudança de comportamento. Para SPEC-002 / SCRUM-18. |
| 1.8 | 2026-10-07 | `SignalTask` detalhado: ator Kids, revalidação de titularidade/estado (`403 ACTION_NOT_ALLOWED`, `404 RESOURCE_NOT_FOUND`, `409 TASK_NOT_PENDING`), resposta `201 Created` com `signal.id`. `POST /media` com `purpose: taskSignal` passa a ser aceito, validando somente o papel Kids no upload; contexto de tarefa é revalidado só no vínculo. Para SPEC-012. |
| 1.7 | 2026-10-07 | `CreateMission`/`EditMission` ganham `note` opcional (≤250 car.); `GetMissionDetail` expõe `note`; `EditMission` explicita rejeição de `taskIds` vazio. Para SPEC-014. |
| 1.5 | 2026-10-06 | Conclusão de tarefa com responsável Kids exige Administrador; `TASK_ALREADY_COMPLETED` reconcilia concorrência sem duplicar crédito; sinalização/foto pendente é auditável só por Admin. Para SPEC-010. |
| 1.4 | 2026-10-06 | Rotas pessoais de UC11 ficam diárias; rotas familiares adultas usam `period`, `memberId` e `includeUnassigned`; overview não inclui carga nesta entrega. Para SPEC-009. |
| 1.3 | 2026-10-06 | Contratos de rotina passam a aceitar `note`, explicitam a ausência de `endDate`, o alcance inclusivo de `fromTaskId` e os erros `FREQUENCY_DAYS_INVALID`, `START_DATE_INVALID` e `ROUTINE_SOURCE_TASK_INVALID`. Para SPEC-008. |
| 1.2 | 2026-10-06 | `CreateTask`/`EditTask` ganham `note` opcional (≤250 car.); `EditTask` ganha `signalResolution` obrigatório sobre tarefa `awaitingConfirmation`; `DeleteTask` remove a sinalização corrente. Para SPEC-007. |
| 1.1 | 2026-10-06 | `SPEC-001`: `SessionResult` e `GetCurrentSession` passam a expor `isFamilyCreator`, necessário para o cliente aplicar as proteções do Criador. |
| 1.0 | 2026-10-05 | Contratos `/v1`, autenticação, projeções, erros, cobertura UC01–UC19 e RNF01–27. |
