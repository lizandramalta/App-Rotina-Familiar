# UX Spec 005: Ingressar por convite

**Status:** aprovada

**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06

**Spec funcional vinculada:** [SPEC-005-ingressar-por-convite.md](SPEC-005-ingressar-por-convite.md)

**Base funcional:** 1.7
**Superfícies de interface:** TEL-001, TEL-003, TEL-004, TEL-010, TEL-040, MOD-013, UF-02, UF-03

## 1. Objetivo da experiência e jornada

- **Visão da experiência:** a pessoa abre um convite, entende se pode continuar sem ter dados familiares expostos, informa a senha e entra no perfil correto. Uma sessão existente só muda após confirmação e sucesso comprovado.
- **Perfis atendidos:** pessoa convidada para perfil Administrador, Membro ou Kids; pessoa com sessão ativa que deseja trocar de acesso; Criador sem sessão, que recebe orientação para Apple em vez de convite.

## 2. Rastreabilidade complementar

| Referência | Código / documento |
|---|---|
| Spec funcional vinculada | `SPEC-005-ingressar-por-convite.md` |
| Telas e modal | TEL-001, TEL-003, TEL-004, TEL-010, TEL-040, MOD-013 |
| Fluxos | UF-02, UF-03 |
| Documentos de design | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

As regras de domínio, contratos e autorização são herdados integralmente da SPEC-005.

## 3. Escopo da experiência

- **Dentro:** abertura por Universal Link, inspeção neutra, senha, confirmação de troca, submissão, recuperação específica de resposta perdida, orientação de recuperação e roteamento por perfil.
- **Fora:** exibir dados familiares antes do ingresso, emitir/reemitir convite, recuperar senha, pedido automático a Administrador, cadastro Apple do Criador e qualquer migração de perfil ou histórico.

## 4. Jornada, navegação e preservação de contexto

| Origem | Ação | Destino | Retorno / cancelamento | Contexto preservado |
|---|---|---|---|---|
| Link externo, sem sessão | Abrir convite | TEL-003 | Convite indisponível segue para TEL-004 | Token fica somente na memória da jornada; senha nunca é pré-preenchida |
| Link externo, com sessão | Abrir convite | MOD-013 | Cancelar fecha o fluxo e mantém acesso atual | Sessão, navegação e dados locais atuais ficam intactos |
| MOD-013 | Confirmar troca | TEL-003 | Falha ou convite indisponível mantém a sessão anterior | Somente a confirmação permite enviar `switchConfirmed` |
| TEL-003 | Enviar senha válida | TEL-010 ou TEL-040 | Não há retorno à senha após sucesso | Dados anteriores são limpos somente após a sessão nova estar confirmada |
| TEL-003 | Falha de rede/resposta incerta | Estado de recuperação na própria tela | Recuperação indisponível leva a TEL-004 | Material da tentativa fica protegido no Keychain por no máximo o necessário à recuperação |
| TEL-004 | Pessoa não é Criador | Aguardar novo convite fora do app | Voltar a TEL-001 | Não cria perfil substituto nem pedido automático |
| TEL-004 | Pessoa é Criador | TEL-001 / Sign in with Apple | Cancelar mantém acesso público | Não oferece senha de convite |

- Sem app instalado, o destino externo orienta instalar e reabrir o mesmo link; não afirma que o ingresso ocorreu.
- A inspeção não mostra nome, foto, família ou papel. A pessoa somente vê a senha após o convite ter sido considerado disponível.

## 5. Superfícies e componentes

### 5.1. MOD-013 — Confirmar troca de acesso

- **Objetivo:** tornar explícito que o próximo ingresso substitui o acesso local somente se for validado.
- **Anatomia:** título, explicação curta sem identidade do convite, ação primária de continuar e ação secundária de cancelar.
- **Comportamento:** cancelar não faz chamada de ingresso nem altera a sessão. Confirmar abre TEL-003, mas preserva dados locais até a resposta confirmada.

### 5.2. TEL-003 — Entrar por convite

- **Objetivo:** solicitar a senha de um convite já inspecionado sem revelar dados do perfil antes do ingresso.
- **Anatomia:** navegação de retorno/cancelamento, título, texto orientador, campo seguro de senha, erro inline, ação primária e link de ajuda para TEL-004.
- **Sem identidade prévia:** não exibir avatar, apelido, família, papel, nome de membro, token ou senha na tela.
- **Envio:** o botão fica em estado de processamento e previne duplo toque. Senha inválida mantém a pessoa na tela para correção; convite indisponível leva à orientação sem explicar o motivo.

### 5.3. TEL-004 — Recuperar acesso

- **Objetivo:** indicar o caminho correto quando não há ingresso possível: novo convite de Administrador para perfis convidados ou Apple para o Criador.
- **Anatomia:** título, explicação neutra, ação “Voltar à entrada”; ação Apple é apresentada somente no caminho do Criador já estabelecido pelo fluxo, sem inferir identidade a partir do convite indisponível.
- **Fora de questão:** não há formulário para contatar Administrador, botão de reenvio, criação de novo perfil ou senha alternativa.

## 6. Estados da interface

| Estado | Condição | O que a pessoa vê | Ações permitidas |
|---|---|---|---|
| `Inspecting` | Link aberto | Indicador discreto, sem detalhes do convite | Cancelar/voltar quando disponível |
| `PasswordEntry` | Convite disponível | Campo de senha e ação para entrar | Digitar, enviar, abrir ajuda |
| `Submitting` | Ingresso enviado | Botão com progresso; campo e navegação de submissão bloqueados | Nenhuma, evita duplo envio |
| `InvalidPassword` | `422 INVITE_PASSWORD_INVALID` | Erro inline, campo preservado e sem revelar estado adicional | Corrigir e enviar novamente |
| `Unavailable` | `404 INVITE_UNAVAILABLE` | Mensagem neutra e caminho para TEL-004 | Abrir orientação ou voltar |
| `RateLimited` | `429 RATE_LIMITED` | Mensagem de pausa e nenhuma indicação sobre o convite | Voltar ou tentar novamente quando o serviço permitir |
| `Recovering` | Timeout ou `503 JOIN_RESULT_UNCERTAIN` | Informação de que o app está conferindo o resultado | Aguardar; cancelar não altera o servidor |
| `RecoveryUnavailable` | Recuperação não retorna sessão | Orientação de novo convite/Apple em TEL-004 | Seguir orientação ou voltar |
| `Success` | Sessão confirmada ou recuperada | Transição para a área do perfil | Nenhuma ação intermediária; limpar dados anteriores |

## 7. Interações, microcopy e localização

| Elemento | Chave i18n | Texto padrão pt-BR | Cenário |
|---|---|---|---|
| Título da senha | `inviteJoin.title` | "Entrar com convite" | TEL-003 disponível |
| Orientação | `inviteJoin.description` | "Informe a senha recebida junto com o convite para continuar." | Antes da senha |
| Campo | `inviteJoin.password.label` | "Senha do convite" | Campo seguro |
| Ação | `inviteJoin.submit` | "Entrar" | Estado pronto |
| Processando | `inviteJoin.submitting` | "Entrando…" | Submissão |
| Senha incorreta | `inviteJoin.error.invalidPassword` | "A senha não confere. Revise e tente novamente." | `422` |
| Convite indisponível | `inviteJoin.error.unavailable` | "Não foi possível usar este convite." | `404` neutro |
| Limite | `inviteJoin.error.rateLimited` | "Tente novamente mais tarde." | `429` |
| Recuperação | `inviteJoin.recovery.inProgress` | "Estamos conferindo seu acesso. Aguarde um momento." | Timeout/resultado incerto |
| Recuperação indisponível | `inviteJoin.recovery.unavailable` | "Não foi possível concluir o acesso por este convite." | Sem recuperação possível |
| Ajuda | `inviteJoin.help.action` | "Preciso de ajuda para acessar" | Abre TEL-004 |
| Troca de acesso | `accessSwitch.title` | "Trocar de acesso?" | MOD-013 |
| Explicação da troca | `accessSwitch.description` | "Vamos manter seu acesso atual até confirmar o novo ingresso." | MOD-013 |
| Confirmar troca | `accessSwitch.confirm` | "Continuar" | MOD-013 |
| Cancelar troca | `accessSwitch.cancel` | "Cancelar" | MOD-013 |
| Recuperar acesso | `accessRecovery.title` | "Recuperar acesso" | TEL-004 |
| Novo convite | `accessRecovery.invite.description` | "Peça a um Administrador da sua família um novo convite para este perfil." | Perfil convidado |
| Retorno Apple | `accessRecovery.apple.description` | "Se você criou a família, entre com Apple para voltar ao seu acesso." | Criador |

## 8. Acessibilidade e adaptação

- Em MOD-013, a ordem de foco é título, explicação, continuar e cancelar. Em TEL-003: voltar, título, orientação, campo de senha, erro inline, entrar e ajuda.
- O campo anuncia “Senha do convite, campo seguro”. O botão de entrada anuncia seu estado de processamento e não depende somente de spinner ou cor.
- Erros e indisponibilidade usam texto e ícone, além de cor. Senhas, tokens e mensagens que possam contê-los não são lidos automaticamente pelo VoiceOver nem apresentados em logs da interface.
- Dynamic Type não trunca textos de erro ou recuperação; controles têm no mínimo 44 × 44 pt e contraste WCAG AA.
- A jornada Kids usa o mesmo acesso seguro, mas após sucesso abre TEL-040 e não revela destinos adultos. Em iPhone, TEL-003 usa `NavigationStack`; em iPad, preserva a pilha em layout adaptativo.

## 9. Decisões e esclarecimentos de UX

| # | Decisão | Origem | Altera a SPEC funcional ou docs/? |
|---|---|---|---|
| UX-01 | A inspeção é neutra e não revela dados de identidade antes da senha e do ingresso confirmados. | Pessoa usuária, 2026-10-06 | Não; registrada como E-01 na SPEC-005. |
| UX-02 | Timeout ou resposta incerta inicia recuperação específica antes de sugerir novo convite; o app não reenvia o ingresso automaticamente. | RN47, RNF12, RNF22 | Não. |
| UX-03 | O texto pt-BR e as chaves i18n desta seção são a proposta aprovada para detalhar a experiência. | Pessoa usuária, 2026-10-06 | Não. |

## 10. Checklist de aprovação

- [x] Está vinculada à SPEC-005 em elaboração.
- [x] TEL-001, TEL-003, TEL-004, TEL-010, TEL-040, MOD-013, UF-02 e UF-03 existem na base.
- [x] Entradas, saídas, cancelamento, troca e recuperação foram descritos.
- [x] Estados de carregamento, envio, erro, indisponibilidade e recuperação foram definidos.
- [x] Microcopy e chaves i18n foram definidas.
- [x] VoiceOver, Dynamic Type, contraste, toque, Kids e iPad foram considerados.
- [x] Status autorizado explicitamente como `aprovada` pela pessoa usuária em 2026-10-06.
