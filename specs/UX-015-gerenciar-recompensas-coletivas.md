# UX Spec 015: Gerenciar recompensas coletivas

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Usuária | **Em:** 2026-10-10  
**Spec funcional vinculada:** [SPEC-015-gerenciar-recompensas-coletivas.md](SPEC-015-gerenciar-recompensas-coletivas.md)  
**Base funcional:** 1.15  
**Superfícies:** TEL-023, MOD-008, UF-11

## 1. Objetivo da experiência

O Administrador consulta rapidamente o que pode entrar na roleta e cadastra uma recompensa coletiva sem confundir esse ato com sorteio ou resgate. A experiência preserva a origem da navegação e torna erros de formulário fáceis de corrigir.

## 2. Rastreabilidade

| Referência | Código ou documento |
|---|---|
| Spec funcional | SPEC-015 |
| Casos e regras | UC06; RN41–42; RF33–34 |
| Design | TEL-023, MOD-008, UF-11 |
| Documentos | `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-feature-catalog.md` |

## 3. Escopo da experiência

- **Inclui:** consulta de itens predefinidos e personalizados, abertura/cancelamento do cadastro, título, descrição, validações e atualizações após salvar.
- **Não inclui:** editar/excluir itens, sorteio, aceite ou visualização por Membro/Kids.
- **Acesso visual:** somente Administrador enxerga TEL-023 e a ação de adicionar; Membro/Kids não recebem atalho nem botão desabilitado.

## 4. Navegação e contexto

| Origem | Ação | Destino | Retorno | Estado preservado |
|---|---|---|---|---|
| TEL-020 | Abrir itens de recompensa | TEL-023 | Voltar | Lista de missões e sua posição |
| TEL-024 | Consultar itens | TEL-023 | Voltar | Estado atual da roleta, sem resultado persistido |
| TEL-023 | Tocar em “Adicionar item” | MOD-008 | Cancelar/fechar | Lista e posição de rolagem |
| MOD-008 | Salvar com sucesso | TEL-023 | Fechamento automático | Lista atualizada com o novo item |

Cancelar sem alterações fecha imediatamente. Se houver título ou descrição digitados, fechar o modal solicita confirmação de descarte; nenhum dado é salvo. Falha de validação, rede ou duplicidade mantém os valores digitados e o foco no primeiro campo com erro.

## 5. Superfícies

### 5.1 TEL-023 — Itens de recompensa

- **Hierarquia:** título “Itens de recompensa”, texto curto explicando que os itens entram nos próximos sorteios, seção “Sugestões para a família”, seção “Itens da sua família” e ação primária “Adicionar item”.
- **Cartão de item:** título; descrição abaixo somente quando existir; selo textual “Sugestão” ou “Da sua família”. A origem nunca depende apenas de cor.
- **Lista personalizada vazia:** a seção mostra “Ainda não há itens personalizados. Você pode adicionar uma recompensa para os próximos sorteios.” Os predefinidos continuam visíveis; portanto, não é uma tela vazia total.
- **Atualização:** pull-to-refresh conserva o conteúdo atual enquanto atualiza. Após cadastro confirmado, o item aparece na seção da família sem afirmar que uma missão foi alterada.

### 5.2 MOD-008 — Adicionar item

- **Cabeçalho:** “Adicionar recompensa”; fechar/cancelar à esquerda.
- **Campo título:** obrigatório, placeholder “Ex.: Noite de pizza”. Exibe contador que considera somente caracteres não-espaço após `trim`, no formato `{{current}}/60`.
- **Campo descrição:** opcional, multiline, placeholder “Ex.: Escolher juntos o sabor e o filme”. Exibe `{{current}}/255`, contando espaços.
- **Ação primária:** “Adicionar item”. Fica disponível quando o título local não está vazio após `trim`; o backend continua sendo a autoridade para todas as validações.
- **Texto de apoio:** “Este item ficará disponível nos próximos sorteios. Ele não será vinculado a uma missão agora.”

## 6. Estados de interface

| Estado | TEL-023 | MOD-008 |
|---|---|---|
| Carregando | Skeleton das duas seções; ação de adicionar oculta até haver permissão confirmada | Não aplicável |
| Conteúdo | Predefinidos e personalizados agrupados | Campos editáveis |
| Atualizando | Indicador discreto, conteúdo permanece visível | Não aplicável |
| Sem personalizados | Predefinidos + orientação e ação de adicionar | Não aplicável |
| Enviando | Não aplicável | Botão mostra “Adicionando…”, campos e fechamento bloqueados para evitar envio duplicado |
| Erro de validação | Não aplicável | Mensagem inline no campo; rascunho preservado |
| Título duplicado | Não aplicável | Banner e erro no título; rascunho preservado |
| Falha de carga | Mensagem com “Tentar novamente”; não apresentar como lista vazia | Não aplicável |
| Resultado incerto | Banner “Ainda estamos confirmando se o item foi adicionado.” com ação “Atualizar lista” | Modal fecha para a lista e não declara sucesso |

## 7. Microcopy e localização

| Chave | Texto pt-BR | Uso |
|---|---|---|
| `rewards.items.title` | Itens de recompensa | Título da TEL-023 |
| `rewards.items.add` | Adicionar item | Ação primária |
| `rewards.items.custom.empty` | Ainda não há itens personalizados. | Seção personalizada vazia |
| `rewards.editor.title` | Adicionar recompensa | Cabeçalho do MOD-008 |
| `rewards.editor.field.title` | Nome da recompensa | Rótulo do título |
| `rewards.editor.field.details` | Descrição opcional | Rótulo da descrição |
| `rewards.editor.helper` | Este item ficará disponível nos próximos sorteios. | Texto de apoio |
| `rewards.editor.error.title_required` | Informe o nome da recompensa. | Título vazio |
| `rewards.editor.error.title_too_long` | Use no máximo 60 caracteres, sem contar espaços. | Limite do título |
| `rewards.editor.error.title_duplicate` | Já existe uma recompensa com esse nome na sua família. | Duplicidade |
| `rewards.editor.error.details_too_long` | A descrição pode ter até 255 caracteres. | Limite da descrição |
| `rewards.editor.submitting` | Adicionando… | Envio em andamento |
| `rewards.items.uncertain` | Ainda estamos confirmando se o item foi adicionado. | Resultado incerto |

## 8. Acessibilidade

- Campos têm rótulos persistentes, instrução de obrigatoriedade e mensagens de erro associadas programaticamente.
- Contadores e selo de origem são lidos por tecnologias assistivas; cor não é a única indicação.
- A ação primária, cancelar e atualizar respeitam área mínima de toque e ordem lógica de foco.
- O foco é transferido ao primeiro erro após uma tentativa inválida e ao novo cartão após cadastro confirmado.

## 9. Critérios de aceite UX

| ID | Critério |
|---|---|
| UX-CA-01 | TEL-023 separa predefinidos e personalizados de forma textual e mantém a origem de abertura ao voltar. |
| UX-CA-02 | MOD-008 torna claro título obrigatório, descrição opcional e que cadastrar não resgata recompensa. |
| UX-CA-03 | Limites, duplicidade e falha de rede preservam o rascunho e fornecem orientação acessível. |
| UX-CA-04 | A interface só confirma o cadastro após retorno confirmado; resultado incerto orienta atualização da lista. |
| UX-CA-05 | Membro e Kids não visualizam ação ou caminho administrativo. |

## 10. Checklist de aprovação

- [x] Fluxo, navegação, estados, microcopy e acessibilidade definidos.
- [x] Sem conflito com SPEC-015 ou RN42/RF34/UC06.
- [x] UX-spec aprovada junto da SPEC funcional.
