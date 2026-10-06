# Catálogo de funcionalidades e rastreabilidade mobile

**Versão:** 1.5 · **Base funcional:** 1.9 · **Design:** 1.4\
**Data:** 2026-10-05 · **Situação:** especificação para implementação futura

[Arquitetura mobile](mobile-architecture.md) · [Decisões](mobile-decisions.md) · [Índice documental](../DOCUMENTACAO.md) · [Screen map](../design/screen-map.md) · [User flows](../design/user-flows.md)

## 1. Fronteiras das funcionalidades

Os nomes abaixo são nomes técnicos em inglês, não novos destinos na navegação. Cada funcionalidade possui as camadas necessárias descritas na arquitetura. Suas portas estão em Application e suas implementações remotas em Data.

| Funcionalidade | Responsabilidade e domínio | Portas principais | Relação com outras áreas |
|---|---|---|---|
| `Access` | Apple, entrada por convite, recuperação e identidade de sessão | `AccessRepository`, `AppleAuthenticating`, `SessionProviding` | Entrega contexto autenticado; não mantém formulário administrativo de membro |
| `Family` | Família, fuso, membros, papéis, modo Kids e convites administrativos | `FamilyRepository`, `MemberRepository`, `InviteRepository` | Compõe indicadores de `Insights` e consultas de `Tasks` na área Família |
| `Profile` | Edição pessoal e apresentação de conquistas | `OwnProfileRepository`, `ProfilePhotoUploading` | Consulta `BadgeAward` de `Missions`; não permite editar papel ou perfil de terceiros |
| `Tasks` | Tarefa individual, atribuição, consulta, conclusão, reabertura e exclusão | `TaskRepository` | Reutilizada nas listas pessoais/familiares e detalhes; efeitos em missões são remotos |
| `Routines` | Configuração recorrente e alcance de alterações futuras | `RoutineRepository` | Compartilha o formulário de tarefas; geração de ocorrências é do backend |
| `KidsParticipation` | Sinalização própria e avaliação administrativa | `KidsSignalRepository`, `TaskPhotoUploading` | Usa ID/estado de `Tasks`; não é uma segunda implementação de tarefa |
| `Insights` | Períodos, progresso e distribuição de carga | `InsightsRepository` | Fornece projeções para tarefas e Família; nenhuma aba de carga separada |
| `Missions` | Missões, vínculos individuais, badges e conquistas | `MissionRepository`, `BadgeRepository` | Consulta resgate de `Rewards`; concede badge apenas por operação remota válida |
| `Rewards` | Itens, sorteio e aceitação | `RewardRepository`, `RewardDrawing` | Resgate pertence à missão; não adiciona item diretamente à conquista |
| `Reports` | Obtenção de snapshot semanal e geração de PDF | `WeeklyReportRepository`, `PDFRendering`, `ReportFileStoring` | Consome valores de `Insights` no snapshot, sem fazer novas consultas ao renderizar |
| `Recognition` | Consulta do próprio destaque e preparação de compartilhamento | `RecognitionRepository`, `DeviceRegistrationRepository`, `HighlightSharing` | Apuração e envio push são remotos; não calcula ranking no dispositivo |

`GetFamilyOverviewUseCase` compõe membros e indicadores por interfaces, sem importar Data. Se a API disponibilizar um resumo familiar consistente, uma porta `FamilyOverviewRepository` pode encapsular essa consulta. Os indicadores devem declarar a mesma referência temporal; atualizações parciais não devem ser mostradas como um snapshot único confirmado.

As dependências cruzadas são restritas a contratos/projeções. `Routines` e `KidsParticipation` podem conhecer valores de `Tasks`; `Tasks` não depende de suas camadas de apresentação. `Reports` conhece as projeções de métricas, e não a ViewModel da tela Família. Compartilhamento de uma tela entre jornadas é resolvido por factories e contexto de origem.

## 2. Telas e arquivos de apresentação

Para cada par abaixo, os arquivos são `<View>.swift` e `<ViewModel>.swift`, dentro de `Features/<Feature>/Presentation/<Screen>/`. O nome do arquivo coincide com o tipo principal. As variantes Kids compartilham modelos e componentes apropriados, mas têm estado e capacidades próprios. A tabela cobre as **26 telas ativas**; os **2 IDs retirados** são indicados separadamente.

| ID | Feature | View | ViewModel | Responsabilidade/entrada |
|---|---|---|---|---|
| TEL-001 | `Access` | `EntryView` | `EntryViewModel` | Entrada Apple e orientação para convidados |
| TEL-002 | `Family` | `CreateFamilyView` | `CreateFamilyViewModel` | Criador autenticado sem família |
| TEL-003 | `Access` | `JoinInviteView` | `JoinInviteViewModel` | Validar link e efetivar ingresso com senha |
| TEL-004 | `Access` | `AccessRecoveryView` | `AccessRecoveryViewModel` | Orientar novo convite ou Apple; não envia solicitação |
| TEL-010 | `Tasks` | `PersonalTasksView` | `PersonalTasksViewModel` | Aba inicial adulta, tarefas e progresso próprios diários |
| TEL-011 | `Tasks` | `FamilyTasksView` | `FamilyTasksViewModel` | Consulta familiar adulta por Dia/Semana, incluindo sem responsável |
| TEL-012 | `Tasks` | `TaskDetailView` | `TaskDetailViewModel` | Detalhe e ações adultas conforme estado |
| TEL-013 | `Tasks` + `Routines` | `TaskEditorView` | `TaskEditorViewModel` | Rascunho único; salva tarefa ou configuração recorrente pelo caso de uso adequado |
| TEL-015 | `KidsParticipation` | `KidsReviewQueueView` | `KidsReviewQueueViewModel` | Fila exclusiva de Administrador |
| TEL-016 | `KidsParticipation` | `KidsSignalReviewView` | `KidsSignalReviewViewModel` | Foto opcional, confirmar ou recusar |
| TEL-020 | `Missions` | `MissionsView` | `MissionsViewModel` | Aba independente adulta/Kids; lista em andamento e concluída |
| TEL-021 | `Missions` | `MissionDetailView` | `MissionDetailViewModel` | Progresso, participações e recompensa; detalhe operacional de tarefa limitado por perfil |
| TEL-022 | `Missions` | `MissionEditorView` | `MissionEditorViewModel` | Administrador, ao menos uma tarefa e nenhum prazo |
| TEL-023 | `Rewards` | `RewardItemsView` | `RewardItemsViewModel` | Catálogo e itens personalizados, com origem preservada |
| TEL-024 | `Rewards` | `RewardWheelView` | `RewardWheelViewModel` | Resultado, novo sorteio, aceitação ou saída sem resgate |
| TEL-030 | `Profile` | `ProfileView` | `ProfileViewModel` | Aba adulta ou avatar Kids; foto, apelido e badges; saída do papel Admin quando permitida |
| TEL-032 | `Family` | `MemberDetailView` | `MemberDetailViewModel` | Consulta adulta Dia/Semana das tarefas do membro; gestão só Admin |
| TEL-033 | `Family` | `MemberEditorView` | `MemberEditorViewModel` | Criar/editar dados administrativos, papel e modo |
| TEL-034 | `Family` | `MemberInviteView` | `MemberInviteViewModel` | Emitir novo link e senha, revogando convites e sessão anteriores |
| TEL-040 | `Tasks` | `KidsTasksView` | `KidsTasksViewModel` | Aba inicial Kids; tarefas/progresso próprios diários |
| TEL-041 | `Tasks` | `KidsTaskDetailView` | `KidsTaskDetailViewModel` | Detalhe somente de tarefa própria; abre sinalização |
| TEL-050 | `Family` | `FamilyOverviewView` | `FamilyOverviewViewModel` | Progresso familiar Dia/Semana, membros, PDF e ações permitidas; carga na SPEC-018 |
| TEL-051 | `Reports` | `WeeklyReportView` | `WeeklyReportViewModel` | Semana, geração, visualização e exportação |
| TEL-052 | `Recognition` | `WeeklyRecognitionView` | `WeeklyRecognitionViewModel` | Reconhecimento próprio; texto editável e compartilhamento |
| TEL-053 | `Family` | `FamilySettingsView` | `FamilySettingsViewModel` | Admin configura fuso e momento de aplicação |
| TEL-054 | `Profile` | `BadgeDetailView` | `BadgeDetailViewModel` | Titular consulta marco e missões contribuintes |

**TEL-014 e TEL-031:** IDs reservados, sem View, ViewModel ou rota. Carga e lista de membros estão integradas à TEL-050. Uma ViewModel não é obrigatória para uma tela que se revele estritamente estática na implementação; TEL-004 pode ser somente View e saídas de navegação, sem classe vazia para cumprir tabela.

Telas adultas iniciais usam `AdultTab` com `personalTasks`, `profile`, `missions` e `family`. Kids usam `KidsTab` com `personalTasks` e `missions`. Perfil e destaque Kids são destinos dentro de um fluxo, sem terceira aba. A posição visual final das abas adultas deve seguir o detalhamento de design.

## 3. Modais e propriedade do rascunho

Modais não se tornam automaticamente novos casos de uso ou novas ViewModels. Seletores editam um rascunho local e devolvem valores à origem. Confirmar um seletor não grava a tarefa ou missão. Para permitir cancelamento, bindings devem apontar para o rascunho do modal, e não alterar imediatamente o estado confirmado.

| ID | Arquivo de View | Dono do estado / ação |
|---|---|---|
| MOD-001 | `AssigneePickerView.swift` | Rascunho de `TaskEditorViewModel`; nenhum, um ou vários responsáveis |
| MOD-002 | `RecurrencePickerView.swift` | Rascunho de `TaskEditorViewModel`; única ou intervalos 1/7/14/21/28, sem data final |
| MOD-003 | `ChangeScopeView.swift` | `TaskEditorViewModel` ou `TaskDetailViewModel`; “selecionada e futuras” inclui a origem, com registros preservados |
| MOD-004 | `TaskCompletionConfirmationView.swift` | `TaskDetailViewModel`; mostra beneficiários e confirma manter/assumir |
| MOD-005 | `TaskDeletionConfirmationView.swift` | `TaskDetailViewModel`; confirma alcance autorizado |
| MOD-006 | `TaskReopeningConfirmationView.swift` | `TaskDetailViewModel`; efeitos sobre todos os responsáveis e missões |
| MOD-007 | `MissionTaskPickerView.swift` | Rascunho de `MissionEditorViewModel`; IDs individuais, sem selecionar rotina inteira |
| MOD-008 | `RewardItemEditorView.swift` | `RewardItemEditorViewModel`; gravação independente do resgate |
| MOD-009 | `OwnProfileEditorView.swift` | `OwnProfileEditorViewModel`; foto/apelido do titular e upload |
| MOD-010 | `MemberChangeConfirmationView.swift` | Fluxo chamador: `ProfileViewModel`, `MemberDetailViewModel` ou `MemberEditorViewModel` |
| MOD-011 | `KidsSignalComposerView.swift` | `KidsSignalComposerViewModel`; captura, revisão, upload e sinalização |
| MOD-012 | `TimeZoneChangeConfirmationView.swift` | `FamilySettingsViewModel`; informativo e aplicação imediata/próximo ciclo |
| MOD-013 | `AccessSwitchConfirmationView.swift` | `JoinInviteViewModel`; confirma troca; mantém sessão antiga até ingresso válido |
| MOD-014 | `SignalResolutionView.swift` | `TaskEditorViewModel`/`TaskDetailViewModel`; exigido ao salvar edição sobre tarefa Aguardando confirmação: retornar a Pendente ou manter Aguardando confirmação |

`SheetRoute` e `ConfirmationRoute` pertencem à apresentação, com um destino ativo por fluxo. Fechar um modal restaura sua origem. Confirmar reabertura e depois cancelar exclusão não desfaz a reabertura já salva (UF-08).

## 4. Casos de uso mobile e rastreabilidade funcional

`UC` representa o objetivo funcional, não necessariamente um único tipo Swift. Os tipos abaixo ficam em `Application/UseCases/`, em arquivos com o mesmo nome e extensão `.swift`. Os links de UC levam à relação completa de RN/RF/RNF na base funcional; referências desta tabela destacam os contratos centrais, sem substituir aquela lista.

| UC | Casos de uso mobile propostos | TEL/MOD principais | UF | Referências centrais |
|---|---|---|---|---|
| [UC01](../03-casos-de-uso.md#uc01) | `CreateFamilyUseCase`, `ResolveCreatorFamilyUseCase`, `GetFamilySettingsUseCase`, `ChangeFamilyTimeZoneUseCase` | TEL-002/053; MOD-012 | [UF-01](../design/user-flows.md#uf-01), [UF-16](../design/user-flows.md#uf-16) | RF01/38/39/67; RN01/09/28/44/65 |
| [UC02](../03-casos-de-uso.md#uc02) | `CreateMemberUseCase`, `UpdateMemberUseCase`, `ChangeMemberRoleUseCase`, `SetKidsModeUseCase`, `LeaveAdministrationUseCase`, `RemoveMemberUseCase`, `GenerateMemberInviteUseCase`, `ResendMemberInviteUseCase` | TEL-050/030/032/033/034; MOD-010 | [UF-02](../design/user-flows.md#uf-02), [UF-03](../design/user-flows.md#uf-03), [UF-12](../design/user-flows.md#uf-12) | RF02–06/40/41/54; RN01–10/45–47 |
| [UC03](../03-casos-de-uso.md#uc03) | `GetKidsReviewQueueUseCase`, `GetKidsSignalUseCase`, `ConfirmKidsSignalUseCase`, `RejectKidsSignalUseCase` | TEL-015/016 | [UF-07](../design/user-flows.md#uf-07) | RF25/26/55/56; RN22–26/54/55 |
| [UC04](../03-casos-de-uso.md#uc04) | `SignInWithAppleUseCase` | TEL-001 | [UF-01](../design/user-flows.md#uf-01), [UF-03](../design/user-flows.md#uf-03) | RF37/39; RN44; RNF15/16 |
| [UC05](../03-casos-de-uso.md#uc05) | `CreateMissionUseCase`, `UpdateMissionUseCase`, `GetMissionTaskOptionsUseCase` | TEL-020/021/022; MOD-007 | [UF-10](../design/user-flows.md#uf-10) | RF28/29/31/32/50/58; RN35–40/50/51/58/64 |
| [UC06](../03-casos-de-uso.md#uc06) | `GetRewardItemsUseCase`, `AddRewardItemUseCase` | TEL-023; MOD-008 | [UF-11](../design/user-flows.md#uf-11) | RF33/34; RN41/42 |
| [UC07](../03-casos-de-uso.md#uc07) | `CreateTaskUseCase`, `UpdateTaskUseCase`, `DeleteTaskUseCase`, `GetTaskDetailUseCase` | TEL-011/012/013; MOD-001/003/005/014 | [UF-05](../design/user-flows.md#uf-05), [UF-08](../design/user-flows.md#uf-08) | RF07–10/15/16/27/58/59/69/70; RN11–13/17–20/50/58/59/66/67 |
| [UC08](../03-casos-de-uso.md#uc08) | `CreateRoutineUseCase`, `UpdateRoutineUseCase`, `DeleteFutureTasksUseCase` | TEL-013; MOD-002/003 | [UF-05](../design/user-flows.md#uf-05) | RF13/14/70; RN14/16–18/67 |
| [UC09](../03-casos-de-uso.md#uc09) | `InspectInviteUseCase`, `JoinInviteUseCase`, `RestoreSessionUseCase` | TEL-003/004; MOD-013 | [UF-02](../design/user-flows.md#uf-02), [UF-03](../design/user-flows.md#uf-03) | RF42–46/54/68; RN09/10/45–47; RNF17–22 |
| [UC10](../03-casos-de-uso.md#uc10) | `GetOwnProfileUseCase`, `UpdateOwnProfileUseCase`, `GetOwnBadgesUseCase`, `GetBadgeContributionsUseCase` | TEL-030/054; MOD-009 | [UF-13](../design/user-flows.md#uf-13) | RF48/62/65; RN63/64; RNF27 |
| [UC11](../03-casos-de-uso.md#uc11) | `GetPersonalTasksUseCase`, `GetFamilyTasksUseCase`, `GetMemberTasksUseCase`, `GetPersonalProgressUseCase`, `GetFamilyOverviewUseCase` | TEL-010/011/032/040/050 | [UF-04](../design/user-flows.md#uf-04) | RF11/17/22/49/60/65/66; RN26/27/33/49/60/61 |
| [UC12](../03-casos-de-uso.md#uc12) | `CompleteTaskUseCase` | TEL-012; MOD-004 | [UF-06](../design/user-flows.md#uf-06) | RF12/47/56; RN21/22/30/48/55/56 |
| [UC13](../03-casos-de-uso.md#uc13) | `GetFamilyLoadUseCase` | TEL-050 | [UF-09](../design/user-flows.md#uf-09) | RF18–21/56/57/66; RN28/30/31/33/34/57/61 |
| [UC14](../03-casos-de-uso.md#uc14) | `GetMissionsUseCase`, `GetMissionDetailUseCase` | TEL-020/021 | [UF-10](../design/user-flows.md#uf-10) | RF30–32/36/58/62/65; RN35–39/43/51–53/58/64 |
| [UC15](../03-casos-de-uso.md#uc15) | `UploadTaskPhotoUseCase`, `SignalTaskUseCase` | TEL-041; MOD-011 | [UF-07](../design/user-flows.md#uf-07) | RF23/24/55/56; RN21–26/54/55 |
| [UC16](../03-casos-de-uso.md#uc16) | `DrawRewardUseCase`, `AcceptRewardUseCase` | TEL-024 | [UF-11](../design/user-flows.md#uf-11) | RF35/51–53; RN42/43/52/53; RNF23 |
| [UC17](../03-casos-de-uso.md#uc17) | `ReopenTaskUseCase` | TEL-012; MOD-006 | [UF-08](../design/user-flows.md#uf-08) | RF57–59; RN55/57–59; RNF25 |
| [UC18](../03-casos-de-uso.md#uc18) | `GetWeeklyReportUseCase`, `ExportWeeklyReportUseCase` | TEL-051 | [UF-14](../design/user-flows.md#uf-14) | RF61; RN62; RNF26/27 |
| [UC19](../03-casos-de-uso.md#uc19) | `GetOwnWeeklyRecognitionUseCase`, `PrepareHighlightShareUseCase`, `RegisterNotificationDeviceUseCase` | TEL-052 | [UF-15](../design/user-flows.md#uf-15) | RF63/64; RN28/30/65; RNF26/27 |

`UpdateTaskUseCase` inclui alteração de responsáveis, sem precisar de um caso de uso para cada campo. Alcance futuro encaminha para o contrato de rotina correspondente; não executa um loop de alterações individuais no iPhone. `DeleteFutureTasksUseCase` expressa exclusão a partir da ocorrência escolhida, preservando registros protegidos conforme UC07.

`RestoreSessionUseCase` é interno ao ciclo de vida, não uma nova tela. Compartilhamento de arquivo e abertura de câmera são integrações de apresentação por adaptadores; não precisam de um UC funcional novo. “Gerenciar” não autoriza operações adicionais: o catálogo de recompensas tem consulta/adição, e não CRUD completo inventado.

Os contratos remotos e sua cobertura por UC estão no [catálogo backend](backend-contracts.md). Nomes de casos de uso mobile e servidor podem diferir porque representam papéis distintos; o mapeamento é pelo objetivo UC e pelo contrato HTTP, não pelo nome de uma classe.

## 5. Responsabilidades que exigem backend

| Operação | Mobile | Garantia exigida do servidor |
|---|---|---|
| Criar família | Coletar nome/fuso e enviar intenção autenticada | Um vínculo por Criador; criação consistente com perfil protegido |
| Ingressar/recuperar | Link, senha, confirmação e armazenamento seguro da sessão | Validar prova, consumir convite uma vez, manter mesmo perfil e tratar concorrência |
| Mudar/remover membro | Confirmar impactos e atualizar navegação | Proteção do Criador, regras Kids/Admin, revogação e preservação histórica |
| Tarefa/rotina | Data livre, alcance e comando; consultar após resposta incerta | Última edição válida persistida vence; gerar sem duplicar, auditar correções, proteger conquistas |
| Concluir/confirmar/recusar | Enviar intenção e reconciliar estado | Primeira decisão válida, autor/beneficiários corretos, efeitos consistentes em missões/badges |
| Reabrir/excluir | Explicar impactos e aguardar confirmação | Validar missões atuais, retirar crédito uma vez e impedir missão vazia |
| Gerenciar missão | Selecionar tarefas individuais | Concluir se todas concluídas, registrar participações e conceder marcos sem duplicar |
| Sortear/aceitar | Sortear localmente, animar, permitir novo sorteio e enviar aceite | Item elegível, permissão atual e uma única recompensa aceita |
| Indicadores/PDF | Selecionar período, formatar e renderizar | Projeções completas/coerentes com calendário e leitura consistente do relatório |
| Reconhecimento | Consultar o próprio resultado e compartilhar | Job às 00:00 locais de segunda, todos os empatados positivos, resultado preservado e fila persistente |

## 6. Cobertura não funcional

| Grupo | RNF | Evidência exigida na futura implementação |
|---|---|---|
| Experiência e acessibilidade | RNF01–05 | Estados por tela, linguagem Kids, leitura de status sem cores, métricas compreensíveis e gráficos acessíveis |
| Isolamento e autorização | RNF06/07 | Testes negativos de família, papel, titularidade e deep links; mesma restrição no servidor |
| Transporte | RNF08 | HTTPS e configuração de rede sem exceções inseguras de produção |
| Integridade | RNF09–11/23/25 | Concorrência entre dispositivos e operações atômicas; ausência de crédito/resgate/decisão duplicados |
| Falhas e responsividade | RNF12/13 | Estado confirmado versus incerto; cancelamento e trabalho pesado sem bloquear UI |
| Separação arquitetural | RNF14 | Imports e dependências por camada; ViewModel sem DTO/rede e Domain sem frameworks de interface |
| Apple e credenciais | RNF15–17 | Validação Apple remota, Keychain e ausência de credenciais em logs/persistência inadequada |
| Ingresso e sessões | RNF18–22 | Proteção remota contra tentativas, consumo único, recuperação e revogação efetiva |
| Fotos | RNF24 | Leitura privada, revogação e limpeza de temporários; permissões por finalidade |
| Relatórios e reconhecimento | RNF26 | Snapshot conciliado, arquivo completo, resultado recuperável e deduplicação lógica por pessoa/semana |
| Perfil e exportação | RNF27 | Administrador não edita apelido alheio; arquivos/textos mínimos e compartilhamento explícito |

## 7. Convenções de nomenclatura

- Tipos e arquivos: `PascalCase`, como `FamilyOverviewViewModel.swift`; funções, propriedades e cases: `camelCase`, como `loadFamilyOverview()` e `awaitingConfirmation`.
- Ports expressam capacidade: `TaskRepository`, `PDFRendering`, `HighlightSharing`; implementações explicitam mecanismo: `RemoteTaskRepository`, `NativePDFRenderer`.
- DTOs usam sufixo `DTO`; comandos/resultados descrevem intenção (`CompleteTaskCommand`, `TaskMutationResult`), sem expor contrato HTTP às views.
- Identificadores de recursos/chaves de localização também em inglês, como `task.status.awaitingConfirmation`; o valor exibido é “Aguardando confirmação”.
- Testes descrevem comportamento em inglês, como `reopeningTaskRemovesPreviousCreditOnce`; fixtures usam nomes fictícios.
- O vocabulário adota `Member`, `FamilyTask`, `Routine`, `Mission`, `RewardItem`, `BadgeAward`, `WeeklyRecognition`; não alterna sinônimos arbitrários entre camadas.
- Nomes portugueses existentes no DER e IDs RN/RF/UC/TEL/MOD/UF permanecem referências documentais. Código futuro usa inglês; mapeamento para persistência é explícito.

`DrawRewardUseCase` usa `RewardDrawing` local e itens elegíveis consultados pela API. `RewardRepository` registra somente o aceite. `ChangeFamilyTimeZoneUseCase` envia fuso IANA e `immediate`/`nextCycle`; o servidor calcula os limites de ciclo.

## Histórico

| Versão | Data | Alteração |
|---|---|---|
| 1.5 | 2026-10-06 | Consulta própria passa a ser diária; consultas familiares adultas usam Dia/Semana, com `memberId` e tarefas sem responsável; carga fica para SPEC-018. Para SPEC-009; base funcional 1.9, design 1.4. |
| 1.4 | 2026-10-06 | Rotina passa a aceitar observação; MOD-002 não exige data final e MOD-003 inclui a ocorrência de origem no alcance futuro. Para SPEC-008; base funcional 1.8, design 1.3. |
| 1.3 | 2026-10-06 | MOD-014 (novo) resolve sinalização Kids pendente ao editar tarefa; TEL-013 ganha campo de observação; título limitado a 60 caracteres. Para SPEC-007; base funcional 1.7, design 1.2. |
| 1.2 | 2026-10-05 | Integração com arquitetura backend 1.0 em Node.js, contratos `/v1`, bootstrap, preparação de rotinas e referências; base funcional 1.5 preservada. |
| 1.1 | 2026-10-05 | Base 1.5; 26 telas, 13 modais, 16 fluxos; configurações de fuso, detalhe de badge, troca de acesso e responsabilidades atualizadas. |
| 1.0 | 2026-10-05 | Fronteiras de 11 funcionalidades, catálogo de 24 telas e 11 modais, cobertura UC01–UC19/UF-01–UF-15 e RNF01–27, com nomes técnicos em inglês. |
