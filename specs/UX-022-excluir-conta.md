# UX Spec 022: Excluir conta

**Status:** aprovada\
**Autor:** Claude | **Criada em:** 2026-11-16 | **Aprovada por:** Pessoa usuária | **Em:** 2026-11-17\
**Spec funcional vinculada:** [SPEC-022-excluir-conta.md](SPEC-022-excluir-conta.md)\
**Base funcional:** RN 1.28 / RF 1.27 / UC 1.27\
**Superfícies de interface:** TEL-001 (mensagens de retorno), TEL-030 (seção Conta), TEL-032 (ação administrativa Kids), TEL-058, MOD-015, UF-17

## 1. Objetivo da experiência e jornada do usuário

- **Visão da experiência:** a pessoa entende exatamente o que será apagado e o que permanece na família antes de excluir a própria conta, confirma de forma deliberada e sai do aplicativo com a certeza de que a exclusão foi concluída. O Criador entende que a exclusão apaga a família inteira e confirma digitando o nome da família.
- **Perfis atendidos:** Administradores, Membros e Kids, pelo próprio perfil; o Criador, com variante própria; Administradores, ao excluir a conta de um Kids a partir do detalhe do membro.

## 2. Rastreabilidade complementar de design

| Referência | Código / documento |
|---|---|
| Spec funcional vinculada | `SPEC-022-excluir-conta.md` |
| Telas e modais existentes/alterados | TEL-001, TEL-030, TEL-032 |
| Telas e modais novos | TEL-058 (Excluir conta), MOD-015 (Confirmar exclusão) |
| Fluxos de navegação | UF-17 |
| Documentos de design consultados | `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/design/design-system.md` |

*(Regras de negócio, casos de uso e permissões são herdados de SPEC-022.)*

## 3. Escopo da experiência

- **Dentro do escopo:** seção Conta no fim de TEL-030; TEL-058 nas variantes adulto não-Criador, Criador e Kids; folha da Apple quando o Criador não tem token guardado; MOD-015; retorno a TEL-001 com mensagem de sucesso; mensagem neutra de acesso encerrado; ação "Excluir conta e dados" em TEL-032 para Administrador com alvo Kids.
- **Fora do escopo:** demais blocos de TEL-030 (UX-006, UX-003); remoção de membro em TEL-032 e MOD-010 (UX-003); onboarding e login Apple (UX-001), que não mudam visualmente.

## 4. Jornada, navegação e preservação de contexto

| Origem | Gatilho | Destino | Apresentação | Retorno / cancelamento | Contexto |
|---|---|---|---|---|---|
| TEL-030 | Tocar em "Excluir conta" na seção Conta | TEL-058 | Push (iPhone) / form sheet (iPad) | Voltar retorna a TEL-030 | Nada é gravado |
| TEL-058 (não-Criador) | Tocar em "Excluir conta" | MOD-015 | Alerta destrutivo | Cancelar retorna a TEL-058 | — |
| TEL-058 (Criador) | Digitar o nome da família e tocar em "Excluir família e conta" | MOD-015 | Alerta destrutivo | Cancelar retorna a TEL-058 mantendo o texto digitado | O botão só habilita quando o texto coincide com o nome da família |
| MOD-015 | Confirmar | TEL-058 em `Submitting` | Spinner no botão; Voltar bloqueado | — | — |
| `Submitting` (Criador) | Servidor responde `APPLE_PROOF_REQUIRED` | Folha nativa Sign in with Apple | Sistema | Cancelar volta a TEL-058 em `Content`, sem erro | Mantém o nome digitado |
| Folha da Apple | Autenticação concluída | TEL-058 em `Submitting` | Reenvio automático da mesma exclusão com a prova | — | A prova Apple é usada uma única vez |
| `Submitting` | Exclusão confirmada | TEL-001 | Substituição da pilha | — | Credenciais locais apagadas; banner de sucesso |
| TEL-032 (Admin, alvo Kids) | Tocar em "Excluir conta e dados" | MOD-015 (variante Kids por Admin) | Alerta destrutivo | Cancelar retorna a TEL-032 | Período selecionado preservado |
| MOD-015 (Admin) | Confirmar com sucesso | TEL-050 | Pop | — | Lista recarregada sem o Kids; intervalo preservado |
| Qualquer tela | Renovação de sessão recebe `401` | TEL-001 | Substituição da pilha | — | Mensagem neutra de acesso encerrado |

- **Prevenção de perda:** não há formulário a preservar, exceto o nome digitado pelo Criador, mantido durante cancelamentos dentro do fluxo e descartado ao sair de TEL-058.
- **Sem desfazer:** nenhum texto sugere restauração.

## 5. Especificação de superfícies

### 5.1. TEL-030 — Meu perfil (seção Conta)

- Nova seção "Conta" no fim da tela, depois dos blocos existentes, com uma linha "Excluir conta" com ícone `trash` e texto na cor `Color.App.destructive`.
- Visível para todos os perfis. Para Kids, a linha usa o mesmo estilo dos demais itens Kids, com área de toque de 56 pt.

### 5.2. TEL-058 — Excluir conta

- **Barra superior:** título "Excluir conta" e Voltar.
- **Variante adulto não-Criador:**
  - Bloco "O que será apagado": nome, apelido, foto e acesso neste aparelho.
  - Bloco "O que continua na família": tarefas, conquistas e créditos já registrados, mostrados como "Membro removido".
  - Aviso de irreversibilidade com ícone `exclamationmark.triangle` e texto.
  - Botão destrutivo "Excluir conta" no rodapé fixo.
- **Variante Criador:**
  - Texto principal: a exclusão apaga a família {nome} inteira.
  - Lista de efeitos: todos os membros perdem o acesso; tarefas, missões, conquistas e fotos são apagadas; a Apple ID deixa de estar ligada ao app.
  - Aviso de irreversibilidade.
  - Campo de texto "Digite o nome da família para confirmar", sem autocorreção nem sugestões, com comparação após remover espaços nas extremidades e sensível a maiúsculas e acentos.
  - Botão destrutivo "Excluir família e conta", desabilitado até o texto coincidir.
- **Variante Kids:**
  - Frases curtas e diretas, sem jargão.
  - Mesmos blocos da variante adulta, com ilustração do design system Kids.
  - Botão destrutivo de 56 pt.
- **Componentes:** `PrimaryButton` em estilo destrutivo com spinner, `TextField` do design system, tokens `Color.App`, `Font.app`, `AppSpacing` e `AppRadius`.

### 5.3. MOD-015 — Confirmar exclusão

- Alerta nativo com título, mensagem curta e dois botões: "Cancelar" (`.cancel`) e "Excluir" (`.destructive`).
- Variantes: própria conta (adulto e Kids), Criador e Administrador excluindo a conta de um Kids (inclui o nome do Kids na mensagem).

### 5.4. TEL-032 — ação administrativa Kids

- No bloco de gestão, abaixo de "Remover membro", a ação "Excluir conta e dados" aparece somente para Administrador e somente quando o alvo é Kids.
- "Remover membro" continua igual (UX-003). A diferença de efeito é explicada em MOD-015.

### 5.5. TEL-001 — mensagens de retorno

- Após exclusão confirmada: banner de sucesso não bloqueante "Sua conta foi excluída."
- Após renovação recusada com `401` em sessão antes ativa: banner neutro "Seu acesso a esta família foi encerrado." O servidor não informa a causa (remoção, exclusão de conta, exclusão da família ou troca de aparelho), por isso a mesma mensagem vale para toda sessão revogada.

## 6. Ciclo de vida da interface

| Estado | Condição | O que se vê | Ações | Transição |
|---|---|---|---|---|
| `Content` | Abertura de TEL-058 | Variante do perfil | Voltar, digitar (Criador), excluir | — |
| `Offline` | Sem conectividade | Aviso discreto; botão de excluir desabilitado | Voltar | Reabilita ao reconectar |
| `Submitting` | Exclusão enviada | Spinner no botão; Voltar e campos desabilitados | Nenhuma | Sucesso, erro ou folha da Apple |
| `AppleReauth` | `APPLE_PROOF_REQUIRED` | Folha nativa da Apple | Autenticar ou cancelar | Cancelar volta a `Content` sem erro |
| `Error` (não bloqueante) | `APPLE_PROOF_INVALID`, `503` ou falha de rede com estado confirmado | Banner de erro em TEL-058 | Tentar de novo | Mantém o nome digitado |
| `Uncertain` | Resposta perdida | Spinner "Confirmando…" enquanto consulta a sessão | Nenhuma | `401` → sucesso; `200` → `Error` com nova tentativa |
| `Success` | `204` ou `401` na consulta | TEL-001 com banner | — | — |

## 7. Microcopy e chaves de internacionalização

| Elemento | Componente | Chave | Texto (pt-BR) | Cenário | Rastreabilidade |
|---|---|---|---|---|---|
| Seção | `Text` header | `account.section.title` | "Conta" | TEL-030 | CA-01 |
| Entrada | Linha destrutiva | `account.deletion.entry` | "Excluir conta" | TEL-030 | CA-01 |
| Título | `Text` | `account.deletion.title` | "Excluir conta" | TEL-058 | CA-01 |
| Apagado | `Text` | `account.deletion.member.deleted` | "Seu nome, apelido e foto serão apagados, e você perderá o acesso neste aparelho." | Não-Criador | CA-02 |
| Preservado | `Text` | `account.deletion.member.kept` | "Tarefas e conquistas já registradas continuam na família como “Membro removido”." | Não-Criador | CA-02 |
| Kids | `Text` | `account.deletion.kids.body` | "Sua conta vai sumir do app. Suas tarefas feitas continuam contando para a família." | Kids | CA-05 |
| Criador | `Text` | `account.deletion.creator.body` | "Você criou a família {familyName}. Excluir sua conta apaga a família inteira." | Criador | CA-12 |
| Efeitos | `Text` lista | `account.deletion.creator.effects` | "Todos os membros perdem o acesso. Tarefas, missões, conquistas e fotos são apagadas. Sua Apple ID deixa de estar ligada ao app." | Criador | CA-12 |
| Irreversível | `Text` com ícone | `account.deletion.irreversible` | "Essa ação não pode ser desfeita." | Todas | CA-01 |
| Campo | `TextField` label | `account.deletion.creator.confirm_label` | "Digite o nome da família para confirmar" | Criador | E-08 |
| Botão | `PrimaryButton` | `account.deletion.button` | "Excluir conta" | Não-Criador | CA-01 |
| Botão | `PrimaryButton` | `account.deletion.creator.button` | "Excluir família e conta" | Criador | CA-12 |
| Enviando | `PrimaryButton` | `account.deletion.submitting` | "Excluindo…" | `Submitting` | CA-01 |
| Confirmando | `Text` | `account.deletion.confirming` | "Confirmando…" | `Uncertain` | CA-08 |
| Alerta | `Alert` título | `account.deletion.confirm.title` | "Excluir sua conta definitivamente?" | MOD-015 | CA-01 |
| Alerta Criador | `Alert` título | `account.deletion.confirm.creator_title` | "Excluir a família {familyName}?" | MOD-015 | CA-12 |
| Alerta Admin | `Alert` título | `account.deletion.confirm.kids_title` | "Excluir a conta de {name}?" | MOD-015 | CA-16 |
| Alerta Admin | `Alert` mensagem | `account.deletion.confirm.kids_message` | "Nome, apelido e foto serão apagados. As tarefas feitas continuam na família como “Membro removido”." | MOD-015 | CA-16 |
| Confirmar | `Alert` botão | `account.deletion.confirm.action` | "Excluir" | MOD-015 | CA-01 |
| Cancelar | `Alert` botão | `account.common.cancel` | "Cancelar" | MOD-015 | — |
| Ação Admin | Botão em TEL-032 | `family.members.delete_account` | "Excluir conta e dados" | TEL-032 | CA-16 |
| Sucesso | Banner | `account.deletion.success` | "Sua conta foi excluída." | TEL-001 | CA-09 |
| Encerrado | Banner | `account.ended.body` | "Seu acesso a esta família foi encerrado." | TEL-001 | CA-20 |
| Erro geral | Banner | `account.deletion.error.generic` | "Não foi possível excluir agora. Tente novamente." | `Error` | CA-08 |
| Erro Apple | Banner | `account.deletion.error.apple` | "Não conseguimos confirmar com a Apple. Tente novamente." | `APPLE_PROOF_INVALID` | CA-11 |
| Rede | Aviso | `account.common.error_network` | "Não foi possível conectar. Verifique sua internet." | `Offline` / falha de rede | CA-08 |
| Bloco apagado | `Label` | `account.deletion.member.deleted_title` | "O que será apagado" | Não-Criador | CA-02 |
| Bloco mantido | `Label` | `account.deletion.member.kept_title` | "O que continua na família" | Não-Criador | CA-02 |
| Bloco Kids | `Label` | `account.deletion.kids.title` | "Sua conta vai sumir" | Kids | CA-05 |
| Bloco Criador | `Label` | `account.deletion.creator.title` | "A família inteira será apagada" | Criador | CA-12 |
| Bloco efeitos | `Label` | `account.deletion.creator.effects_title` | "O que acontece" | Criador | CA-12 |
| Dica entrada | Accessibility hint | `account.deletion.entry_hint` | "Abre as informações sobre a exclusão da conta" | TEL-030 | — |
| Dica botão | Accessibility hint | `account.deletion.button_hint` | "Abre a confirmação final" | TEL-058 | — |
| Fechar aviso | Botão | `account.notice.dismiss` | "Fechar aviso" | TEL-001 | CA-09/CA-20 |

## 8. Acessibilidade e adaptação de dispositivo

- **VoiceOver:** ordem Voltar → título → blocos de efeito → aviso → campo (Criador) → botão. O botão de excluir tem a dica "Abre a confirmação final". O banner de TEL-001 é anunciado ao aparecer. O aviso de irreversibilidade é lido como texto, não apenas como ícone.
- **Dynamic Type:** todos os tamanhos, incluindo acessibilidade; a lista de efeitos quebra em várias linhas sem truncar.
- **Não depender de cor:** ações destrutivas combinam `Color.App.destructive` com ícone e texto explícito.
- **Área de toque:** 44×44 pt; 56×56 pt no Kids.
- **iPad:** TEL-058 em form sheet centralizado com largura máxima de 540 pt; MOD-015 permanece alerta nativo.

## 9. Referências visuais e design tokens

- **Wireframes e protótipos:** a criar com `/desenvolver-card-ux` após o planejamento no Jira.
- **Tokens:** `Color.App.destructive` para ações destrutivas, demais cores, `Font.app`, `AppSpacing` e `AppRadius` conforme `docs/design/design-system.md`.

## 10. Decisões e esclarecimentos de UX

| # | Dúvida ou cenário | Decisão | Responsável / data | Altera SPEC ou docs? |
|---|---|---|---|---|
| UX-01 | Como o Criador confirma | Digita o nome da família; o botão só habilita com texto igual; verificação somente no app (SPEC-022 E-08) | Pessoa usuária / 2026-11-16 | Não |
| UX-02 | Mensagem para quem perde o acesso | Banner neutro em TEL-001, sem push (SPEC-022 E-09) | Pessoa usuária / 2026-11-16 | Não |
| UX-03 | A mensagem neutra vale para qualquer sessão revogada? | Sim: o servidor não distingue a causa da revogação, então o banner aparece sempre que uma sessão antes ativa é recusada na renovação, inclusive após remoção (RN10) ou troca de aparelho. Hoje o app volta a TEL-001 sem mensagem | Pessoa usuária / 2026-11-17 | Não |
| UX-04 | Onde fica a ação administrativa para Kids | No bloco de gestão de TEL-032, abaixo de "Remover membro" | Pessoa usuária / 2026-11-17 | Não |
| UX-05 | Alinhamento na implementação | `common.cancel` e `common.network.error` não existiam no catálogo do app; foram criadas `account.common.cancel` e `account.common.error_network`. Títulos dos blocos de efeito, dicas de acessibilidade e o botão de fechar o aviso entraram na tabela da seção 7 | Claude / 2026-11-17 — informado à pessoa usuária | Não |

## 11. Checklist de aprovação da UX-spec

- [x] Está vinculada a uma SPEC funcional em elaboração.
- [x] As superfícies usam códigos existentes ou novos documentados (TEL-058, MOD-015, UF-17).
- [x] Entradas, saídas e cancelamento estão explicitados.
- [x] A máquina de estados foi descrita.
- [x] A microcopy define chaves i18n.
- [x] Ações não permitidas por perfil ficam ocultas.
- [x] Acessibilidade contemplada.
- [x] Adaptação para iPad especificada.
- [x] Decisões UX-03 e UX-04 confirmadas.
- [x] Nenhuma regra de negócio ou permissão foi inventada nesta UX-spec.
