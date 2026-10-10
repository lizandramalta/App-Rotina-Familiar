# UX Spec 017: Resgatar recompensa da missão

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Usuária | **Em:** 2026-10-10  
**Spec funcional vinculada:** [SPEC-017-resgatar-recompensa.md](SPEC-017-resgatar-recompensa.md)  
**Base funcional:** 1.15  
**Superfícies de interface:** TEL-021, TEL-023, TEL-024, UF-11

## 1. Objetivo da experiência e jornada

O Administrador escolhe uma recompensa coletiva ao fim de uma missão sem confundir sorteio local com aceite salvo. A família vê o resultado confirmado no detalhe da missão; somente o Administrador opera a roleta.

## 2. Rastreabilidade complementar

| Referência | Código ou documento |
|---|---|
| Spec funcional | SPEC-017 |
| Caso, regras e requisitos | UC16; RN42–43, RN52–53; RF35, RF51–53 |
| Design | TEL-021, TEL-023, TEL-024, UF-11 |
| Documentos | `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-feature-catalog.md` |

## 3. Escopo da experiência

- **Inclui:** entrada autorizada de TEL-021, catálogo e resultado local, novo sorteio, aceite, saída sem aceite, retorno ao detalhe e recuperação de falhas.
- **Não inclui:** cadastrar item (UX-015), editar missão, reabrir tarefa ou expor roleta a Membro/Kids.

## 4. Jornada e preservação de contexto

| Origem | Ação | Destino | Retorno | Contexto preservado |
|---|---|---|---|---|
| TEL-021 | Admin toca em “Resgatar recompensa” | TEL-024 | Voltar/sair | Detalhe e posição de rolagem |
| TEL-024 | Consultar itens | TEL-023 | Voltar | Resultado local atual e catálogo carregado |
| TEL-024 | Aceitar com confirmação | TEL-021 | Automático | Detalhe recarregado com recompensa aceita |
| TEL-024 | Sair sem aceitar | TEL-021 | Voltar | Missão permanece concluída e resgatável |

## 5. Superfícies

### 5.1 TEL-021 — Detalhe da missão

Para Administrador, missão concluída sem aceite mostra a ação “Resgatar recompensa”. Membro e Kids veem apenas a situação de resgate; não recebem botão desabilitado nem rota alternativa. Após aceite confirmado, todos veem o bloco de recompensa aceita da UX-016.

### 5.2 TEL-024 — Roleta da missão

- **Hierarquia:** voltar, título “Escolher recompensa”, contexto da missão, roleta/resultado, instrução de que o sorteio ainda não está salvo e ações.
- **Antes de sortear:** ação primária “Sortear recompensa”; o catálogo vem de `GET /reward-items`.
- **Resultado local:** anuncia o título e a descrição quando existir; ações “Sortear novamente”, “Aceitar recompensa” e “Sair sem aceitar”.
- **Aceite:** durante envio, desabilita ações duplicadas e mostra “Confirmando recompensa…”. Só navega após `200` confirmado.
- **Consultar itens:** abre TEL-023 em modo consulta e retorna à roleta; adicionar item permanece fora desta jornada e não altera o resultado já exibido.

## 6. Estados de interface

| Estado | Apresentação e ação |
|---|---|
| `Loading` | Skeleton/contexto; controles de sorteio indisponíveis até catálogo e permissão confirmados |
| `Ready` | Ação “Sortear recompensa” disponível |
| `Result` | Resultado local explícito como não confirmado; permite novo sorteio, aceite ou saída |
| `Submitting` | Resultado visível, controles bloqueados e progresso anunciado |
| `AlreadyAccepted` | Fecha/recarrega TEL-021 e informa que a recompensa já foi escolhida |
| `Unavailable` | Fecha/recarrega TEL-021 e informa que o resgate não está mais disponível |
| `Error` | Mantém último resultado local; informa falha e permite consultar a missão antes de nova tentativa |
| `Uncertain` | Não afirma aceite; ação “Atualizar missão” consulta TEL-021 |

## 7. Microcopy e localização

| Chave | Texto pt-BR | Uso |
|---|---|---|
| `mission.reward.redeem` | Resgatar recompensa | Entrada em TEL-021 Admin |
| `reward.wheel.title` | Escolher recompensa | Título TEL-024 |
| `reward.wheel.draw` | Sortear recompensa | Primeiro sorteio |
| `reward.wheel.draw_again` | Sortear novamente | Recusa do resultado local |
| `reward.wheel.accept` | Aceitar recompensa | Confirmação remota |
| `reward.wheel.exit` | Sair sem aceitar | Saída segura |
| `reward.wheel.pending` | Esta recompensa ainda não foi confirmada. | Resultado local |
| `reward.wheel.submitting` | Confirmando recompensa… | Envio |
| `reward.wheel.already_accepted` | Esta missão já teve uma recompensa escolhida. | Conflito concorrente |
| `reward.wheel.unavailable` | O resgate desta missão não está disponível agora. | Estado inválido |
| `reward.wheel.uncertain` | Ainda estamos confirmando a recompensa escolhida. | Resposta perdida |
| `reward.wheel.refresh_mission` | Atualizar missão | Reconciliação |

## 8. Acessibilidade e adaptação

- Resultado, status não confirmado e confirmação remota são anunciados por VoiceOver; cor ou animação não são a única indicação.
- Controles têm rótulo, estado e alvo de toque mínimo de 44×44 pt; foco vai ao resultado após sorteio e ao banner após falha/conflito.
- `Reduce Motion` reduz a animação da roleta sem eliminar a seleção nem as ações.
- iPhone usa uma coluna; iPad preserva contexto da missão e ações em layout adaptativo sem ocultar estado ou descrição.

## 9. Critérios de aceite UX

| ID | Critério |
|---|---|
| UX-CA-01 | Somente Administrador de missão concluída sem aceite visualiza a entrada e TEL-024. |
| UX-CA-02 | Resultado de sorteio deixa claro que não foi salvo e permite sortear de novo ou sair sem efeitos. |
| UX-CA-03 | Aceite bloqueia duplicidade e só atualiza a missão após confirmação remota. |
| UX-CA-04 | Conflito, indisponibilidade e resposta incerta levam à consulta do detalhe, sem alegar aceite. |
| UX-CA-05 | A experiência é navegável por tecnologia assistiva e respeita Reduce Motion e adaptação iPhone/iPad. |

## 10. Checklist de aprovação

- [x] Fluxo, estados, microcopy e acessibilidade definidos.
- [x] Permissões visuais alinhadas à SPEC-017 e à UX-016.
- [x] Revisão e aprovação explícita junto da SPEC funcional em 2026-10-10.
