# Backend — contratos de API e rastreabilidade

**Versão:** 1.2 · **Base funcional:** 1.7 · **Arquitetura backend:** 1.0\
**Data:** 2026-10-06\
**Situação:** contrato arquitetural para detalhamento OpenAPI na implementação

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
| `POST /families` | `CreateFamily` | Grant, `name`, `timeZoneId` → família, Criador e sessão | Grant restrito à criação |
| `POST /access/invites/inspect` | `InspectInvite` | Token → disponibilidade e contexto mínimo para ingresso, sem senha/dados privados | Posse do token e limites de tentativas |
| `POST /access/invite-joins` | `JoinFamilyByInvite` | Token, senha, provas de instalação/tentativa; sessão anterior opcional e troca confirmada → sessão nova | Convite válido; antiga só é encerrada com sucesso |
| `POST /access/invite-joins/recover` | `RecoverInviteJoin` | `attemptId`, segredo da tentativa e prova original → credenciais daquele ingresso | Janela de dez minutos e sessão ainda ativa |
| `POST /access/refresh` | `RefreshSession` | Refresh + prova da instalação → novo access token | Sessão ativa e perfil ativo |
| `GET /me/session` | `GetCurrentSession` | Perfil, família, papel, flag `isFamilyCreator`, capacidades e IDs; nunca hashes | Sessão ativa |
| `DELETE /me/session` | `RevokeOwnSession` | Revoga sessão e dispositivo push; sem remover membro | Sessão ativa; contrato técnico de encerramento |

`creationGrant` não cria um quarto perfil. Seu prazo técnico não altera a ausência de expiração temporal de convite/refresh. Para criação concorrente, associação única à identidade Apple impede segunda família; retomar Apple permite descobrir a família criada após resposta perdida.

`SessionResult` contém `sessionId`, `memberId`, `familyId`, `role`, `isFamilyCreator`, `accessToken`, `accessTokenExpiresAt` e `refreshToken` no ingresso/recuperação. `GetCurrentSession` devolve `memberId`, `familyId`, `role` e `isFamilyCreator`, sem credenciais. Refresh não precisa devolver novamente o segredo estável.

Troca confirmada não é endpoint para transferir membro. Uma sessão anterior de outra família pode ser encerrada por seu próprio titular como parte da troca, sem conceder acesso cruzado aos dados. Falha antes do commit preserva ambas as identidades; commit com resposta perdida exige recuperação, conforme a arquitetura.

## 3. Família, membros e perfil

| Método e caminho | Caso de uso de aplicação | Campos / resposta | Permissão |
|---|---|---|---|
| `GET /family/settings` | `GetFamilySettings` | Fuso vigente, mudança programada e limites do ciclo | Admin |
| `POST /family/time-zone-changes/preview` | `PreviewFamilyTimeZoneChange` | `timeZoneId`, `application` → limites estimados e informativo | Admin; sem gravação |
| `POST /family/time-zone-changes` | `ChangeFamilyTimeZone` | `timeZoneId`, `application: immediate \| nextCycle` → configuração confirmada | Admin; revalidar limites no commit |
| `GET /family/members` | `ListFamilyMembers` | Projeção familiar paginada | Adulto |
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
| `GET /me/tasks` | `GetOwnTasks` | `period`, `referenceDate`, cursor → tarefas próprias e período | Todos |
| `GET /family/tasks` | `GetFamilyTasks` | Período, membro opcional, sem responsáveis opcional, cursor | Adulto |
| `GET /family/members/{memberId}/tasks` | `GetMemberTasks` | Período da origem e cursor | Adulto |
| `GET /tasks/{taskId}` | `GetTaskDetail` | Estado atual, origem, capacidades e detalhes autorizados | Adulto; Kids apenas responsável |
| `POST /tasks` | `CreateTask` | `title` (1–60 car.), `weight`, `scheduledDate`, `assigneeIds`, `note` (opcional, ≤250 car.) → tarefa única | Adulto |
| `PATCH /tasks/{taskId}` | `EditTask` | Campos editáveis de uma ocorrência, incluindo data e `note`; `signalResolution` (`resetToPending` \| `keepAwaitingConfirmation`) obrigatório quando o estado atual é `awaitingConfirmation` | Adulto; respeitar proteção |
| `DELETE /tasks/{taskId}` | `DeleteTask` | Exclusão individual e vínculos afetados; remove sinalização Kids corrente sem registrar decisão | Adulto; não concluída/não protegida |
| `POST /tasks/{taskId}/completion` | `CompleteTask` | `assignment: keepAssignees \| takeOver` → estado canônico | Adulto |
| `POST /tasks/{taskId}/reopening` | `ReopenTask` | Comando explícito → conclusão desfeita e períodos afetados | Admin; missão em andamento, nenhuma concluída |
| `POST /routines` | `CreateRoutine` | Título, peso, responsáveis, `startDate`, `frequencyDays` → rotina e materialização | Adulto |
| `GET /routines/{routineId}` | `GetRoutine` | Configuração, versão vigente e progresso de materialização | Adulto |
| `PATCH /routines/{routineId}` | `UpdateFutureRoutine` | `fromTaskId`, configuração/data inicial/frequência; somente futuras elegíveis | Adulto |
| `POST /routines/{routineId}/future-task-deletions` | `DeleteFutureRoutineTasks` | `fromTaskId` → alcance, preservadas e fim de geração | Adulto |
| `POST /tasks/{taskId}/signals` | `SignalTask` | `photoMediaId` opcional → sinalização corrente | Kids responsável e tarefa pendente |
| `GET /kids/signals` | `GetKidsReviewQueue` | Sinalizações pendentes paginadas | Admin |
| `GET /kids/signals/{signalId}` | `GetKidsSignal` | Tarefa, autor, foto opcional e estado da sinalização | Admin |
| `POST /kids/signals/{signalId}/decision` | `DecideKidsSignal` | `decision: confirm \| reject` → tarefa/decisão | Admin; sinalização ainda corrente |
| `GET /me/progress` | `GetOwnProgress` | Totais do período; sem carga familiar | Todos |
| `GET /family/overview` | `GetFamilyOverview` | Carga/progresso/membros num snapshot | Adulto |
| `GET /family/load` | `GetFamilyLoad` | Distribuição por membro e totais, sem ranking | Adulto |

`period` aceita `day` ou `week`; `referenceDate` é a data selecionada, validada pelo limite de consulta RN49. O servidor devolve intervalo nominal e efetivo. `GET /tasks/{id}` resolve criação fora do carrossel quando o ator pode consultar aquela tarefa; isso não cria novo calendário de navegação. Cadastro/edição não bloqueiam passado, meses futuros ou datas anteriores à família.

O servidor não aceita o perfil responsável como autor da conclusão. O ator vem da sessão; manter/assumir é uma decisão explícita do comando. `signalId` é identidade de domínio que protege uma decisão contra outra sinalização mais recente, não versão geral de edição.

`EditTask` rejeita com `422 VALIDATION_FAILED`/`SIGNAL_RESOLUTION_REQUIRED` qualquer gravação sobre tarefa `awaitingConfirmation` sem `signalResolution`, independentemente de quais campos mudaram. `resetToPending` transiciona a tarefa para `pending` e descarta a sinalização corrente; `keepAwaitingConfirmation` preserva o estado e a sinalização corrente com os dados editados. `DeleteTask` sobre tarefa `awaitingConfirmation` remove a sinalização corrente junto da tarefa, sem gerar `CONFIRMED`/`REJECTED`.

`TaskMutationResult` contém `task` e `affectedResources` com IDs/tipos e períodos a invalidar. `familyOverview`, progresso pessoal, fila Kids, missão, badges e relatório corrente são recarregados quando afetados. Recursos sem permissão não têm dados privados devolvidos; pode-se invalidar uma área por tipo sem expor seus registros. Exclusões retornam ID removido, vínculos alterados e resumo dos registros preservados.

Consultas paginadas usam ordenação estável com ID como desempate e cursor opaco vinculado ao filtro. Página não determina totais. Em listas que mudam entre páginas, app recarrega ao receber invalidação; snapshot de relatório não depende dessas páginas. Limite de página é operacional, não limite de tarefas cadastráveis.

## 5. Missões, recompensa, relatório e reconhecimento

| Método e caminho | Caso de uso de aplicação | Campos / resposta | Permissão |
|---|---|---|---|
| `GET /missions` | `ListMissions` | Em andamento/concluídas, progresso e recompensa | Todos |
| `GET /missions/{missionId}` | `GetMissionDetail` | Vínculos individuais, participações e resgate; projeção Kids restrita | Todos da família |
| `GET /missions/task-options` | `GetMissionTaskOptions` | Ocorrências persistidas, filtros e paginação; sem selecionar rotina inteira | Admin |
| `POST /missions` | `CreateMission` | Título e `taskIds` não vazio; sem prazo nem selo | Admin |
| `PATCH /missions/{missionId}` | `EditMission` | Título e/ou conjunto completo de `taskIds`; pode encerrar missão | Admin; em andamento |
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
| `POST /media` | Upload multipart, `purpose: profilePhoto \| taskSignal` → `mediaId`, estado e dimensões | Titular; `taskSignal` exige Kids responsável e contexto de tarefa válido |
| `GET /media/{mediaId}/content` | Streaming privado, tipo/tamanho corretos e sem cache compartilhado | Sessão ativa e leitura permitida pela finalidade/vínculo |
| `GET /health/live` | Estado mínimo do processo | Operação; sem detalhes internos |
| `GET /health/ready` | Prontidão da função API/worker | Infraestrutura autorizada |

Perfil recebe `photoMediaId`; sinalização recebe `photoMediaId` opcional. Ambos revalidam que a mídia está pronta, é do titular/da família e tem finalidade compatível. URL arbitrária no body não substitui esse contrato. Antes de vínculo, só quem enviou pode consultar sua mídia. R2 é privado e credenciais S3 nunca aparecem no retorno.

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
| <a id="backend-uc08"></a>[UC08](../03-casos-de-uso.md#uc08) | `CreateRoutine`, `UpdateFutureRoutine`, `MaterializeRoutineOccurrences` | Frequências fixas, horizonte e origem estável; proteger passado/conquistas | RF13/14; RN14/16–18 |
| <a id="backend-uc09"></a>[UC09](../03-casos-de-uso.md#uc09) | `InspectInvite`, `JoinFamilyByInvite`, `RecoverInviteJoin`, `RefreshSession` | Consumo único, prova de instalação e troca sem remoção | RF42–46/54/68; RN09/10/45–47 |
| <a id="backend-uc10"></a>[UC10](../03-casos-de-uso.md#uc10) | `UpdateOwnProfile`, `GetOwnBadges`, `GetBadgeContributions` | Titularidade, câmera/galeria na UI e marcos por participação | RF48/62/65; RN63/64 |
| <a id="backend-uc11"></a>[UC11](../03-casos-de-uso.md#uc11) | `GetOwnTasks`, `GetFamilyTasks`, `GetMemberTasks`, `GetOwnProgress`, `GetFamilyOverview` | Dia/Semana e carrossel; Kids só projeção permitida | RF11/17/22/49/60/65/66; RN26/27/33/49/60/61 |
| <a id="backend-uc12"></a>[UC12](../03-casos-de-uso.md#uc12) | `CompleteTask` / Tasks, Kids, Missions | Manter/assumir, crédito integral, uma conclusão vigente | RF12/47/56; RN21/22/30/48/55/56 |
| <a id="backend-uc13"></a>[UC13](../03-casos-de-uso.md#uc13) | `GetFamilyLoad` / Insights | Carga pelo instante da conclusão, sem duplicação por joins | RF18–21/56/57/66; RN28/30/31/33/34/57/61 |
| <a id="backend-uc14"></a>[UC14](../03-casos-de-uso.md#uc14) | `ListMissions`, `GetMissionDetail` / Missions | Tarefas distintas e recompensa preservada; projeção Kids | RF30/31/36/58/62/65; RN35–39/43/51–53/58/64 |
| <a id="backend-uc15"></a>[UC15](../03-casos-de-uso.md#uc15) | `UploadMedia`, `SignalTask` / Media, Kids | Foto opcional; sinalizar não conclui nem credita | RF23/24/55/56; RN21–26/54/55 |
| <a id="backend-uc16"></a>[UC16](../03-casos-de-uso.md#uc16) | `AcceptMissionReward` / Rewards, Missions | Sorteio local, um aceite remoto | RF35/51–53; RN42/43/52/53; RNF23 |
| <a id="backend-uc17"></a>[UC17](../03-casos-de-uso.md#uc17) | `ReopenTask` / Tasks, Missions | Admin, missão em andamento, nenhuma concluída, retirar crédito uma vez | RF57–59; RN55/57–59 |
| <a id="backend-uc18"></a>[UC18](../03-casos-de-uso.md#uc18) | `GetWeeklyReportSnapshot` / Reports, Insights | Snapshot consistente adulto para PDF local | RF61; RN62; RNF26/27 |
| <a id="backend-uc19"></a>[UC19](../03-casos-de-uso.md#uc19) | `FinalizeWeeklyHighlight`, `GetOwnWeeklyRecognition`, `DeliverRecognitionNotification` | Ciclo encerrado, positivos/empates, resultado preservado e outbox | RF63/64; RN28/30/65; RNF26/27 |

## 8. Cobertura não funcional

| RNF | Obrigação no backend |
|---|---|
| RNF01–05 | Estados/erros compreensíveis e projeções acessíveis; UI final continua responsabilidade mobile |
| RNF06/07 | Escopo por família, papel, titularidade, whitelist de campos e revalidação no lock |
| RNF08 | TLS e credenciais privadas, incluindo conexão com banco |
| RNF09–11/25 | Transações, unicidade, histórico e preservação de conquistas |
| RNF12/13 | Resultado incerto explícito, limites de processamento e preparação consultável |
| RNF14 | Dependências internas e contratos que preservam módulos |
| RNF15/16 | Validação oficial Apple e proteção da identidade |
| RNF17–21 | Segredos imprevisíveis/protegidos, limitação de tentativas e consumo único |
| RNF22 | Sessão única revogável, prova de instalação, refresh estável e recuperação restrita |
| RNF23 | Aceite de recompensa consistente sob concorrência |
| RNF24 | R2 privado, leitura autorizada por finalidade e revogação |
| RNF26 | Snapshot para PDF, resultado semanal único e fila persistente |
| RNF27 | Perfil por titularidade, PDF adulto e compartilhamento explícito no cliente |

O OpenAPI futuro deve materializar schemas e exemplos de sucesso/erro dessas rotas. Esta versão define fronteiras e semântica, sem alegar que existe especificação executável, SDK gerado ou endpoint em funcionamento.

## Histórico

| Versão | Data | Alteração |
|---|---|---|
| 1.2 | 2026-10-06 | `CreateTask`/`EditTask` ganham `note` opcional (≤250 car.); `EditTask` ganha `signalResolution` obrigatório sobre tarefa `awaitingConfirmation`; `DeleteTask` remove a sinalização corrente. Para SPEC-007. |
| 1.1 | 2026-10-06 | `SPEC-001`: `SessionResult` e `GetCurrentSession` passam a expor `isFamilyCreator`, necessário para o cliente aplicar as proteções do Criador. |
| 1.0 | 2026-10-05 | Contratos `/v1`, autenticação, projeções, erros, cobertura UC01–UC19 e RNF01–27. |
