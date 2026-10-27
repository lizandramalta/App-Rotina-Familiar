# UX Spec 009: Visualizar minhas tarefas

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-19
**Spec funcional vinculada:** [SPEC-009-visualizar-minhas-tarefas.md](SPEC-009-visualizar-minhas-tarefas.md)
**Base funcional:** RN 1.18 / RF 1.17 / UC 1.18
**Revisão de interface:** 2026-10-26 — círculo imediato em TEL-010/TEL-040; cabeçalho e estados vazio/falha de TEL-010 alinhados ao [protótipo adulto aprovado](https://www.figma.com/design/CuxXOp9tKivMbELeeB6mHw/APP-FAM%C3%8DLIA-%7C-C18?node-id=330-2940)
**Superfícies:** TEL-010, TEL-011, TEL-032, TEL-040, TEL-050, UF-04

## 1. Objetivo e jornada

- **Visão da experiência:** a pessoa entende que Minhas tarefas é sua agenda diária; adultos distinguem claramente essa visão da consulta familiar por Dia/Semana.
- **Perfis:** Administrador, Membro e Kids na jornada pessoal; somente Administrador e Membro na jornada Família.

| Origem | Ação | Destino | Retorno preservado |
|---|---|---|---|
| Navegação adulta | Abrir Minhas tarefas | TEL-010 | Data diária, posição e estado da lista |
| Aba Kids | Abrir Minhas tarefas | TEL-040 | Data diária e estado da lista |
| Navegação adulta | Abrir Família | TEL-050 | Dia/Semana e data de referência |
| TEL-050 | Selecionar membro | TEL-032 | Membro e período; voltar restaura TEL-050 |
| TEL-050 | Abrir Todas as tarefas | TEL-011 | Período e filtros familiares |

## 2. Escopo de interface

- **TEL-010 e TEL-040:** carrossel de datas, checklist próprio, progresso diário e estados de lista; sem controle Semana. TEL-010 inclui somente tarefas sob responsabilidade ou corresponsabilidade do adulto. O círculo é um controle separado para concluir/reabrir conforme SPEC/UX-010/011; tocar no restante da linha abre o detalhe.
- **TEL-010 adulta:** o título visível é “Tarefas”, alinhado à esquerda, com a data logo abaixo e o botão de adicionar no mesmo cabeçalho; não há segundo título central. A aba adulta também usa “Tarefas”. O carrossel pessoal mostra uma semana visual de domingo a sábado, com o dia selecionado na posição correspondente, e permite avançar ou voltar entre semanas dentro de RN49. Essa disposição não altera a semana de segunda a domingo das métricas familiares (RN28/RN61). O cartão de progresso mostra “N de M concluídas” e “Você consegue!”; abaixo, o cabeçalho da lista mostra “Hoje | N Tarefas” ou a data escolhida com a contagem. As tarefas aparecem em cartões individuais com responsáveis e esforço como “P1 - Baixo Esforço”, “P2 - Médio Esforço” ou “P3 - Alto Esforço”. O status não compõe o subtítulo visual adulto; ícone e VoiceOver continuam a comunicá-lo. Os rótulos P1/P2/P3 são específicos do checklist e não mudam os rótulos do formulário de UX-007 §4.
- **Ícones:** usar SF Symbols nos controles do checklist e na barra de abas, preservando rótulos acessíveis e o significado de cada ação ou destino.
- **TEL-040 Kids:** preserva “Minhas tarefas” e o status textual sob cada tarefa, inclusive “Aguardando confirmação”; não herda o subtítulo de responsáveis e esforço da variante adulta.
- **TEL-010 sem tarefas:** mantém o cartão de progresso com “Sem tarefas” e barra vazia, sem incentivo; abaixo, um cartão branco apresenta “Sem tarefas para este dia”, “Tarefas atribuídas a você aparecem aqui.” e a ação “Nova tarefa”. **Falha ao atualizar:** apresenta cartão branco com ícone de alerta, mensagem e botão escuro “Tentar novamente”; quando há dados anteriores, preserva-os e oferece a mesma ação de recuperação.
- **TEL-050:** seletor Dia/Semana, progresso familiar e membros. Carga não aparece nesta entrega.
- **TEL-011:** lista familiar adulta por Dia/Semana, filtro de membro e controle de tarefas sem responsável.
- **TEL-032:** tarefas do membro escolhido por Dia/Semana, com retorno contextual.
- **Fora:** mudanças de tarefa, distribuição de carga, PDF e qualquer superfície familiar para Kids.

## 3. Estados e comportamento

| Superfície | Carregando | Vazio | Falha | Sem acesso |
|---|---|---|---|---|
| TEL-010 / TEL-040 | Esqueleto de checklist e progresso | “Sem tarefas para este dia” | “Não foi possível atualizar suas tarefas. Tente novamente.” | Não aplicável na sessão válida |
| TEL-050 | Esqueleto de indicador e membros | “Sem tarefas neste período” | “Não foi possível carregar a Família. Tente novamente.” | Ocultar para Kids; API nega |
| TEL-011 / TEL-032 | Esqueleto de lista | “Nenhuma tarefa encontrada” | “Não foi possível carregar as tarefas. Tente novamente.” | Retornar à origem sem expor dados |

- Datas fora de RN49 aparecem indisponíveis e não disparam consulta.
- Uma falha nunca usa a mensagem de vazio nem zera o progresso.
- Em Semana, anunciar e apresentar intervalo segunda–domingo, incluindo bordas efetivas.
- Após Kids sinalizar tarefa compartilhada, TEL-010 do adulto corresponsável anuncia “Pendente” no VoiceOver e TEL-040 Kids mostra “Aguardando confirmação”. A apresentação não altera o estado efetivo, a fila administrativa, o progresso ou as ações permitidas.
- No círculo da lista, a linha e o progresso mudam no toque. Toques seguintes registram a intenção mais recente enquanto o app envia um comando por vez para aquela tarefa. Uma recusa confirmada restaura o estado do servidor e abre um alerta; resposta incerta exige consulta antes de novo envio. A confirmação de missão continua obrigatória.

## 4. Microcopy localizável

| Chave | Texto-base em pt-BR |
|---|---|
| `tasks.personal.dailyProgress` | `Progresso de hoje` |
| `tasks.personal.completedCountFormat` | `N de M concluídas` |
| `tasks.personal.encouragement` | `Você consegue!` somente em TEL-010 |
| `tasks.personal.todaySectionFormat` / `dateSectionFormat` | `Hoje | N Tarefas` / `<data> | N Tarefas` |
| `tasks.personal.weightLow` / `weightMedium` / `weightHigh` | `P1 - Baixo Esforço` / `P2 - Médio Esforço` / `P3 - Alto Esforço` no checklist adulto |
| `tasks.personal.emptyDay` | `Sem tarefas para este dia` |
| `tasks.personal.noTasks` / `emptyHint` | `Sem tarefas` / `Tarefas atribuídas a você aparecem aqui.` |
| `tasks.personal.status.pending` | `Pendente` anunciado na lista do adulto corresponsável, sem rótulo visual no subtítulo de TEL-010 |
| `tasks.personal.status.awaitingConfirmation` | `Aguardando confirmação` na visualização Kids |
| `family.period.day` | `Dia` |
| `family.period.week` | `Semana` |
| `family.tasks.includeUnassigned` | `Incluir tarefas sem responsável` |
| `family.load.comingSoon` | Não exibir nesta entrega |
| `tasks.error.retry` | `Tentar novamente` |

Nenhum texto de interface embute título de tarefa em mensagem de erro ou acesso negado.

## 5. Acessibilidade

- Carrossel de data e seletor Dia/Semana são controles acessíveis por VoiceOver, com valor atual e limites anunciados.
- O carrossel pessoal preserva as sete posições de domingo a sábado ao mudar a seleção; dias fora de RN49 ficam indisponíveis. A paginação por semana não transforma a consulta pessoal em período semanal.
- O progresso expõe texto equivalente, por exemplo: “3 de 5 tarefas concluídas, 60%”.
- O estado da tarefa é anunciado com texto e ícone, sem depender apenas de cor. Em TEL-010, o subtítulo visual mostra responsáveis e esforço, enquanto o anúncio da linha inclui o estado apresentado ao perfil. O adulto não recebe anúncio de conclusão ou liberação de ação pela apresentação “Pendente” quando o estado efetivo aguarda confirmação. TEL-040 mantém o estado visível sob o título.
- Círculo e linha são botões distintos: o círculo anuncia Concluir/Reabrir somente quando permitido; a linha anuncia Abrir detalhe. Após a ação, foco segue para o estado atualizado.
- Durante a gravação, o círculo continua acionável quando o perfil tem permissão para a próxima transição; o estado e o progresso anunciados refletem a intenção atual. Falha leva o foco ao alerta e depois ao estado reconciliado.
- Filtros possuem rótulo, estado selecionado e alvo de toque adequado; não dependem apenas de cor.
- Ao trocar período, foco segue para o cabeçalho atualizado; ao falhar, segue para a mensagem de erro e ação de nova tentativa.

## 6. Critérios UX verificáveis

- TEL-010 e TEL-040 não exibem Semana.
- TEL-010 mostra apenas tarefas em que o adulto é responsável ou corresponsável; tarefas sem sua responsabilidade continuam na consulta familiar adulta.
- Tarefa compartilhada sinalizada por Kids anuncia “Pendente” no VoiceOver do checklist pessoal do adulto corresponsável e mostra “Aguardando confirmação” no checklist Kids, sem mudar progresso nem permissões.
- TEL-050, TEL-011 e TEL-032 exibem Dia/Semana apenas para adultos.
- O retorno de TEL-032 e TEL-011 restaura filtros e período da origem.
- O estado de falha é visual e semanticamente diferente do estado vazio.
- Kids não encontram entrada navegável para Família.
- TEL-010 mostra responsáveis e P1/P2/P3, barra com contagem por extenso, incentivo e cabeçalho datado acima dos cartões; remove o título central e o status textual do subtítulo adulto.

## 7. Checklist de aprovação

- [x] Jornada, superfícies e estados definidos.
- [x] Microcopy localizável e requisitos de acessibilidade definidos.
- [x] Decisão de carga adiada para SPEC-018 refletida.
- [x] Revisão de 2026-10-19 aprovada; aprovação anterior de 2026-10-06 preservada no histórico.
