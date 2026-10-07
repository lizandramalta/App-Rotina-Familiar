# UX Spec 001: Autenticar com Apple

**Status:** aprovada
**Autor:** Ana Luísa Coleone | **Criada em:** 2026-10-06 | **Aprovada por:** Ana Luísa Coleone | **Em:** 2026-10-06
**Spec funcional vinculada:** [SPEC-001-autenticar-com-apple.md](SPEC-001-autenticar-com-apple.md)
**Base funcional:** 1.14
**Superfícies de interface:** TEL-001
**Última revisão:** 2026-10-07 — decisões do SCRUM-46

## 1. Objetivo da Experiência e Jornada do Usuário

- **Visão da Experiência:** a pessoa que cria a família (ou que já é Criadora) entra no aplicativo com um único toque, usando sua identidade Apple. O app segue para suas tarefas quando já tem família, ou entrega o controle para a configuração inicial do perfil quando ainda não tem.
- **Perfis Atendidos:** Criador da Família ou pessoa que ainda vai criá-la. Não atende Administrador convidado, Membro ou Kids — esses perfis entram por convite (coberto por outra UX-spec).

## 2. Rastreabilidade Complementar de Design

| Referência | Código / Documento |
|---|---|
| Spec funcional vinculada | `SPEC-001-autenticar-com-apple.md` |
| Telas existentes/alteradas | TEL-001 (Entrada); destino TEL-055 |
| Fluxos de navegação (User Flows) | UF-01 (trecho de autenticação), UF-03 (trecho "Criador retorna por Apple") |
| Documentos de design consultados | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

*(Regras de negócio, casos de uso e permissões de domínio são herdados integralmente da SPEC funcional vinculada.)*

## 3. Escopo da Experiência

- **Dentro do escopo:** TEL-001 — estado inicial, botão nativo Apple, retorno silencioso para cancelamento/falha nativa, carregamento, mensagens inline para prova inválida, rede e limite de tentativas, e saída bem-sucedida.
- **Fora do escopo:** TEL-055/TEL-002/TEL-056 (onboarding de perfil, família e membros, outra UX-spec de `SPEC-002`); TEL-003/TEL-004 (convite e recuperação, outra UX-spec de `SPEC-005`). TEL-001 apenas referencia o destino — não os detalha.

## 4. Jornada, Navegação e Preservação de Contexto

| Superfície Origem | Gatilho / Ação do Usuário | Superfície Destino | Tipo de Apresentação | Ação de Retorno / Cancelamento | Preservação de Contexto e Rascunho |
|---|---|---|---|---|---|
| TEL-001 | Tocar "Entrar com Apple" | Sheet nativo Apple (externo) | Apresentação nativa do sistema | Cancelar no sheet retorna a TEL-001 sem alteração | Não há dado digitado a preservar |
| Sheet nativo Apple | Cancelar ou retornar falha sem prova | TEL-001 (`Idle`) | Dismiss do sheet pelo sistema | Retorno silencioso; foco do VoiceOver volta ao botão Apple | Não há dado digitado a preservar |
| Sheet nativo Apple | Login concluído com sucesso | TEL-001 (estado `Submitting`, transitório) | — | — | Mantém o botão em estado de carregamento até a resposta do backend |
| TEL-001 (`Submitting`) | Backend confirma família vinculada | TEL-010 (Minhas tarefas) | Dismiss automático da entrada | — | Sessão passa a ser mantida pelo app; não há retorno a TEL-001 |
| TEL-001 (`Submitting`) | Backend confirma ausência de família | TEL-055 (Configurar perfil inicial) | Push controlado pela navegação principal | Cancelar o onboarding retorna à entrada sem salvar | `creationGrant` é mantido em memória até ser consumido ou expirar |
| TEL-001 (`Submitting`) | `401 APPLE_PROOF_INVALID`, falha de rede ou `429 RATE_LIMIT_EXCEEDED` | TEL-001 (`Idle` com mensagem inline) | Sem trocar de tela | Botão Apple fica disponível; novo toque inicia um novo login Apple | Nenhuma sessão, grant ou prova anterior é preservada para retry |

- **Preservação de Estado:** não há formulário nesta tela; nada para preservar além do estado de carregamento durante a chamada ao backend.
- **Prevenção de Perda de Dados:** não aplicável — não há dados digitados nesta tela.

## 5. Especificação de Superfícies, Anatomia e Componentes de UI

### 5.1. TEL-001 — Entrada

- **Objetivo da Superfície:** oferecer o ponto único de entrada do Criador via Apple, com orientação mínima para quem recebeu convite (fora do escopo desta UX-spec).
- **Anatomia e Hierarquia Visual:**
  - **Corpo da Tela:** título/ilustração de boas-vindas; botão nativo `Sign in with Apple` centralizado; texto de apoio orientando quem já tem convite a usar o link recebido (ação que leva a TEL-003/TEL-004, fora desta spec).
  - **Rodapé:** nenhum controle fixo adicional; o botão Apple é a única ação primária desta spec.
- **Componentes do Design System Utilizados:**
  - `SignInWithAppleButton` / `ASAuthorizationAppleIDButton` nativo, com rótulo `.signIn` e estilo `.black`; texto livre, ícone e fonte não são customizados.
  - `InlineFeedback` não bloqueante, acima do botão Apple, com ícone e texto localizável para os erros que o app pode apresentar.
  - Indicador de carregamento acoplado ao próprio botão nativo durante `Submitting`.
- **Apresentação por Perfil de Acesso:** não há variação por perfil nesta tela — ela antecede qualquer perfil resolvido.

## 6. Ciclo de Vida da Interface e Máquina de Estados (ViewStates)

| Estado da View (`ViewState`) | Condição / Gatilho | O que o Usuário Vê na Tela | Ações Permitidas | Feedback / Transição |
|---|---|---|---|---|
| **`Idle / Initial`** | Abertura de TEL-001 sem sessão válida | Botão Apple pronto, texto de apoio para convidados | Tocar o botão Apple | Transição suave de entrada |
| **`Idle / Initial`** | Cancelamento ou falha devolvida pelo sheet nativo | Mesma tela inicial, sem mensagem do app | Tocar o botão Apple | Foco do VoiceOver retorna ao botão Apple |
| **`Submitting`** | Login nativo concluído; aguardando `POST /access/apple` | Botão Apple com indicador de carregamento; texto de apoio oculto | Nenhuma (previne toque duplo) | Mantém foco no botão |
| **`Content / Success`** | Backend confirma sessão ou `creationGrant` | Transição imediata para TEL-010 ou TEL-055 | — | Dismiss automático de TEL-001 |
| **`Error (Não-Bloqueante)`** | Resposta `401 APPLE_PROOF_INVALID` ou `429 RATE_LIMIT_EXCEEDED` | Mensagem inline; botão Apple volta a `Idle` | Tocar o botão Apple novamente | Não exige recarregar a tela |
| **`Offline / Sem Conexão`** | Falha de rede ao chamar `POST /access/apple` após login nativo concluído | Mensagem inline de conexão; botão Apple volta a `Idle` | Tocar o botão Apple novamente após restabelecer a conexão | Uma nova tentativa sempre reinicia o login Apple; a prova anterior não é reenviada |

Não há estados `Loading (Carga Inicial)`, `Refreshing` ou `Empty State` nesta tela — ela não carrega lista nem dados remotos antes da interação do usuário.

## 7. Interações, Microcopy e Chaves de Internacionalização (`i18n`)

| Elemento de UI | Tipo de Componente | Chave de Localização (`i18n key`) | Texto Padrão (pt-BR) | Cenário de Exibição / Validação | Rastreabilidade (CA / RN da SPEC) |
|---|---|---|---|---|---|
| Título da tela | `Text` | `access.entry.title` | "Organize a rotina da família" | Estado inicial | TEL-001 |
| Texto de apoio | `Text` | `access.entry.subtitle` | "Entre com Apple para criar ou acessar sua família" | Estado inicial | CA-01, CA-02 |
| Orientação a convidados | `Text` | `access.entry.invite_hint` | "Recebeu um convite? Abra o link que a sua família enviou." | Estado inicial, sempre visível | Fora do escopo (referência a TEL-003/004) |
| Erro de prova inválida | `InlineFeedback` | `access.entry.error_apple_proof_invalid` | "Não foi possível confirmar sua conta Apple. Tente novamente." | Resposta `401 APPLE_PROOF_INVALID` | CA-04 |
| Erro de rede | `InlineFeedback` | `access.common.error_network` | "Não foi possível conectar. Verifique sua internet." | Timeout ou falha de rede após login nativo | CA-10 |
| Limite de tentativas | `InlineFeedback` | `access.entry.error_rate_limited` | "Muitas tentativas. Aguarde alguns minutos e tente novamente." | Resposta `429 RATE_LIMIT_EXCEEDED` | CA-11 |

*Regra de Ouro aplicada:* cancelamento e falha do sheet Apple não recebem feedback duplicado do app. As mensagens inline só tratam retornos do nosso backend ou indisponibilidade de rede e sempre oferecem um caminho de retomar com novo toque.

## 8. Acessibilidade (A11y) e Adaptação de Dispositivo

### 8.1. VoiceOver e Tecnologias Assistivas (iOS)
- **Ordem de Foco Lógico:** Título → Texto de apoio → Botão Apple → Orientação a convidados.
- **Rótulos Acessíveis:** o botão `ASAuthorizationAppleIDButton` já fornece rótulo e papel acessíveis nativos da Apple; nenhum rótulo customizado é necessário ou permitido para esse componente.
- **Mensagens de erro:** `InlineFeedback` usa rótulo de alerta e é anunciado pelo VoiceOver quando aparece; em seguida, o foco lógico permanece no botão Apple para nova tentativa. Cancelamento ou falha nativa não anuncia mensagem adicional; o foco retorna ao botão Apple.

### 8.2. Dynamic Type (Escala de Fontes)
- Título, texto de apoio e mensagens de erro suportam todos os tamanhos de Dynamic Type, incluindo os tamanhos de acessibilidade, quebrando em múltiplas linhas sem truncar.

### 8.3. Contraste e Identificação Não-Cromática
- Mensagens de erro usam ícone (`exclamationmark.triangle` ou equivalente) além da cor `SemanticDestructive`, conforme WCAG 2.1 AA.

### 8.4. Ergonomia e Área de Toque Mínima
- O botão nativo Apple já respeita a área mínima de toque definida pela própria `AuthenticationServices`.

### 8.5. Adaptação de Layout (iPhone vs. iPad)
- **iPhone:** conteúdo centralizado verticalmente em tela cheia, sem navegação.
- **iPad:** mesmo conteúdo centralizado com largura máxima de 540 pt, para não esticar o botão e os textos em telas grandes; sem uso de `NavigationSplitView` nesta tela, por não haver navegação lateral antes da autenticação.

## 9. Referências Visuais e Design Tokens

- **Wireframes e Protótipos:** ainda não produzidos; a tela segue o layout mínimo descrito na seção 5.1 até haver material visual dedicado.
- **Cores Semânticas:** Fundo principal `BackgroundPrimary`; Erro/Alerta `SemanticDestructive`.
- **Tipografia:** Tipografia do sistema (San Francisco) com estilos semânticos (`.largeTitle` para o título, `.body` para o texto de apoio).

## 10. Decisões e Esclarecimentos de UX

| # | Dúvida ou Cenário de UX | Decisão de Design Adotada | Responsável / Data | Altera a SPEC funcional ou docs/? |
|---|---|---|---|---|
| UX-01 | O botão Apple deve ter alguma personalização de texto/cor? | Não — mantém o componente nativo `ASAuthorizationAppleIDButton` sem customização, para preservar a conformidade com as diretrizes da Apple. | Ana Luísa Coleone / 2026-10-06 | Não |
| UX-02 | O que a tela mostra enquanto aguarda a resposta de `POST /access/apple`? | Indicador de carregamento acoplado ao próprio botão nativo, com o restante da tela estável (sem skeleton, pois não há lista/dado remoto a carregar). | Ana Luísa Coleone / 2026-10-06 | Não |
| UX-03 | O que ocorre quando o sheet Apple é cancelado ou devolve erro sem prova? | TEL-001 retorna a `Idle` sem mensagem do app; o foco do VoiceOver volta ao botão Apple. | Produto / 2026-10-07 | Não |
| UX-04 | Quais falhas aparecem em tela? | `APPLE_PROOF_INVALID`, rede e `RATE_LIMIT_EXCEEDED` usam mensagem inline acima do botão. Cancelamento e falha nativa não aparecem como erro no app. | Produto / 2026-10-07 | Não |
| UX-05 | Como a pessoa tenta novamente após rede ou erro de backend? | Um novo toque no botão Apple inicia novo login; o app não reenvia a prova anterior automaticamente. | Produto / 2026-10-07 | Não |
| UX-06 | Quais escopos e configuração usa o botão Apple? | Nenhum escopo adicional; botão nativo com rótulo `.signIn` e estilo `.black`. | Produto / 2026-10-07 | Não |

## 11. Checklist de Aprovação da UX-Spec (Definition of Ready)

- [x] Está vinculada a uma SPEC funcional em elaboração.
- [x] Todas as superfícies citadas utilizam códigos estáveis existentes (`TEL-001`).
- [x] Entradas, saídas, cancelamento e preservação de rascunhos estão explicitados (não há dados a preservar nesta tela).
- [x] A máquina de estados completa foi descrita para TEL-001, com justificativa para os estados não aplicáveis (`Loading` inicial, `Refreshing`, `Empty`).
- [x] A tabela de microcopy define chaves `i18n` estruturadas para todos os textos e mensagens de erro.
- [x] Não há ações por perfil nesta tela — ela antecede a resolução de perfil.
- [x] Requisitos objetivos de acessibilidade foram contemplados.
- [x] Comportamento responsivo e adaptação para iPad estão especificados.
- [x] Nenhuma regra de negócio ou permissão de domínio foi inventada nesta UX-spec.
