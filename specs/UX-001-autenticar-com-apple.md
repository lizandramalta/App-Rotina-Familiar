# UX Spec 001: Autenticar com Apple

**Status:** rascunho
**Autor:** Ana Luísa Coleone | **Criada em:** 2026-10-06 | **Aprovada por:** | **Em:**
**Spec funcional vinculada:** [SPEC-001-autenticar-com-apple.md](SPEC-001-autenticar-com-apple.md)
**Base funcional:** 1.5
**Superfícies de interface:** TEL-001

## 1. Objetivo da Experiência e Jornada do Usuário

- **Visão da Experiência:** a pessoa que cria a família (ou que já é Criadora) precisa entrar no aplicativo com um único toque, usando sua identidade Apple, sem preencher formulário algum. O app apenas reage ao resultado: segue para suas tarefas quando já tem família, ou entrega o controle para a criação da família quando ainda não tem.
- **Perfis Atendidos:** Criador da Família ou pessoa que ainda vai criá-la. Não atende Administrador convidado, Membro ou Kids — esses perfis entram por convite (coberto por outra UX-spec).

## 2. Rastreabilidade Complementar de Design

| Referência | Código / Documento |
|---|---|
| Spec funcional vinculada | `SPEC-001-autenticar-com-apple.md` |
| Telas existentes/alteradas | TEL-001 (Entrada) |
| Fluxos de navegação (User Flows) | UF-01 (trecho de autenticação), UF-03 (trecho "Criador retorna por Apple") |
| Documentos de design consultados | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

*(Regras de negócio, casos de uso e permissões de domínio são herdados integralmente da SPEC funcional vinculada.)*

## 3. Escopo da Experiência

- **Dentro do escopo:** TEL-001 — estado inicial, botão nativo Apple, estados de carregamento, erro (cancelamento/falha/rede) e saída bem-sucedida.
- **Fora do escopo:** TEL-002 (criação da família, outra UX-spec de `SPEC-002`); TEL-003/TEL-004 (convite e recuperação, outra UX-spec de `SPEC-005`). TEL-001 apenas referencia o destino — não os detalha.

## 4. Jornada, Navegação e Preservação de Contexto

| Superfície Origem | Gatilho / Ação do Usuário | Superfície Destino | Tipo de Apresentação | Ação de Retorno / Cancelamento | Preservação de Contexto e Rascunho |
|---|---|---|---|---|---|
| TEL-001 | Tocar "Entrar com Apple" | Sheet nativo Apple (externo) | Apresentação nativa do sistema | Cancelar no sheet retorna a TEL-001 sem alteração | Não há dado digitado a preservar |
| Sheet nativo Apple | Login concluído com sucesso | TEL-001 (estado `Submitting`, transitório) | — | — | Mantém o botão em estado de carregamento até a resposta do backend |
| TEL-001 (`Submitting`) | Backend confirma família vinculada | TEL-010 (Minhas tarefas) | Dismiss automático da entrada | — | Sessão passa a ser mantida pelo app; não há retorno a TEL-001 |
| TEL-001 (`Submitting`) | Backend confirma ausência de família | Entrega do `creationGrant` para o fluxo de criação (outra UX-spec) | Transição controlada pela navegação principal | — | `creationGrant` é mantido em memória até ser consumido ou expirar |

- **Preservação de Estado:** não há formulário nesta tela; nada para preservar além do estado de carregamento durante a chamada ao backend.
- **Prevenção de Perda de Dados:** não aplicável — não há dados digitados nesta tela.

## 5. Especificação de Superfícies, Anatomia e Componentes de UI

### 5.1. TEL-001 — Entrada

- **Objetivo da Superfície:** oferecer o ponto único de entrada do Criador via Apple, com orientação mínima para quem recebeu convite (fora do escopo desta UX-spec).
- **Anatomia e Hierarquia Visual:**
  - **Corpo da Tela:** título/ilustração de boas-vindas; botão nativo `Sign in with Apple` centralizado; texto de apoio orientando quem já tem convite a usar o link recebido (ação que leva a TEL-003/TEL-004, fora desta spec).
  - **Rodapé:** nenhum controle fixo adicional; o botão Apple é a única ação primária desta spec.
- **Componentes do Design System Utilizados:**
  - `ASAuthorizationAppleIDButton` (componente nativo da Apple, não personalizável em texto/ícone).
  - `BannerAlert` ou `Toast` para erro não bloqueante.
  - Indicador de carregamento acoplado ao próprio botão nativo durante `Submitting`.
- **Apresentação por Perfil de Acesso:** não há variação por perfil nesta tela — ela antecede qualquer perfil resolvido.

## 6. Ciclo de Vida da Interface e Máquina de Estados (ViewStates)

| Estado da View (`ViewState`) | Condição / Gatilho | O que o Usuário Vê na Tela | Ações Permitidas | Feedback / Transição |
|---|---|---|---|---|
| **`Idle / Initial`** | Abertura de TEL-001 sem sessão válida | Botão Apple pronto, texto de apoio para convidados | Tocar o botão Apple | Transição suave de entrada |
| **`Submitting`** | Login nativo concluído; aguardando `POST /access/apple` | Botão Apple com indicador de carregamento; texto de apoio oculto | Nenhuma (previne toque duplo) | Mantém foco no botão |
| **`Content / Success`** | Backend confirma sessão ou `creationGrant` | Transição imediata para TEL-010 ou para o fluxo de criação | — | Dismiss automático de TEL-001 |
| **`Error (Não-Bloqueante)`** | Cancelamento no sheet nativo, falha de autenticação ou prova rejeitada (`APPLE_PROOF_INVALID`) | `Toast`/`BannerAlert` com mensagem explicativa; botão Apple volta a `Idle` | Tocar o botão novamente | Não exige recarregar a tela |
| **`Offline / Sem Conexão`** | Falha de rede ao chamar `POST /access/apple` após login nativo concluído | Aviso de conexão; botão Apple volta a `Idle` | Tentar novamente ao recuperar conexão | Reenvia ao recuperar conexão, sem repetir o login nativo se a prova ainda for válida |

Não há estados `Loading (Carga Inicial)`, `Refreshing` ou `Empty State` nesta tela — ela não carrega lista nem dados remotos antes da interação do usuário.

## 7. Interações, Microcopy e Chaves de Internacionalização (`i18n`)

| Elemento de UI | Tipo de Componente | Chave de Localização (`i18n key`) | Texto Padrão (pt-BR) | Cenário de Exibição / Validação | Rastreabilidade (CA / RN da SPEC) |
|---|---|---|---|---|---|
| Título da tela | `Text` | `access.entry.title` | "Organize a rotina da família" | Estado inicial | TEL-001 |
| Texto de apoio | `Text` | `access.entry.subtitle` | "Entre com Apple para criar ou acessar sua família" | Estado inicial | CA-01, CA-02 |
| Orientação a convidados | `Text` | `access.entry.invite_hint` | "Recebeu um convite? Abra o link que a sua família enviou." | Estado inicial, sempre visível | Fora do escopo (referência a TEL-003/004) |
| Erro de cancelamento | `Toast` | `access.entry.error_cancelled` | "Entrada cancelada. Toque novamente quando quiser continuar." | Cancelamento no sheet nativo | CA-03 |
| Erro de prova inválida | `BannerAlert` | `access.entry.error_apple_proof_invalid` | "Não foi possível confirmar sua conta Apple. Tente novamente." | Resposta `401 APPLE_PROOF_INVALID` | CA-04 |
| Erro de rede | `Toast` | `access.common.error_network` | "Não foi possível conectar. Verifique sua internet." | Timeout ou falha de rede após login nativo | CA-10 |

*Regra de Ouro aplicada:* nenhuma mensagem culpa o usuário pelo cancelamento ou pela falha de rede; todas oferecem o caminho de retomar com um toque.

## 8. Acessibilidade (A11y) e Adaptação de Dispositivo

### 8.1. VoiceOver e Tecnologias Assistivas (iOS)
- **Ordem de Foco Lógico:** Título → Texto de apoio → Botão Apple → Orientação a convidados.
- **Rótulos Acessíveis:** o botão `ASAuthorizationAppleIDButton` já fornece rótulo e papel acessíveis nativos da Apple; nenhum rótulo customizado é necessário ou permitido para esse componente.
- **Mensagens de erro:** `BannerAlert`/`Toast` customizados seguem rótulo e `Accessibility Trait` de alerta (`.staticText` com `UIAccessibilityTraits.updatesFrequently` quando aplicável), para serem anunciados automaticamente pelo VoiceOver.

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
