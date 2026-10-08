# UX Spec 013: Validar conclusão de tarefa Kids

**Status:** rascunho

**Autor:** Codex | **Criada em:** 2026-10-08 | **Aprovada por:** | **Em:**

**Spec funcional vinculada:** [SPEC-013-validar-conclusao-kids.md](SPEC-013-validar-conclusao-kids.md)

**Base funcional:** 1.14

**Superfícies de interface:** TEL-015, TEL-016, UF-07 (ramo Administrador)

## 1. Objetivo da Experiência e Jornada do Usuário

- **Visão:** dar ao Administrador uma fila simples e tranquila para avaliar pendências Kids, sem expor fotos fora desse contexto e sem transformar uma decisão concorrente em erro para a família.
- **Perfis atendidos:** somente Administrador. Membro e Kids não veem ponto de entrada, fila, detalhe ou foto.

## 2. Rastreabilidade Complementar de Design

| Referência | Código / Documento |
|---|---|
| Spec funcional vinculada | `SPEC-013-validar-conclusao-kids.md` |
| Telas | TEL-015, TEL-016 |
| Fluxo | UF-07, ramo Administrador |
| Documentos consultados | `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-feature-catalog.md` |

## 3. Escopo da Experiência

- **Dentro do escopo:** entrada administrativa a partir de TEL-050; lista ordenada da pendência mais antiga; estado vazio; detalhe de uma sinalização corrente; foto opcional; confirmar/recusar; carregamento, falha e reconciliação silenciosa.
- **Fora do escopo:** sinalização e câmera Kids, conclusão manual, edição de tarefa, histórico navegável de avaliações, notificações e acesso de Membro/Kids.

## 4. Jornada, Navegação e Preservação de Contexto

| Origem | Ação | Destino | Retorno | Contexto preservado |
|---|---|---|---|---|
| TEL-050 | Abrir "Confirmações Kids" | TEL-015 | Voltar para Família | Período da origem permanece intacto |
| TEL-015 | Selecionar uma pendência | TEL-016 | Voltar sem decidir | Cursor/posição da fila e itens carregados |
| TEL-016 | Confirmar ou recusar com sucesso | TEL-015 | Retorno automático | Fila atualizada sem o item decidido |
| TEL-016 | Outra decisão/conclusão já ocorreu | TEL-015 | Retorno automático e silencioso | Fila atualizada; sem alerta de erro |

Voltar de TEL-016 sem decidir não altera a sinalização. Não há rascunho ou confirmação secundária: confirmar e recusar são ações finais explícitas. Após qualquer conclusão, a tela não oferece acesso a histórico.

## 5. Especificação de Superfícies

### 5.1. TEL-015 — Confirmações Kids

- **Cabeçalho:** título "Confirmações Kids" e voltar para TEL-050.
- **Lista:** itens em ordem crescente de data/hora de sinalização; cada item mostra título da tarefa, criança que sinalizou, tempo/data local e indicador textual/por ícone de foto opcional.
- **Estado vazio:** explica que não há tarefas aguardando avaliação; não sugere que Kids ou Membros possam agir.
- **Ação:** tocar no item abre TEL-016. Não há confirmar/recusar diretamente na lista.

### 5.2. TEL-016 — Avaliar sinalização

- **Cabeçalho:** voltar para a fila, sem menu de edição.
- **Conteúdo:** título/observação da tarefa quando existente, responsáveis, criança que sinalizou, data/hora e estado "Aguardando confirmação".
- **Foto:** quando disponível, preview acessível que abre visualização privada; quando ausente, texto "Nenhuma foto foi enviada" sem tom de falha.
- **Rodapé:** botão primário "Confirmar realização" e ação secundária destrutiva "Recusar". Ambos ficam indisponíveis durante o envio.
- **Resultado:** após resposta bem-sucedida, inclusive tardia (`applied: false`), retorna à fila atualizada sem alerta técnico.

## 6. Ciclo de Vida da Interface e Máquina de Estados

| ViewState | Condição | Ações | Resultado |
|---|---|---|---|
| `QueueLoading` | Entrada/atualização de TEL-015 | Voltar | Indicador de carregamento sem bloquear navegação |
| `QueueContent` | Há pendências | Abrir item | Navega para TEL-016 |
| `QueueEmpty` | Não há pendências | Voltar | Mensagem de estado vazio |
| `ReviewContent` | Sinalização corrente carregada | Confirmar, recusar, visualizar foto | Mantém contexto até resposta |
| `Submitting` | Decisão enviada | Nenhuma decisão adicional | Evita duplo toque |
| `Reconciled` | Resposta com `applied: false` | Nenhuma | Retorna silenciosamente à fila atualizada |
| `Error` | Falha de rede, sessão ou servidor | Tentar novamente ou voltar | Não anuncia sucesso nem descarta o contexto |
| `NotFound` | Item deixou de ser corrente antes de carregar | Voltar | Atualiza a fila, sem revelar histórico |

## 7. Interações, Microcopy e Chaves de Internacionalização (`i18n`)

| Elemento | Chave | Texto padrão (pt-BR) | Cenário |
|---|---|---|---|
| Título da fila | `kidsReview.queue.title` | "Confirmações Kids" | TEL-015 |
| Fila vazia | `kidsReview.queue.empty` | "Não há tarefas aguardando avaliação." | Sem pendências |
| Foto ausente | `kidsReview.detail.no_photo` | "Nenhuma foto foi enviada." | TEL-016 sem foto |
| Confirmar | `kidsReview.decision.confirm` | "Confirmar realização" | Decisão disponível |
| Recusar | `kidsReview.decision.reject` | "Recusar" | Decisão disponível |
| Enviando | `kidsReview.decision.submitting` | "Salvando..." | `Submitting` |
| Falha | `kidsReview.error.submit` | "Não foi possível salvar agora. Tente novamente." | Rede/servidor |
| Item atualizado | `kidsReview.reconciled` | "A fila foi atualizada." | Decisão ou conclusão concorrente; usar somente anúncio acessível, sem toast de erro |
| Item indisponível | `kidsReview.error.not_found` | "Essa confirmação não está mais pendente." | Carregamento de item removido da fila |

## 8. Acessibilidade e Adaptação de Dispositivo

- **VoiceOver:** ordem em TEL-015: voltar → título → estado vazio ou itens; em TEL-016: voltar → título → detalhes da tarefa → criança → foto/ausência de foto → confirmar → recusar. Botões anunciam a tarefa avaliada.
- **Dynamic Type:** títulos, responsáveis e ações expandem sem truncamento; a lista aumenta a altura das células.
- **Contraste:** estado e disponibilidade de foto usam texto e ícone, nunca apenas cor; ações confirmatória e destrutiva conservam contraste AA.
- **Toque:** ações principais com área mínima de 44×44 pt; não usar gesto oculto para decidir.
- **iPhone:** fila e detalhe em `NavigationStack` de coluna única. **iPad:** fila e detalhe podem usar `NavigationSplitView`; no layout compacto, preservam a pilha equivalente. Foto abre em sheet privada adaptada ao espaço.

## 9. Referências Visuais e Design Tokens

- Reutilizar `StatusBadge`, `ListRow`, `PrimaryButton`, `DestructiveButton`, `EmptyState` e visualizador privado de mídia.
- Tokens semânticos: `BackgroundPrimary`, `TextPrimary`, `ActionPrimary`, `SemanticDestructive` e `SemanticSuccess`; nenhuma foto ou estado pode depender de URL pública.

## 10. Decisões e Esclarecimentos de UX

| # | Decisão | Responsável / Data | Altera SPEC funcional ou docs? |
|---|---|---|---|
| UX-01 | Fila mostra pendências da mais antiga para a mais recente. | Pessoa usuária / 2026-10-08 | Sim — SPEC e contrato backend |
| UX-02 | Decisão já aplicada por outra ação retorna à fila de modo silencioso; não há erro nem segunda confirmação. | Pessoa usuária / 2026-10-08 | Sim — SPEC e contrato backend |
| UX-03 | Não há histórico navegável de avaliações no app. | Pessoa usuária / 2026-10-08 | Não |

## 11. Checklist de Aprovação da UX-Spec

- [x] Vinculada à SPEC-013 em rascunho.
- [x] TEL-015, TEL-016 e UF-07 existem na base de design.
- [x] Navegação, retorno, estados, microcopy e acessibilidade foram especificados.
- [x] iPhone e iPad foram considerados.
- [x] Decisões de concorrência e ausência de histórico foram refletidas sem alterar regras de domínio.
- [ ] Status `aprovada` autorizado explicitamente para esta UX-spec e SPEC-013.
