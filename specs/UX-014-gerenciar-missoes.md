# UX Spec 014: Gerenciar missões

**Status:** aprovada
**Autor:** Claude | **Criada em:** 2026-10-07 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-07
**Spec funcional vinculada:** [SPEC-014-gerenciar-missoes.md](SPEC-014-gerenciar-missoes.md)
**Base funcional:** 1.12
**Superfícies de interface:** TEL-020 (parcial), TEL-021 (parcial), TEL-022, MOD-007

## 1. Objetivo da experiência e jornada

- **Visão da experiência:** um Administrador organiza uma conquista coletiva escolhendo tarefas específicas — já existentes ou criadas na hora — sem se preocupar com prazo; qualquer pessoa da família, inclusive uma criança, entende do que se trata e acompanha o status de forma simples.
- **Perfis atendidos:** Administrador (gestão completa em TEL-022/MOD-007). Membro e Kids consultam TEL-020/TEL-021 em leitura; Kids numa apresentação simplificada, sem nenhuma ação de gestão.

## 2. Rastreabilidade complementar

| Referência | Código / documento |
|---|---|
| Spec vinculada | `SPEC-014-gerenciar-missoes.md` |
| Telas e modais | TEL-020 (parcial), TEL-021 (parcial), TEL-022, MOD-007 |
| Fluxos | UF-10 (ramos de criação/edição e consulta básica) |
| Design consultado | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

## 3. Escopo da experiência

- **Dentro:** formulário de criação/edição de missão (título, observação, tarefas vinculadas) com atalho para criar tarefa nova; seletor de tarefas com bloqueio local contra ficar sem nenhuma selecionada; lista (TEL-020) e detalhe (TEL-021) na fatia mínima — título, observação, tarefas vinculadas e status — para todos os perfis, com variante Kids simplificada.
- **Fora:** progresso formatado, participações, exibição de recompensa e navegação por marco de badge (UX-016/SPEC-016); roleta e resgate (UX-017/SPEC-017); cadastro de itens de recompensa (UX-015/SPEC-015).

## 4. Jornada, navegação e preservação de contexto

| Origem | Ação | Destino | Retorno / cancelamento | Preservação |
|---|---|---|---|---|
| TEL-020 | Administrador toca em "Nova missão" | TEL-022 | Fechar sem salvar pede confirmação de descarte se houver texto digitado | Rascunho local até confirmar |
| TEL-020 | Qualquer perfil toca numa missão da lista | TEL-021 | Voltar retorna à lista | — |
| TEL-021 | Administrador toca em "Editar" (missão em andamento) | TEL-022 (pré-preenchida) | Fechar sem salvar pede confirmação de descarte | Dados atuais da missão carregados no rascunho |
| TEL-022 | Abrir seletor de tarefas | MOD-007 | Confirmar devolve a seleção ao rascunho; cancelar mantém seleção anterior | Rascunho do formulário preservado |
| MOD-007 | Tocar em "+ Nova tarefa" | TEL-013 (fluxo padrão de criação, SPEC-007) | Cancelar volta a MOD-007 sem alterar a seleção | Seleção atual do rascunho preservada |
| TEL-013 | Salvar a nova tarefa com sucesso | MOD-007 | — | Tarefa recém-criada aparece pré-selecionada no topo da lista |
| TEL-022 | Salvar com sucesso | TEL-020 (criação) ou TEL-021 (edição) de origem | — | Lista/detalhe atualizados; item destacado brevemente |

- **Preservação de estado:** o rascunho de tarefas selecionadas em MOD-007 sobrevive à ida e volta do atalho "+ Nova tarefa".
- **Prevenção de perda de dados:** iniciar o preenchimento de TEL-022 e tentar fechar exibe alerta: "Descartar alterações? Os dados não salvos serão perdidos."

## 5. Superfícies e componentes

### 5.1. TEL-022 — Criar/editar missão

- **Objetivo:** coletar título, observação opcional e tarefas vinculadas, e salvar a missão.
- **Anatomia:** barra superior com fechar/voltar e título da tela; campo de título com contador (0/60); campo de observação multilinha opcional com contador (0/250); bloco "Tarefas vinculadas" com a lista atual e botão "Selecionar tarefas" que abre MOD-007; botão primário "Salvar" fixo no rodapé.
- **Comportamento:** o botão Salvar só habilita com título não vazio e ao menos uma tarefa selecionada. Se o rascunho ficar sem tarefas, o botão fica desabilitado e um texto inline explica o motivo ("uma missão precisa de ao menos uma tarefa"), sem chamar o backend. Ao salvar, se todas as tarefas vinculadas já estiverem concluídas, a missão nasce/retorna já `Concluída` e a tela de origem mostra esse status imediatamente.
- **Apresentação por perfil:** Membro e Kids não acessam esta tela; a entrada de criação/edição fica oculta para esses perfis em qualquer superfície.

### 5.2. MOD-007 — Selecionar tarefas da missão

- **Objetivo:** escolher individualmente uma ou mais tarefas da família, com opção de criar uma nova na hora.
- **Anatomia:** campo de busca textual opcional; lista paginada de tarefas da família (título, status, data), com checkbox de seleção; ação "+ Nova tarefa" no topo ou rodapé da lista; ação "Confirmar" fixa.
- **Comportamento:** edita um rascunho local; confirmar devolve a seleção a TEL-022 sem gravar a missão. Desmarcar a última tarefa selecionada não é bloqueado dentro do próprio MOD-007 (a seleção pode ficar vazia aqui), mas o botão "Confirmar"/"Salvar" subsequente em TEL-022 permanece desabilitado enquanto a seleção estiver vazia, com a mesma explicação inline. "+ Nova tarefa" abre o fluxo padrão de criação (TEL-013); ao voltar com sucesso, a nova tarefa aparece marcada e em destaque no topo da lista.

### 5.3. TEL-020 — Missões e conquistas (fatia desta entrega)

- **Objetivo:** listar missões em andamento e concluídas.
- **Anatomia:** duas seções ("Em andamento", "Concluídas"); cada item mostra título e status; Administrador vê a ação "Nova missão" no topo.
- **Comportamento:** lista vazia mostra estado vazio com texto orientador; para Administrador, com ação de criar. Progresso detalhado, participações e recompensa não aparecem nesta fatia — ficam para UX-016.
- **Apresentação por perfil:** Kids veem a mesma lista (título e status), em visual simplificado (ilustrações lúdicas, textos diretos), sem a ação "Nova missão".

### 5.4. TEL-021 — Detalhe da missão (fatia desta entrega)

- **Objetivo:** mostrar título, observação, tarefas vinculadas e status; dar acesso a "Editar" quando permitido.
- **Anatomia:** cabeçalho com título e status (`Em andamento`, `Concluída`); observação quando houver; lista de tarefas vinculadas (título e status de cada uma); ação "Editar" visível apenas para Administrador e apenas quando a missão está em andamento.
- **Comportamento:** progresso formatado, lista de participações e recompensa não aparecem nesta fatia — ficam para UX-016/UX-017. Toques em uma tarefa vinculada abrem seu detalhe (TEL-012) para adultos; Kids só abrem tarefas próprias (TEL-041).
- **Apresentação por perfil:** Kids veem a mesma informação básica (título, observação, tarefas, status) em layout simplificado, sem a ação "Editar" nem qualquer dado de gestão.

## 6. Estados de interface

| Estado | TEL-020 | TEL-021 | TEL-022 | MOD-007 |
|---|---|---|---|---|
| Initial/Loading | Skeleton nas duas seções | Skeleton no cabeçalho e na lista de tarefas | Formulário vazio (criação) ou skeleton nos campos (edição) | Skeleton na lista de tarefas |
| Empty | Ilustração + texto; ação de criar só para Admin | Não aplicável (sempre existe uma missão) | Bloco "Tarefas vinculadas" vazio orienta abrir o seletor | Lista vazia orienta usar a busca ou "+ Nova tarefa" |
| Content | Listas preenchidas, seções visíveis | Dados completos, "Editar" conforme perfil/estado | Campos preenchidos com contadores; botão Salvar habilitado conforme validação local | Lista com seleção marcada |
| Submitting | — | — | Botão com spinner, campos bloqueados | "Confirmar" com spinner ao voltar do seletor |
| Error não bloqueante | Banner, conteúdo anterior preservado | Banner, conteúdo anterior preservado | Erro de campo inline; bloqueio local "sem tarefas" sem chamar o servidor | Erro de busca inline |
| Error bloqueante | Tela de falha com "Tentar novamente" | Tela de falha com "Tentar novamente" | — | — |
| Offline | Mostra último estado conhecido | Mostra último estado conhecido | Mantém rascunho, orienta reconectar | Mantém rascunho local, bloqueia nova busca |

## 7. Microcopy e i18n

| Elemento | Chave | Texto pt-BR proposto | Cenário |
|---|---|---|---|
| Título criar | `missions.create.title` | "Nova missão" | TEL-022 |
| Título editar | `missions.edit.title` | "Editar missão" | TEL-022 |
| Campo título | `missions.form.title_placeholder` | "Ex.: Arrumar o quintal" | Campo de entrada |
| Contador título | `missions.form.title_counter` | "{{current}}/60 caracteres" | Enquanto digita |
| Observação | `missions.form.note_placeholder` | "Observação (opcional)" | Campo multilinha |
| Contador observação | `missions.form.note_counter` | "{{current}}/250 caracteres" | Enquanto digita |
| Bloco de tarefas | `missions.form.tasks_section_title` | "Tarefas vinculadas" | TEL-022 |
| Selecionar tarefas | `missions.form.select_tasks_button` | "Selecionar tarefas" | TEL-022 |
| Erro título vazio | `missions.form.error_title_required` | "Informe um título para a missão" | Submissão com campo vazio |
| Erro título longo | `missions.form.error_title_too_long` | "O título pode ter no máximo 60 caracteres" | Acima do limite |
| Erro observação longa | `missions.form.error_note_too_long` | "A observação pode ter no máximo 250 caracteres" | Acima do limite |
| Bloqueio sem tarefas | `missions.form.error_tasks_required` | "Uma missão precisa de ao menos uma tarefa vinculada" | Rascunho de tarefas vazio |
| Botão salvar | `missions.form.submit` | "Salvar missão" | Ação primária |
| Botão salvando | `missions.form.submitting` | "Salvando..." | Durante envio |
| Nova tarefa no seletor | `missions.task_picker.add_new_task` | "+ Nova tarefa" | MOD-007 |
| Busca no seletor | `missions.task_picker.search_placeholder` | "Buscar tarefa por título" | MOD-007 |
| Lista vazia (TEL-020) | `missions.list.empty_title` | "Nenhuma missão ainda" | Estado vazio |
| Lista vazia — ação Admin | `missions.list.empty_action` | "Criar primeira missão" | Estado vazio, Administrador |
| Status em andamento | `missions.status.in_progress` | "Em andamento" | TEL-020/021 |
| Status concluída | `missions.status.completed` | "Concluída" | TEL-020/021 |
| Falha de rede | `missions.common.error_network` | "Não foi possível conectar. Verifique sua internet." | Timeout ou erro de rede |

## 8. Acessibilidade e adaptação

- Ordem VoiceOver em TEL-022: fechar/voltar → título da tela → campo de título → campo de observação → bloco de tarefas vinculadas → salvar. Em MOD-007: busca → "+ Nova tarefa" → lista de tarefas → confirmar.
- Rótulos acessíveis: cada tarefa no seletor anuncia título e status ("Arrumar o quintal, pendente, não selecionada"); o bloqueio "sem tarefas" é anunciado como erro de formulário, não apenas por cor.
- Todos os textos usam Dynamic Type, sem truncar título ou observação; campos de texto expandem verticalmente.
- Cor nunca é a única indicação de status (badge de texto + ícone acompanha "Em andamento"/"Concluída").
- Alvos de toque com no mínimo 44×44 pt; para o perfil Kids em TEL-020/021, no mínimo 56×56 pt nos elementos principais. Em iPad, TEL-022 e MOD-007 usam `Form Sheet` centralizado até 540 pt.

## 9. Decisões e esclarecimentos de UX

| # | Decisão | Situação | Altera comportamento? |
|---|---|---|---|
| UX-01 | O bloqueio "sem tarefas" impede a chamada ao backend tanto na criação quanto ao desmarcar a última tarefa numa edição; a validação do servidor (`MISSION_TASKS_REQUIRED`/`MISSION_WOULD_HAVE_NO_TASKS`) permanece como última linha de defesa. | Decidida em 2026-10-07 | Não; aplica RN50/RNF07 já registrados na SPEC |
| UX-02 | TEL-020/021 mostram a mesma fatia mínima (título, observação, tarefas, status) para todos os perfis nesta entrega; progresso formatado, participações e recompensa só aparecem quando UX-016 existir. | Decidida em 2026-10-07 | Não; antecipa fatia de UC14 já registrada na SPEC (E-02) |
| UX-03 | Variante Kids reaproveita a mesma tela e os mesmos dados de TEL-020/021, apenas com apresentação simplificada (ilustrações, textos diretos, área de toque maior) e sem nenhuma ação de gestão. | Decidida em 2026-10-07 | Não; aplica RNF01/RNF04 já registrados na base |

## 10. Checklist de aprovação

- [x] Vinculada à SPEC-014 e às superfícies existentes/novas.
- [x] Jornadas, retornos, falhas e preservação de rascunho especificados, incluindo o atalho de criação de tarefa.
- [x] Estados, i18n e requisitos de acessibilidade definidos.
- [x] Ações não permitidas por perfil ficam ocultas, não apenas desabilitadas.
- [x] Bloqueio local "sem tarefas" especificado para criação e edição.
- [x] Apresentação Kids descrita como simplificação visual, sem alterar dados ou permissões.
