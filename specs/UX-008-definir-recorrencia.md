# UX Spec 008: Definir recorrência de rotina

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06
**Spec funcional vinculada:** [SPEC-008-definir-recorrencia.md](SPEC-008-definir-recorrencia.md)
**Base funcional:** RN 1.20 / RF 1.19 / UC 1.19 (revisada em 2026-10-27, UX-04 e UX-05)
**Superfícies de interface:** TEL-012, TEL-013, MOD-002, MOD-003, UF-05

## 1. Objetivo da experiência e jornada

- **Visão da experiência:** um adulto configura uma tarefa que se repete sem confundir a frequência com uma data de término, e entende precisamente quais ocorrências serão alteradas ou terão a geração encerrada.
- **Perfis atendidos:** Administrador e Membro. Kids não acessam os controles de recorrência.

## 2. Rastreabilidade complementar

| Referência | Código / documento |
|---|---|
| Spec vinculada | `SPEC-008-definir-recorrencia.md` |
| Telas e modais | TEL-012, TEL-013, MOD-002, MOD-003 |
| Fluxo | UF-05 |
| Design consultado | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

## 3. Escopo da experiência

- **Dentro:** selecionar repetição em TEL-013, escolher data inicial livre e frequência em MOD-002, apresentar preparação de materialização, escolher o alcance inclusivo em MOD-003 e confirmar retorno à origem com dados atualizados.
- **Fora:** formulário-base da tarefa única e seus campos já detalhados na UX-007; conclusão, reabertura, tarefas Kids, data final, frequência mensal e intervalos customizados.

## 4. Jornada, navegação e preservação de contexto

| Origem | Ação | Destino | Retorno / cancelamento | Preservação |
|---|---|---|---|---|
| TEL-010/TEL-011 | Criar tarefa | TEL-013 | Fechar confirma descarte se houver alterações | Mantém rascunho até confirmar descarte |
| TEL-013 | Tocar em repetição | MOD-002 | Cancelar retorna sem alterar a escolha anterior | Campos, responsáveis e observação preservados |
| MOD-002 | Escolher frequência recorrente e confirmar | TEL-013 | — | Exibe resumo da frequência; não exibe data final |
| TEL-013 | Salvar rotina | Origem | Falha mantém TEL-013 | Exibe preparo enquanto materialização estiver pendente |
| TEL-012 | Editar ocorrência de rotina | MOD-003 | Cancelar retorna ao detalhe sem gravar | Mantém o contexto da ocorrência e da origem |
| MOD-003 | Escolher “Somente esta tarefa” | TEL-013 (edição individual, SPEC-007) | Voltar preserva escolha até cancelar o formulário | Salvar grava só a ocorrência aberta (`PATCH /v1/tasks/{taskId}`) |
| MOD-003 | Escolher “Esta tarefa e as futuras” | TEL-013 | Voltar preserva escolha até cancelar o formulário | A ocorrência aberta é incluída no alcance; salvar usa `PATCH /v1/routines/{routineId}` com `fromTaskId` |
| TEL-012 | Excluir ocorrência de rotina | MOD-003 → MOD-005 | Cancelar não altera ocorrências | Confirma alcance e registros preservados |
| MOD-003 (excluir) | Escolher “Somente esta tarefa” e confirmar em MOD-005 | Origem | Cancelar em MOD-005 retorna ao detalhe | Exclui só a ocorrência aberta (`DELETE /v1/tasks/{taskId}`) |
| MOD-003 (excluir) | Escolher “Esta tarefa e as futuras” e confirmar em MOD-005 | Origem | Cancelar em MOD-005 retorna ao detalhe | `POST /v1/routines/{routineId}/future-task-deletions` com `fromTaskId` |

- **Prevenção de perda:** ao fechar TEL-013 com alteração não salva, mostrar confirmação de descarte. Falha de rede ou resposta incerta preserva o rascunho e não anuncia êxito.
- **Retorno:** a origem preserva período, filtros e posição de navegação; quando a rotina estiver preparando, uma atualização posterior não muda silenciosamente os campos que a pessoa acabou de preencher.

## 5. Superfícies e componentes

### 5.1. TEL-013 — Criar/editar tarefa ou rotina

- **Objetivo:** editar os campos comuns e encaminhar a escolha de repetição a MOD-002.
- **Anatomia:** mantém os campos da UX-007; o resumo de repetição mostra “Sem repetição” ou a frequência selecionada. Nenhum componente de data final é exibido.
- **Acesso:** somente Administrador/Membro vê o seletor e o botão de salvar. Kids não navegam à tela.
- **Edição de ocorrência de rotina:** a linha Repetição mostra a frequência vigente somente para leitura, sem abrir MOD-002, nos dois alcances. Em “Esta tarefa e as futuras”, a Data também fica somente leitura e apenas título, esforço, responsáveis e observação são editáveis (SPEC-008 E-05, E-07). Em “Somente esta tarefa”, a Data continua editável.
- **Edição de tarefa única:** a linha Repetição mostra “Sem repetição” somente para leitura; editar não transforma tarefa única em rotina (UX-05).

### 5.2. MOD-002 — Configurar repetição

- **Objetivo:** escolher tarefa única, rotina diária ou rotina a cada 7, 14, 21 ou 28 dias.
- **Anatomia:** título, campo de data inicial, grupo de seleção única para frequência, explicação curta de que ocorrências serão criadas individualmente e ações Cancelar/Confirmar.
- **Comportamento:** data inicial padrão é o dia atual do fuso familiar, mas aceita qualquer data válida. Não há escolha mensal, intervalo livre ou data final. Confirmar devolve o resumo ao formulário; a gravação acontece apenas no Salvar de TEL-013.

### 5.3. MOD-003 — Definir alcance

- **Objetivo:** tornar explícito o alcance antes de editar ou encerrar uma rotina a partir de uma ocorrência.
- **Anatomia:** sheet com ✕ (Cancelar) e ✓ (Confirmar) na barra; título “Onde aplicar esta alteração?” ao editar ou “O que excluir?” ao excluir; resumo da ocorrência aberta no formato “{título} · {data curta}”; grupo de seleção única sempre com “Somente esta tarefa” (“As outras ocorrências da rotina não mudam.”) e “Esta tarefa e as futuras” (“Inclui esta tarefa. As anteriores e as concluídas permanecem preservadas.”); rodapé “Cancelar volta ao detalhe sem gravar.”, precedido de “Depois você confirma a exclusão.” no fluxo de excluir (UX-04).
- **Comportamento:** Confirmar fica desabilitado até uma opção ser escolhida. “Somente esta tarefa” segue a edição ou exclusão individual da SPEC-007. O ramo de rotina envia `fromTaskId` somente após confirmação da opção inclusiva. Se a API indicar proteção ou origem inválida, o modal fecha para o detalhe atualizado e apresenta o motivo sem prometer alteração.

### 5.4. TEL-012 — Detalhe da tarefa de rotina

- **Objetivo:** identificar que a ocorrência vem de rotina e iniciar a ação de editar/excluir no alcance correto.
- **Comportamento:** em ocorrência de rotina, Administrador/Membro veem Editar e Excluir; ambos abrem MOD-003 antes da confirmação final. O texto de origem explica a escolha de alcance. Ações não autorizadas permanecem ocultas.

## 6. Estados de interface

| Estado | TEL-013 | MOD-002/MOD-003 | TEL-012 |
|---|---|---|---|
| Initial | Rascunho herdado ou novo | Mostra a escolha atual | Carrega detalhe e origem da tarefa |
| Content | Campos e resumo de repetição | Opções disponíveis conforme contexto | Identifica ocorrência de rotina |
| Submitting | Salvar desabilitado com progresso | Confirmar desabilitado com progresso | Ações bloqueadas durante comando |
| Preparing | Configuração confirmada, materialização em preparo | Não aplicável | Atualiza quando consulta confirmar novas ocorrências |
| Error não bloqueante | Erro de campo/servidor, rascunho preservado | Mantém escolha e permite corrigir | Banner com estado atual |
| Error bloqueante | Falha de carga oferece nova tentativa | Fecha para origem se faltar contexto | Tela de falha ao carregar detalhe |
| Offline/resposta incerta | Não mostra sucesso; preserva rascunho e orienta consultar/tentar novamente | Mantém seleção sem enviar | Mostra último estado conhecido e bloqueia gravação |

## 7. Microcopy e i18n

| Elemento | Chave | Texto pt-BR | Cenário |
|---|---|---|---|
| Título da repetição | `routines.recurrence.title` | “Repetição” | MOD-002 |
| Sem repetição | `routines.recurrence.none` | “Sem repetição” | Tarefa única |
| Diária | `routines.recurrence.daily` | “Todos os dias” | Frequência 1 |
| A cada N dias | `routines.recurrence.every_days` | “A cada {{days}} dias” | Frequências 7/14/21/28 |
| Início | `routines.recurrence.start_date` | “Começa em” | Campo de data |
| Sem data final | `routines.recurrence.no_end_date_hint` | “A rotina continua até você alterar ou encerrar as próximas ocorrências.” | Ajuda no modal |
| Preparando | `routines.materialization.preparing` | “Estamos preparando as próximas tarefas.” | Após salvar/consultar `202` |
| Alcance | `routines.scope.title` | “Onde aplicar esta alteração?” | MOD-003 |
| Alcance ao excluir | `routines.scope.delete_title` | “O que excluir?” | MOD-003 no fluxo de excluir |
| Somente esta | `routines.scope.only_this` | “Somente esta tarefa” | Alcance individual |
| Explicação somente esta | `routines.scope.only_this_hint` | “As outras ocorrências da rotina não mudam.” | MOD-003 |
| Selecionada e futuras | `routines.scope.selected_and_future` | “Esta tarefa e as futuras” | Alcance de rotina |
| Explicação do alcance | `routines.scope.selected_and_future_hint` | “Inclui esta tarefa. As anteriores e as concluídas permanecem preservadas.” | MOD-003 |
| Rodapé cancelar | `routines.scope.cancel_hint` | “Cancelar volta ao detalhe sem gravar.” | MOD-003 |
| Rodapé excluir | `routines.scope.delete_hint` | “Depois você confirma a exclusão.” | MOD-003 no fluxo de excluir |
| Origem no detalhe | `routines.detail.origin_hint` | “Faz parte de uma rotina. Ao editar ou excluir, você escolhe se vale só para esta tarefa ou também para as próximas.” | TEL-012 em ocorrência de rotina |
| Frequência inválida | `routines.error_frequency_invalid` | “Escolha uma frequência disponível.” | `FREQUENCY_DAYS_INVALID` |
| Início inválido | `routines.error_start_date_invalid` | “Informe uma data de início válida.” | `START_DATE_INVALID` |
| Origem inválida | `routines.error_source_task_invalid` | “Esta tarefa não pode definir o alcance da rotina. Atualize e tente novamente.” | `ROUTINE_SOURCE_TASK_INVALID` |
| Resultado incerto | `routines.error_result_uncertain` | “Não foi possível confirmar se a rotina foi salva. Confira o estado antes de tentar novamente.” | Resposta perdida |

## 8. Acessibilidade e adaptação

- VoiceOver em MOD-002: título → data inicial → opções de frequência → texto de ajuda → cancelar → confirmar. Em MOD-003: título → resumo → opções de alcance → explicação → cancelar → confirmar.
- Cada frequência anuncia nome, intervalo e estado selecionado. O resumo da rotina expõe data inicial e frequência em uma única descrição acessível.
- Dynamic Type não trunca opções, explicações ou erros; controles aumentam verticalmente conforme necessário.
- Estado de preparação, erro e alcance combinam texto e ícone, nunca apenas cor; contraste mínimo WCAG AA.
- Alvos de toque mínimos de 44×44 pt. Em iPad, MOD-002 e MOD-003 são `Form Sheet` de até 540 pt; em iPhone, são sheets adaptáveis.

## 9. Decisões e esclarecimentos de UX

| # | Decisão | Situação | Altera comportamento? |
|---|---|---|---|
| UX-01 | Não existe campo ou mensagem que sugira data final obrigatória; o texto explica que a rotina pode ser alterada ou encerrada futuramente. | Decidida em 2026-10-06 | Não; aplica RN14/RF13 |
| UX-02 | “Esta tarefa e as futuras” declara que inclui a ocorrência aberta. | Decidida em 2026-10-06 | Não; aplica RN17/RF13 |
| UX-03 | Materialização pendente é apresentada como preparo, sem percentual ou total final não confirmado. | Decidida em 2026-10-06 | Não; aplica contratos e RNF12/13 |
| UX-04 | MOD-003 sempre oferece “Somente esta tarefa” e “Esta tarefa e as futuras”, ao editar e ao excluir. | Decidida em 2026-10-27 | Não; aplica RN17/RN18/UC08 |
| UX-05 | Na edição, a linha Repetição é somente leitura: tarefa única não vira rotina e ocorrência de rotina não muda a frequência; em “Esta tarefa e as futuras” a Data também é somente leitura. | Decidida em 2026-10-27 | Sim; aplica SPEC-008 E-05/E-07 (RN17 1.20) |

## 10. Checklist de aprovação

- [x] Vinculada à SPEC-008 e às superfícies existentes.
- [x] Jornadas, retornos, rascunhos e falhas definidos.
- [x] Estados, microcopy localizável e acessibilidade definidos.
- [x] Ações de Kids permanecem ocultas e bloqueadas no servidor.
- [x] Não cria regra de data final, frequência ou alcance além da SPEC vinculada.
- [x] Status `aprovada` autorizado explicitamente pela pessoa usuária em 2026-10-06.
