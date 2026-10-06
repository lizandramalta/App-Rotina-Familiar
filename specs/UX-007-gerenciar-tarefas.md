# UX Spec 007: Gerenciar tarefas

**Status:** aprovada
**Autor:** Claude | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06
**Spec funcional vinculada:** [SPEC-007-gerenciar-tarefas.md](SPEC-007-gerenciar-tarefas.md)
**Base funcional:** 1.7
**Superfícies de interface:** TEL-011, TEL-012 (parcial), TEL-013 (parcial), MOD-001, MOD-005, MOD-014

## 1. Objetivo da experiência e jornada

- **Visão da experiência:** um adulto cadastra ou ajusta uma tarefa doméstica em poucos campos, sem ambiguidade sobre o que aconteceu quando a tarefa já tinha uma sinalização da criança pendente de decisão.
- **Perfis atendidos:** Administrador e Membro em TEL-011, TEL-012 e TEL-013. Kids não navegam para nenhuma dessas superfícies de gestão.

## 2. Rastreabilidade complementar

| Referência | Código / documento |
|---|---|
| Spec vinculada | `SPEC-007-gerenciar-tarefas.md` |
| Telas e modais | TEL-011, TEL-012, TEL-013, MOD-001, MOD-005, MOD-014 |
| Fluxos | UF-05 (ramo tarefa única), UF-08 (ramo exclusão) |
| Design consultado | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

## 3. Escopo da experiência

- **Dentro:** formulário de criação/edição de tarefa única (título, peso, data, responsáveis, observação), confirmação de exclusão, e o modal obrigatório de resolução de sinalização pendente ao editar.
- **Fora:** seletor de recorrência (MOD-002, pertence à UX-008), seletor de alcance de rotina (MOD-003), ações Concluir/Reabrir em TEL-012 (permanecem ocultas até SPEC-010/SPEC-011), fila de confirmação Kids (TEL-015/016).

## 4. Jornada, navegação e preservação de contexto

| Origem | Ação | Destino | Retorno / cancelamento | Preservação |
|---|---|---|---|---|
| TEL-011 | Tocar em "Nova tarefa" | TEL-013 | Fechar sem salvar pede confirmação de descarte se houver texto digitado | Rascunho local até confirmar |
| TEL-013 | Abrir seletor de responsáveis | MOD-001 | Confirmar devolve seleção ao rascunho; cancelar mantém seleção anterior | Rascunho do formulário preservado |
| TEL-013 | Salvar com sucesso | TEL-011 ou TEL-012 de origem | — | Lista/detalhe atualizados; item recém-criado é destacado brevemente |
| TEL-012 | Tocar em "Editar" | TEL-013 (pré-preenchida) | Fechar sem salvar pede confirmação de descarte | Dados atuais da tarefa carregados no rascunho |
| TEL-013 | Salvar edição de tarefa `awaitingConfirmation` | MOD-014 | Cancelar no modal retorna a TEL-013 sem salvar | Rascunho da edição preservado até a escolha |
| MOD-014 | Escolher e confirmar | TEL-012 ou TEL-011 de origem | — | Tarefa retorna com o novo estado (`pending` ou `awaitingConfirmation`) |
| TEL-012 | Tocar em "Excluir" | MOD-005 | Cancelar retorna a TEL-012 sem excluir | Nenhum dado de formulário envolvido |
| MOD-005 | Confirmar exclusão | TEL-011 ou TEL-012 de origem | — | Lista atualizada; se havia sinalização pendente, ela some sem aviso adicional |

- **Prevenção de perda de dados:** iniciar o preenchimento e tentar fechar exibe alerta: "Descartar alterações? Os dados não salvos serão perdidos."

## 5. Superfícies e componentes

### 5.1. TEL-013 — Criar/editar tarefa (bloco de tarefa única)

- **Objetivo:** coletar título, peso, data, responsáveis e observação, e salvar a tarefa única.
- **Anatomia:** barra superior com fechar/voltar e título da tela; campo de título com contador (0/60); seletor de peso com os três níveis rotulados; `DatePicker` com data inicial livre (padrão hoje); `MOD-001` para responsáveis; campo de observação multilinha opcional com contador (0/250); botão primário "Salvar" fixo no rodapé.
- **Comportamento:** o botão só habilita com título não vazio e peso selecionado. Ao salvar uma tarefa `awaitingConfirmation`, antes de enviar o `PATCH`, abre `MOD-014` e só prossegue após a escolha. O bloco de recorrência (frequência) não aparece nesta entrega.
- **Apresentação por perfil:** Kids não acessam esta tela; o botão/entrada de criação fica oculto para esse perfil em qualquer superfície.

### 5.2. TEL-012 — Detalhe da tarefa (ações desta entrega)

- **Objetivo:** mostrar título, peso, responsáveis, observação, estado e origem, com acesso a Editar e Excluir.
- **Anatomia:** cabeçalho com título e estado (`Pendente`, `Aguardando confirmação`, `Concluída`); corpo com peso, responsáveis, data e observação quando houver; ações "Editar" e "Excluir" visíveis apenas para Administrador/Membro.
- **Comportamento:** nesta entrega, "Concluir" e "Reabrir" não são exibidos — eles pertencem a SPEC-010/SPEC-011 e só aparecem quando essas entregas existirem. "Excluir" fica desabilitado com explicação quando a tarefa está `completed` ou protegida por missão concluída.

### 5.3. MOD-001 — Selecionar responsáveis

- **Objetivo:** escolher nenhum, um ou vários responsáveis para a tarefa.
- **Comportamento:** edita um rascunho local; confirmar devolve a seleção a TEL-013 sem gravar. IDs repetidos não são exibidos como seleção distinta (a lista mostrada já é um conjunto).

### 5.4. MOD-005 — Confirmar exclusão

- **Objetivo:** confirmar o alcance e os impactos antes de excluir.
- **Anatomia:** mensagem de confirmação; quando há sinalização Kids pendente, inclui uma linha informando que a sinalização será removida junto com a tarefa; ações Cancelar e Excluir.
- **Comportamento:** bloqueia e explica quando a tarefa é `completed` ou está protegida por missão concluída, sem oferecer "Excluir" nesses casos.

### 5.5. MOD-014 — Resolver sinalização pendente

- **Objetivo:** obrigar a escolha entre devolver a tarefa a Pendente ou manter Aguardando confirmação, antes de persistir qualquer edição sobre uma tarefa nesse estado.
- **Anatomia:** título explicando a situação; resumo de quem sinalizou e quando; duas opções mutuamente exclusivas ("Retornar para Pendente" e "Manter Aguardando confirmação"); ações Cancelar (volta ao formulário sem salvar) e Confirmar (habilitada só após escolher uma opção).
- **Comportamento:** aparece sempre que uma edição é salva sobre tarefa `awaitingConfirmation`, mesmo que só a observação tenha mudado. Confirmar dispara o `PATCH` com o `signalResolution` escolhido.

## 6. Estados de interface

| Estado | TEL-013 | TEL-012 | MOD-014 |
|---|---|---|---|
| Initial | Formulário vazio, data de hoje, peso não selecionado | Carregando dados da tarefa | Não aplicável antes de abrir |
| Loading | Não aplicável antes de interação | Skeleton nos campos | Não aplicável |
| Content | Campos editáveis com contadores | Dados completos e ações habilitadas conforme estado/permissão | Resumo da sinalização e duas opções |
| Submitting | Botão com spinner, campos bloqueados | Ações bloqueadas durante edição/exclusão em andamento | Botão Confirmar com spinner |
| Error não bloqueante | Erro de campo inline, dados preservados | Banner de erro ao editar/excluir, estado anterior preservado | Erro de envio preservando a escolha feita |
| Error bloqueante | — | Tela de falha ao carregar, com "Tentar novamente" | — |
| Offline | Mantém rascunho, orienta reconectar | Mostra último estado conhecido, ações de gravação desabilitadas | Mantém escolha, desabilita Confirmar |

Não há estado vazio nestas superfícies: TEL-013 sempre é um formulário e TEL-012 sempre exibe uma tarefa existente.

## 7. Microcopy e i18n

| Elemento | Chave | Texto pt-BR proposto | Cenário |
|---|---|---|---|
| Título criar | `tasks.create.title` | "Nova tarefa" | TEL-013 |
| Título editar | `tasks.edit.title` | "Editar tarefa" | TEL-013 |
| Campo título | `tasks.form.title_placeholder` | "Ex.: Arrumar a cama" | Campo de entrada |
| Contador título | `tasks.form.title_counter` | "{{current}}/60 caracteres" | Enquanto digita |
| Peso | `tasks.form.weight_label` | "Esforço" | Seletor de peso |
| Peso 1/2/3 | `tasks.form.weight_option_{low,medium,high}` | "Pouco esforço" / "Esforço médio" / "Alto esforço" | RF16 |
| Observação | `tasks.form.note_placeholder` | "Observação (opcional)" | Campo multilinha |
| Contador observação | `tasks.form.note_counter` | "{{current}}/250 caracteres" | Enquanto digita |
| Erro título vazio | `tasks.form.error_title_required` | "Informe um título para a tarefa" | Submissão com campo vazio |
| Erro título longo | `tasks.form.error_title_too_long` | "O título pode ter no máximo 60 caracteres" | Acima do limite |
| Erro observação longa | `tasks.form.error_note_too_long` | "A observação pode ter no máximo 250 caracteres" | Acima do limite |
| Botão salvar | `tasks.form.submit` | "Salvar tarefa" | Ação primária |
| Botão salvando | `tasks.form.submitting` | "Salvando..." | Durante envio |
| Excluir — confirmar | `tasks.delete.confirm_message` | "Excluir esta tarefa?" | MOD-005 |
| Excluir — aviso de sinalização | `tasks.delete.pending_signal_notice` | "A sinalização da criança para esta tarefa será removida." | MOD-005, quando `awaitingConfirmation` |
| Bloqueio concluída | `tasks.delete.error_already_completed` | "Tarefas concluídas não podem ser excluídas diretamente" | 409 |
| Bloqueio missão concluída | `tasks.delete.error_mission_protected` | "Esta tarefa faz parte de uma missão concluída e não pode ser alterada" | 409 |
| Bloqueio última tarefa | `tasks.delete.error_mission_would_be_empty` | "Vincule outra tarefa à missão antes de excluir esta" | 409 |
| Título MOD-014 | `tasks.signal_resolution.title` | "Esta tarefa tem uma sinalização aguardando confirmação" | MOD-014 |
| Opção retornar | `tasks.signal_resolution.option_reset` | "Retornar para Pendente" | MOD-014 |
| Opção manter | `tasks.signal_resolution.option_keep` | "Manter Aguardando confirmação" | MOD-014 |
| Explicação retornar | `tasks.signal_resolution.option_reset_hint` | "A sinalização atual será descartada e a criança poderá sinalizar novamente." | MOD-014 |
| Explicação manter | `tasks.signal_resolution.option_keep_hint` | "A sinalização continua aguardando sua confirmação, já com os dados atualizados." | MOD-014 |
| Falha de rede | `tasks.common.error_network` | "Não foi possível conectar. Verifique sua internet." | Timeout ou erro de rede |

## 8. Acessibilidade e adaptação

- Ordem VoiceOver em TEL-013: fechar/voltar → título da tela → campo de título → peso → data → responsáveis → observação → salvar. Em MOD-014: título explicativo → opção retornar → opção manter → cancelar → confirmar.
- Rótulos acessíveis: botão de peso anuncia o nível ("Esforço: pouco, selecionado"); contador de caracteres é anunciado ao atingir o limite.
- Todos os textos usam Dynamic Type, sem truncar título ou observação; campos de texto expandem verticalmente.
- Cor nunca é a única indicação de erro ou estado; usar texto e ícone semântico com contraste WCAG AA.
- Alvos de toque com no mínimo 44×44 pt. Em iPad, TEL-013 usa `Form Sheet` centralizado até 540 pt; MOD-001, MOD-005 e MOD-014 seguem o mesmo padrão.

## 9. Decisões e esclarecimentos de UX

| # | Decisão | Situação | Altera comportamento? |
|---|---|---|---|
| UX-01 | MOD-014 é exigido em toda edição salva sobre tarefa `awaitingConfirmation`, mesmo alterando somente a observação. | Decidida em 2026-10-06 | Não; aplica RN66/RF69 já registrados na SPEC |
| UX-02 | MOD-005 informa a remoção da sinalização pendente como parte da confirmação de exclusão, sem uma segunda confirmação específica para a sinalização. | Decidida em 2026-10-06 | Não; aplica RN66/RF69 |
| UX-03 | TEL-012 oculta completamente as ações Concluir e Reabrir nesta entrega, em vez de mostrá-las desabilitadas. | Decidida em 2026-10-06 | Não; antecipa SPEC-010/SPEC-011 |

## 10. Checklist de aprovação

- [x] Vinculada à SPEC-007 e às superfícies existentes.
- [x] Jornadas, retornos, falhas e preservação de rascunho especificados.
- [x] Estados, i18n e requisitos de acessibilidade definidos.
- [x] Ações não permitidas por perfil ficam ocultas, não apenas desabilitadas.
- [x] Base funcional atualizada e SPEC vinculada aprovada.
