# UX Spec 016: Acompanhar missões e recompensas

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-10  
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

## 3. Escopo da experiência

- **Dentro:** listas em andamento/concluídas, cartões com progresso, detalhe de missão, estados de resgate e recompensa aceita, atualização e falhas recuperáveis.
- **Fora:** editor de missão, seleção de tarefas, catálogo de itens, roleta, aceite de recompensa, perfil de badges e reabertura.

## 4. Jornada, navegação e contexto

| Origem | Ação | Destino | Retorno | Contexto preservado |
|---|---|---|---|---|
| Navegação adulta ou tab Kids | Abrir “Missões e conquistas” | TEL-020 | Trocar de aba/voltar | Último grupo e posição da lista após abrir detalhe |
| TEL-020 | Tocar em uma missão | TEL-021 | Voltar | Mantém lista e rolagem; atualiza o cartão se o detalhe tiver sido recarregado |
| TEL-021 | Atualizar | TEL-021 | — | Conteúdo confirmado continua visível durante `Refreshing` |

Não há formulário nesta entrega. Se a consulta falhar, a pessoa pode tentar novamente sem perder o conteúdo já confirmado.

## 5. Superfícies

### 5.1. TEL-020 — Missões e conquistas

- **Anatomia:** título da aba; seções “Em andamento” e “Concluídas”; cartões com título, estado em texto/ícone, fração de tarefas e percentual; estado vazio.
- **Estado concluído:** mostra “Resgate disponível” quando não houver aceite e “Recompensa aceita” quando existir, sem afirmar que a pessoa pode resgatar.
- **Por perfil:** ação “Nova missão” mantém as permissões da SPEC-014. Kids tem alvos de toque ampliados e não recebe botão de gestão.

### 5.2. TEL-021 — Detalhe da missão

- **Anatomia:** cabeçalho com título e status; observação quando houver; progresso textual e visual; tarefas vinculadas com seus estados; bloco de recompensa; bloco de participações autorizado.
- **Recompensa:** em missão concluída com aceite, mostra o título do item em todos os perfis. Sem aceite, explica o estado verdadeiro. A ação de resgate não é exibida nesta spec; ela será introduzida pela UX-017 apenas para Administrador.
- **Participações:** Administrador e Membro veem as participações registradas. Kids não vê o bloco nem uma contagem substituta.
- **Tarefas:** adultos seguem para TEL-012; Kids só pode abrir tarefa própria em TEL-041. Tarefa de outro membro não vira caminho operacional.

## 6. Estados de interface

| Estado | TEL-020 | TEL-021 | Ação |
|---|---|---|---|
| `Loading` | Esqueleto de cartões | Esqueleto do cabeçalho e blocos | Bloqueia interação de conteúdo incompleto |
| `Empty` | Ilustração, “Ainda não há missões” e orientação para Admin | Não aplicável | Admin pode usar a criação já autorizada |
| `Content` | Seções e cartões canônicos | Dados, progresso e blocos autorizados | Navegar, atualizar e voltar |
| `Refreshing` | Indicador nativo preservando cartões | Indicador discreto preservando conteúdo | Rolagem continua disponível |
| `Error` inicial | Mensagem e “Tentar novamente” | Mensagem e “Tentar novamente” | Nova consulta |
| `Error` não bloqueante | Banner sem apagar conteúdo | Banner sem apagar conteúdo | Nova consulta |

## 7. Microcopy e i18n

| Elemento | Chave | Texto pt-BR | Uso |
|---|---|---|---|
| Título da lista | `missions.title` | “Missões e conquistas” | TEL-020 |
| Estado vazio | `missions.empty.title` | “Nenhuma missão por aqui” | Sem missões |
| Estado vazio Admin | `missions.empty.admin_hint` | “Crie uma missão para transformar tarefas em uma conquista da família.” | Admin |
| Em andamento | `mission.status.in_progress` | “Em andamento” | Estado `inProgress` |
| Concluída | `mission.status.completed` | “Concluída” | Estado `completed` |
| Progresso | `mission.progress` | “{{completed}} de {{total}} tarefas concluídas ({{percent}}%)” | Cartão e detalhe |
| Resgate disponível | `mission.reward.available` | “Recompensa pronta para resgate” | Concluída sem aceite |
| Recompensa aceita | `mission.reward.accepted` | “Recompensa escolhida: {{title}}” | Todos os perfis, com aceite |
| Sem recompensa | `mission.reward.none` | “Nenhuma recompensa foi escolhida ainda.” | Estado sem aceite |
| Falha | `mission.load.error` | “Não foi possível atualizar esta missão. Tente novamente.” | Falha de consulta |

## 8. Acessibilidade e adaptação

- Percentual e fração são anunciados juntos no VoiceOver; cor não é a única indicação de estado.
- Ordem de foco no detalhe: voltar → título/status → observação → progresso → tarefas → recompensa → participações, quando autorizadas.
- Recompensa aceita recebe rótulo acessível com título e estado, não apenas ícone.
- Dynamic Type não trunca títulos, observações ou nomes de recompensa.
- Alvos de toque têm ao menos 44×44 pt; nas superfícies Kids, cartões e ações principais têm ao menos 56×56 pt.
- iPhone usa lista de coluna única; iPad preserva a hierarquia em `NavigationSplitView` sem ocultar informação autorizada.

## 9. Decisões e esclarecimentos de UX

| # | Decisão | Situação | Impacto |
|---|---|---|---|
| UX-01 | Kids visualizam recompensa aceita, em concordância com RF36; participações e resgate permanecem ocultos. | Decidida pela pessoa usuária em 2026-10-10 | Atualizou `screen-map.md`, `user-flows.md` e SPEC-014. |
| UX-02 | A ausência de aceite comunica disponibilidade/ausência de recompensa sem simular uma ação de resgate antes de UX-017. | Proposta | Não altera regra de domínio. |

## 10. Checklist de aprovação

- [x] Vinculada à SPEC-016 e às superfícies existentes.
- [x] Estados de carga, vazio, atualização e falha descritos.
- [x] Projeção Kids alinhada a RF36.
- [x] Microcopy e acessibilidade especificadas.
- [x] Revisada e aprovada explicitamente com a SPEC funcional em 2026-10-10.
