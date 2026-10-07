# Specs de entrega

Esta pasta contém as especificações aprovadas que transformam a base documental em
entregas pequenas, testáveis e rastreáveis entre `mobile/` e `backend/`.

As specs são contratos de trabalho, não uma nova fonte de verdade para o produto. Elas
delimitam o que será entregue, quais regras aplicam e quais critérios devem ser
verificados. A base funcional continua em `docs/`.

## Regra de execução com IA

Um agente de IA só inicia uma funcionalidade quando existir uma SPEC aprovada e, caso
ela altere a experiência, uma UX-spec aprovada e vinculada. O agente usa o mapa abaixo
para localizar a próxima entrega, mas não deve inferir comportamento a partir dele:
regras, permissões, estados e exceções continuam em `docs/` e precisam estar
referenciados na spec.

## Como criar uma spec funcional

1. Copie `SPEC-000-template.md` para `SPEC-NNN-nome-curto.md`.
2. Preencha a rastreabilidade com os códigos que realmente pertencem ao recorte.
3. Leia os documentos citados, convertendo os comportamentos relevantes em critérios
   de aceitação verificáveis.
4. Registre toda lacuna em **Esclarecimentos**. Se ela mudar o produto, atualize
   primeiro a documentação em `docs/`.
5. Associe cada critério a uma única fase e aprove a spec apenas após o checklist.

## UX-spec e fluxo de trabalho

Para toda entrega que altera a experiência de alguém no aplicativo, crie uma UX-spec
em paralelo usando `UX-000-template.md`. Use a mesma numeração e o mesmo nome curto da
spec funcional: por exemplo, `SPEC-001-criar-tarefa.md` e
`UX-001-criar-tarefa.md`. Para trabalho estritamente interno de backend, a spec deve
registrar **UX-spec: não aplicável** e justificar.

1. Crie a spec funcional e a UX-spec ainda como rascunhos, vinculando uma à outra.
2. A spec converte regras e casos de uso em critérios de aceitação; a UX-spec detalha
   entradas, navegação, conteúdo, feedback, microcopy e acessibilidade.
3. Revise e aprove as duas juntas. Se uma decisão de UX mudar uma regra, permissão ou
   estado, ela volta para a spec funcional e para `docs/` antes da aprovação.
4. Na implementação, mobile consulta as duas; backend consulta a spec funcional e os
   contratos técnicos. Cada PR aponta os critérios e a UX-spec que cobriu.

UX-spec não substitui wireframes ou protótipos: ela é o registro textual e rastreável
da experiência. Isso permite evoluir o visual sem perder decisões, estados e textos.

## Leitura por tipo de trabalho

| Trabalho | Consulte além da spec |
|---|---|
| Regra, permissão ou estado | `01-regras-de-negocio.md`, `02-requisitos.md`, `03-casos-de-uso.md` |
| Experiência e interface | `design/screen-map.md`, `design/user-flows.md` e a UX-spec vinculada |
| Mobile | `architecture/mobile-architecture.md`, `mobile-feature-catalog.md`, `mobile-decisions.md` |
| Backend ou API | `architecture/backend-architecture.md`, `backend-contracts.md`, `backend-decisions.md`, `05-modelo-de-dados.md` |
| Alteração compartilhada | As fontes mobile e backend acima, mais os contratos de API |

## Mapa de implementação

**Base funcional:** 1.13 (2026-10-07)

**Convenção de status:** `não criada` indica apenas uma entrega planejada; os status
do template passam a valer depois que o arquivo da spec existir.

O mapa organiza as entregas por tema e preserva a numeração estável dos futuros pares
`SPEC-NNN` e `UX-NNN`. Dependências são funcionais: uma spec posterior pode ser
planejada antes, mas não deve depender de comportamento ainda indisponível.

### Tema 1 - Acesso, família e perfis

| Spec planejada | UC principal | Projetos | Depende de | Status |
|---|---|---|---|---|
| [`SPEC-001-autenticar-com-apple`](SPEC-001-autenticar-com-apple.md) - Autenticar com Apple | UC04 | ambos | - | aprovada |
| [`SPEC-002-criar-configurar-familia`](SPEC-002-criar-configurar-familia.md) - Criar e configurar família | UC01 | ambos | SPEC-001 | aprovada |
| [`SPEC-003-gerenciar-membros`](SPEC-003-gerenciar-membros.md) - Gerenciar membros | UC02 | ambos | SPEC-002 | aprovada |
| [`SPEC-004-gerar-reenviar-convite`](SPEC-004-gerar-reenviar-convite.md) - Gerar e reenviar convite | UC02 | ambos | SPEC-003 | aprovada |
| [`SPEC-005-ingressar-por-convite`](SPEC-005-ingressar-por-convite.md) - Ingressar por convite | UC09 | ambos | SPEC-004 | aprovada |
| [`SPEC-006-editar-perfil`](SPEC-006-editar-perfil.md) - Editar perfil e consultar badges | UC10 | ambos | SPEC-003, SPEC-014 | aprovada |

`SPEC-002` inclui o fuso da família: seleção na criação e configuração posterior por
Administradores. Ela cobre TEL-002, TEL-053 e MOD-012; não há uma SPEC-021 separada.

### Tema 2 - Tarefas e rotina

| Spec planejada | UC principal | Projetos | Depende de | Status |
|---|---|---|---|---|
| [`SPEC-007-gerenciar-tarefas`](SPEC-007-gerenciar-tarefas.md) - Gerenciar tarefas | UC07 | ambos | SPEC-002 | aprovada |
| [`SPEC-008-definir-recorrencia`](SPEC-008-definir-recorrencia.md) - Definir recorrência de rotina | UC08 | ambos | SPEC-007 | aprovada |
| [`SPEC-009-visualizar-minhas-tarefas`](SPEC-009-visualizar-minhas-tarefas.md) - Visualizar minhas tarefas | UC11 | ambos | SPEC-007 | aprovada |
| [`SPEC-010-concluir-tarefa`](SPEC-010-concluir-tarefa.md) - Concluir tarefa | UC12 | ambos | SPEC-007 | aprovada |
| [`SPEC-011-reabrir-tarefa`](SPEC-011-reabrir-tarefa.md) - Retornar tarefa concluída a Pendente | UC17 | ambos | SPEC-010, SPEC-014 | aprovada |

### Tema 3 - Participação Kids

| Spec planejada | UC principal | Projetos | Depende de | Status |
|---|---|---|---|---|
| `SPEC-012-sinalizar-tarefa-kids` - Sinalizar tarefa como realizada | UC15 | ambos | SPEC-007 | não criada |
| `SPEC-013-validar-conclusao-kids` - Validar conclusão de tarefa Kids | UC03 | ambos | SPEC-012 | não criada |

### Tema 4 - Missões e recompensas

| Spec planejada | UC principal | Projetos | Depende de | Status |
|---|---|---|---|---|
| [`SPEC-014-gerenciar-missoes`](SPEC-014-gerenciar-missoes.md) - Gerenciar missões | UC05 | ambos | SPEC-007 | aprovada |
| `SPEC-015-gerenciar-recompensas-coletivas` - Gerenciar itens de recompensas coletivas | UC06 | ambos | SPEC-002 | não criada |
| `SPEC-016-acompanhar-missoes-recompensas` - Acompanhar missões e recompensas | UC14 | ambos | SPEC-014 | não criada |
| `SPEC-017-resgatar-recompensa` - Resgatar recompensa da missão | UC16 | ambos | SPEC-014, SPEC-015 | não criada |

### Tema 5 - Acompanhamento e reconhecimento

| Spec planejada | UC principal | Projetos | Depende de | Status |
|---|---|---|---|---|
| `SPEC-018-visualizar-carga` - Visualizar carga diária ou semanal | UC13 | ambos | SPEC-010, SPEC-013 | não criada |
| `SPEC-019-gerar-relatorio-semanal-pdf` - Gerar relatório semanal em PDF | UC18 | ambos | SPEC-018 | não criada |
| `SPEC-020-destaque-semanal` - Apurar e compartilhar destaque semanal | UC19 | ambos | SPEC-018 | não criada |

## Índice de arquivos

Ao iniciar uma entrega, inclua neste índice a SPEC e sua UX-spec com seus links,
status e resumo; mantenha esta tabela como o panorama do backlog.

| Spec | UX-spec | Status | Projetos | Resumo |
|---|---|---|---|---|
| [SPEC-001-autenticar-com-apple](SPEC-001-autenticar-com-apple.md) | [UX-001-autenticar-com-apple.md](UX-001-autenticar-com-apple.md) | aprovada | ambos | Login nativo Apple do Criador, emissão de sessão ou `creationGrant`, e ciclo de vida da sessão (consulta, renovação, revogação). |
| [SPEC-002-criar-configurar-familia](SPEC-002-criar-configurar-familia.md) | [UX-002-criar-configurar-familia.md](UX-002-criar-configurar-familia.md) | aprovada | ambos | Criação atômica da família pelo Criador e configuração autorizada do fuso familiar. |
| [SPEC-003-gerenciar-membros](SPEC-003-gerenciar-membros.md) | [UX-003-gerenciar-membros](UX-003-gerenciar-membros.md) | aprovada | ambos | Criação e gestão autorizada de membros, papéis, modo Kids e remoção preservando histórico. |
| [SPEC-004-gerar-reenviar-convite](SPEC-004-gerar-reenviar-convite.md) | [UX-004-gerar-reenviar-convite](UX-004-gerar-reenviar-convite.md) | aprovada | ambos | Emissão e reemissão segura de link e senha, com revogação de credenciais/sessão anteriores e compartilhamento nativo único. |
| [SPEC-005-ingressar-por-convite](SPEC-005-ingressar-por-convite.md) | [UX-005-ingressar-por-convite](UX-005-ingressar-por-convite.md) | aprovada | ambos | Inspeção neutra e consumo único do convite, sessão vinculada à instalação, troca segura de acesso e recuperação limitada de resposta perdida. |
| [SPEC-007-gerenciar-tarefas](SPEC-007-gerenciar-tarefas.md) | [UX-007-gerenciar-tarefas.md](UX-007-gerenciar-tarefas.md) | aprovada | ambos | CRUD da tarefa única (título, peso, data, responsáveis, observação), com proteções de missão/conclusão e resolução obrigatória de sinalização Kids pendente ao editar/excluir. |
| [SPEC-008-definir-recorrencia](SPEC-008-definir-recorrencia.md) | [UX-008-definir-recorrencia.md](UX-008-definir-recorrencia.md) | aprovada | ambos | Rotina com observação opcional, início sem data final obrigatória, frequências fixas, materialização segura e alcance inclusivo “selecionada e futuras”. |
| [SPEC-009-visualizar-minhas-tarefas](SPEC-009-visualizar-minhas-tarefas.md) | [UX-009-visualizar-minhas-tarefas.md](UX-009-visualizar-minhas-tarefas.md) | aprovada | ambos | Consulta própria diária para todos; tarefas e progresso familiares adultos por Dia/Semana, com filtros de membro e tarefas sem responsável. |
| [SPEC-010-concluir-tarefa](SPEC-010-concluir-tarefa.md) | [UX-010-concluir-tarefa.md](UX-010-concluir-tarefa.md) | aprovada | ambos | Conclusão atômica com crédito explícito; tarefa com responsável Kids somente por Administrador e reconciliação silenciosa de concorrência. |
| [SPEC-014-gerenciar-missoes](SPEC-014-gerenciar-missoes.md) | [UX-014-gerenciar-missoes.md](UX-014-gerenciar-missoes.md) | aprovada | ambos | Criação e edição de missões coletivas sem prazo com observação opcional, atalho de criação de tarefa, fechamento automático com participações/badges, e consulta básica por todos os perfis, inclusive Kids. |
| [SPEC-006-editar-perfil](SPEC-006-editar-perfil.md) | [UX-006-editar-perfil.md](UX-006-editar-perfil.md) | aprovada | ambos | Edição do próprio apelido (até 20 caracteres não-espaço) e foto opcional por câmera/galeria, com titularidade exclusiva; consulta de badges cumulativos e missões contribuintes por marco. |
| [SPEC-011-reabrir-tarefa](SPEC-011-reabrir-tarefa.md) | [UX-011-reabrir-tarefa.md](UX-011-reabrir-tarefa.md) | aprovada | ambos | Retorno de tarefa concluída para Pendente por Admin/Membro (qualquer tarefa acessível) ou Kids (própria), com reversão de crédito e confirmação explícita quando afeta missão concluída e/ou recompensa aceita. |

## Templates

- `SPEC-000-template.md`: comportamento, critérios de aceitação e fases.
- `UX-000-template.md`: experiência, navegação, estados e textos da interface.
