# UX Spec 016: Acompanhar missões e recompensas

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-10  
**Revisada em:** 2026-11-08 — anatomia gamificada aprovada pela pessoa usuária ([Figma 579-59](https://www.figma.com/design/CuxXOp9tKivMbELeeB6mHw/APP-FAM%C3%8DLIA-%7C-C18?node-id=579-59))  
**Spec funcional vinculada:** [SPEC-016-acompanhar-missoes-recompensas.md](SPEC-016-acompanhar-missoes-recompensas.md)  
**Base funcional:** 1.15  
**Superfícies de interface:** TEL-020, TEL-021, UF-10

## 1. Objetivo da experiência e jornada

- **Visão da experiência:** cada pessoa da família acompanha uma conquista coletiva sem precisar calcular o progresso. Ao concluir, entende se a recompensa ainda pode ser resgatada ou qual item já foi aceito.
- **Perfis atendidos:** Administrador e Membro consultam progresso, participações e recompensa; Kids consulta a mesma conquista em linguagem direta, com recompensa aceita visível e sem dados de participação ou ações administrativas.

## 2. Rastreabilidade complementar de design

| Referência | Código / documento |
|---|---|
| Spec funcional | `SPEC-016-acompanhar-missoes-recompensas.md` |
| Telas | TEL-020, TEL-021 |
| Fluxo | UF-10 |
| Design consultado | `docs/design/screen-map.md`, `docs/design/user-flows.md` |
| Protótipo de média fidelidade | [Figma 579-59 — Gamificada · Missões (TEL-020 · TEL-021)](https://www.figma.com/design/CuxXOp9tKivMbELeeB6mHw/APP-FAM%C3%8DLIA-%7C-C18?node-id=579-59) |

## 3. Escopo da experiência

- **Dentro:** listas em andamento/concluídas, cartões com progresso, detalhe de missão com trilha de tarefas, estados de resgate e recompensa aceita, atualização e falhas recuperáveis.
- **Fora:** editor de missão, seleção de tarefas, catálogo de itens, roleta, aceite de recompensa, perfil de badges e reabertura. O botão “Resgatar recompensa” do protótipo pertence à UX-017. A tela de celebração “Missão concluída!” do protótipo é uma superfície nova, marcada como lacuna no próprio Figma, e não faz parte desta entrega (SPEC-016 E-03).

## 4. Jornada, navegação e contexto

| Origem | Ação | Destino | Retorno | Contexto preservado |
|---|---|---|---|---|
| Navegação adulta ou tab Kids | Abrir “Missões e conquistas” | TEL-020 | Trocar de aba/voltar | Último grupo e posição da lista após abrir detalhe |
| TEL-020 | Tocar em uma missão | TEL-021 | Voltar | Mantém lista e rolagem; atualiza o cartão se o detalhe tiver sido recarregado |
| TEL-021 | Atualizar | TEL-021 | — | Conteúdo confirmado continua visível durante `Refreshing` |

Não há formulário nesta entrega. Se a consulta falhar, a pessoa pode tentar novamente sem perder o conteúdo já confirmado.

TEL-020 é a única rota desta UX com barra de abas. TEL-021 e as telas abertas a partir dela (TEL-012, TEL-041, TEL-022, TEL-023) ocultam a barra de abas e retornam à origem por Voltar (UX-08).

## 5. Superfícies

### 5.1. TEL-020 — Missões e conquistas

- **Faixa de destaque:** título “Missões da família”, resumo coletivo e ilustração da família (placeholder no protótipo). Adultos veem “N em andamento · M concluídas”. Kids veem “Vocês já concluíram M missões juntos!”, oculto enquanto M for 0. Os atalhos de itens de recompensa e “Nova missão” aparecem somente para Administrador (SPEC-014/SPEC-015); Kids têm o avatar de acesso ao perfil.
- **Seções:** cabeçalhos “EM ANDAMENTO” e “CONCLUÍDAS” em caixa alta; seção sem missões não é exibida.
- **Cartão de missão:** título; barra de progresso grossa com a contagem “x / y” dentro da parte preenchida, sem preenchimento em 0%; baú à direita; rodapé com “N tarefas faltam” na missão em andamento ou a situação da recompensa na concluída, seguido de chevron. O cartão inteiro abre TEL-021.
- **Baú:** fechado na missão em andamento; fechado com destaque na concluída sem aceite; aberto quando há recompensa aceita. É decorativo: a situação sempre aparece em texto.
- **Estado concluído:** o rodapé mostra “Recompensa pronta para resgate” a Administrador e Membro quando não houver aceite e “Recompensa escolhida: [item]” a todos os perfis quando existir, sem oferecer ação de resgate. Kids veem “Nenhuma recompensa foi escolhida ainda.” enquanto não houver aceite (UX-05).
- **Por perfil:** Kids tem barra de 24 pt, alvos de toque ampliados e nenhum botão de gestão. Os cartões não exibem avatares de participação (UX-09).

### 5.2. TEL-021 — Detalhe da missão

- **Faixa da missão:** título, “N tarefas para abrir o baú” na missão em andamento ou “Missão concluída!” na concluída, e a barra “x / y”.
- **Observação:** em cartão próprio, quando houver.
- **Trilha:** tarefas vinculadas como nós de ao menos 72 pt em zigue-zague, ligados por um caminho pontilhado que termina no baú (fechado ou aberto, como em TEL-020). Ícone do nó: check em nó preenchido para concluída, estrela para pendente e relógio para aguardando confirmação, de modo que esta nunca pareça concluída. Abaixo do título aparece somente o estado da tarefa (UX-09).
- **Tarefa do titular:** recebe balão “SUA TAREFA” para adultos e “SUA VEZ!” para Kids, com contorno no nó (UX-04).
- **Recompensa:** cartão exibido em missão concluída. Com aceite, mostra o título do item em todos os perfis; sem aceite, explica o estado verdadeiro. A ação de resgate não é exibida nesta spec; ela será introduzida pela UX-017 apenas para Administrador.
- **Quem já ajudou:** Administrador e Membro veem, em missão concluída, avatares de iniciais e os nomes das participações registradas. Kids não vê o bloco nem uma contagem substituta.
- **Tarefas:** adultos seguem para TEL-012 a partir de qualquer nó; Kids só pode abrir tarefa própria em TEL-041. Tarefa de outro membro não vira caminho operacional.

## 6. Estados de interface

| Estado | TEL-020 | TEL-021 | Ação |
|---|---|---|---|
| `Loading` | Esqueleto de cartões | Esqueleto da faixa, da barra e das tarefas | Bloqueia interação de conteúdo incompleto |
| `Empty` | Faixa de destaque, “Nenhuma missão por aqui” e orientação para Admin | Não aplicável | Admin pode usar a criação já autorizada |
| `Content` | Faixa, seções e cartões canônicos | Faixa, trilha e blocos autorizados | Navegar, atualizar e voltar |
| `Refreshing` | Indicador nativo preservando cartões | Indicador discreto preservando conteúdo | Rolagem continua disponível |
| `Error` inicial | Mensagem e “Tentar novamente” | Mensagem e “Tentar novamente” | Nova consulta |
| `Error` não bloqueante | Banner sem apagar conteúdo | Banner sem apagar conteúdo | Nova consulta |

## 7. Microcopy e i18n

As chaves abaixo são as usadas pelo aplicativo. Textos com quantidade têm variantes de singular e plural no catálogo.

| Elemento | Chave | Texto pt-BR | Uso |
|---|---|---|---|
| Título de navegação | `missions.list.title` | “Missões e conquistas” | Aba, VoiceOver e Voltar das telas empurradas |
| Título da faixa | `missions.hero.title` | “Missões da família” | TEL-020 |
| Resumo adulto | `missions.hero.summary` | “{{inProgress}} em andamento · {{completed}} concluída(s)” | TEL-020, Admin e Membro |
| Resumo Kids | `missions.hero.kids_summary` | “Vocês já concluíram {{completed}} missão/missões juntos!” | TEL-020, Kids; oculto com 0 |
| Seção em andamento | `missions.section.in_progress` | “Em andamento” | Cabeçalho de seção |
| Seção concluídas | `missions.section.completed` | “Concluídas” | Cabeçalho de seção |
| Em andamento | `missions.status.in_progress` | “Em andamento” | Estado `inProgress` anunciado |
| Concluída | `missions.status.completed` | “Concluída” | Estado `completed` anunciado |
| Estado vazio | `missions.list.empty_title` | “Nenhuma missão por aqui” | Sem missões |
| Estado vazio Admin | `missions.list.empty_description` | “Crie uma missão para transformar tarefas em uma conquista da família.” | Admin |
| Progresso visível | `mission.progress.short` | “{{completed}} / {{total}}” | Barra no cartão e na faixa |
| Progresso acessível | `mission.progress` | “{{completed}} de {{total}} tarefas concluídas ({{percent}}%)” | VoiceOver do cartão e da faixa |
| Tarefas restantes | `mission.tasks_remaining` | “{{n}} tarefa falta” / “{{n}} tarefas faltam” | Rodapé do cartão em andamento |
| Faixa em andamento | `mission.banner.remaining` | “{{n}} tarefa para abrir o baú” / “{{n}} tarefas para abrir o baú” | TEL-021 |
| Faixa concluída | `mission.banner.completed` | “Missão concluída!” | TEL-021 |
| Resgate disponível | `mission.reward.available` | “Recompensa pronta para resgate” | Concluída sem aceite, Admin e Membro |
| Recompensa aceita | `mission.reward.accepted` | “Recompensa escolhida: {{title}}” | Todos os perfis, com aceite |
| Sem recompensa | `mission.reward.none` | “Nenhuma recompensa foi escolhida ainda.” | Sem aceite; Kids também em concluída |
| Balão adulto | `missions.trail.own_task` | “SUA TAREFA” | Tarefa do titular adulto |
| Balão Kids | `missions.trail.own_task_kids` | “SUA VEZ!” | Tarefa do titular Kids |
| Participações | `missions.detail.participations_title` | “Quem já ajudou” | TEL-021, Admin e Membro |
| Falha | `mission.load.error` | “Não foi possível atualizar esta missão. Tente novamente.” | Falha de consulta |

## 8. Acessibilidade e adaptação

- A barra mostra “x / y”, mas o VoiceOver anuncia fração e percentual juntos (“1 de 4 tarefas concluídas (25%)”) (UX-07). O percentual exibido é arredondado para baixo (UX-06). Cor e forma não são a única indicação de estado.
- O rótulo do cartão reúne título, estado, progresso e rodapé. O rótulo do nó reúne título da tarefa, estado e o balão, quando houver.
- Baú e ilustração são decorativos e ocultos do VoiceOver; o estado correspondente está sempre em texto.
- Ordem de foco no detalhe: voltar → título/status → observação → progresso → tarefas → recompensa → participações, quando autorizadas.
- Recompensa aceita recebe rótulo acessível com título e estado, não apenas ícone.
- Dynamic Type não trunca títulos, observações ou nomes de recompensa.
- Alvos de toque têm ao menos 44×44 pt; nas superfícies Kids, cartões e ações principais têm ao menos 56×56 pt. Nós da trilha têm ao menos 72 pt.
- iPhone usa lista de coluna única; iPad preserva a hierarquia em `NavigationSplitView` sem ocultar informação autorizada.

## 9. Decisões e esclarecimentos de UX

| # | Decisão | Situação | Impacto |
|---|---|---|---|
| UX-01 | Kids visualizam recompensa aceita, em concordância com RF36; participações e resgate permanecem ocultos. | Decidida pela pessoa usuária em 2026-10-10 | Atualizou `screen-map.md`, `user-flows.md` e SPEC-014. |
| UX-02 | A ausência de aceite comunica disponibilidade/ausência de recompensa sem simular uma ação de resgate antes de UX-017. | Proposta | Não altera regra de domínio. |
| UX-03 | A proposta gamificada do Figma 579-59 é a referência de média fidelidade de TEL-020/TEL-021. | Decidida pela pessoa usuária em 2026-11-08 | Revisa §5–§8. A etiqueta “aguardando revisão” do quadro será atualizada pela responsável por UX. |
| UX-04 | A tarefa do titular é identificada pela consulta individual da tarefa, porque o detalhe da missão não traz responsáveis. Ela recebe o balão para adultos e Kids e define quais tarefas Kids podem abrir. Se a consulta falhar, nenhum balão aparece, as tarefas ficam sem toque para Kids e continuam abríveis para adultos. | Decidida pela pessoa usuária em 2026-11-08 | Apresentação; não altera permissão nem contrato. |
| UX-05 | Kids veem “Nenhuma recompensa foi escolhida ainda.” em missão concluída sem aceite, porque a projeção Kids não traz a situação de resgate. | Decidida pela pessoa usuária em 2026-11-08 | O cartão Kids do Figma 579-59 diverge neste ponto e deve ser ajustado por UX. |
| UX-06 | O percentual exibido é arredondado para baixo, para nunca mostrar 100% antes da conclusão. | Decidida pela pessoa usuária em 2026-11-08 | Apresentação; o valor canônico continua vindo do servidor. |
| UX-07 | A barra exibe somente “x / y”; o percentual permanece no anúncio do VoiceOver. | Decidida pela pessoa usuária em 2026-11-08 | Substitui o uso visível de `mission.progress`. |
| UX-08 | A barra de abas aparece somente nas telas principais; telas abertas por push a ocultam. | Decidida pela pessoa usuária em 2026-11-08 | Regra geral registrada no `screen-map.md` 1.24. |
| UX-09 | Avatares de participação nos cartões da lista e data/responsável por tarefa na trilha ficam fora, porque o contrato da SPEC-016 não os expõe. | Decidida pela pessoa usuária em 2026-11-08 | Lacuna registrada em SPEC-016 E-02. |

## 10. Checklist de aprovação

- [x] Vinculada à SPEC-016 e às superfícies existentes.
- [x] Estados de carga, vazio, atualização e falha descritos.
- [x] Projeção Kids alinhada a RF36.
- [x] Microcopy e acessibilidade especificadas.
- [x] Revisada e aprovada explicitamente com a SPEC funcional em 2026-10-10.
- [x] Anatomia gamificada (Figma 579-59) aprovada explicitamente em 2026-11-08.
