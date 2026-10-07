# UX Spec 006: Editar perfil e consultar badges

**Status:** aprovada
**Autor:** Claude | **Criada em:** 2026-10-07 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-07
**Spec funcional vinculada:** [SPEC-006-editar-perfil.md](SPEC-006-editar-perfil.md)
**Base funcional:** 1.13
**Superfícies de interface:** TEL-030 (recorte), MOD-009, TEL-054

## 1. Objetivo da Experiência e Jornada do Usuário

- **Visão da Experiência:** a pessoa consulta sua identificação (foto, apelido) e seu reconhecimento acumulado por participação em missões (badges), e pode ajustar foto/apelido quando desejar, sem tocar em papel, família ou modo Kids.
- **Perfis Atendidos:** Administradores e Membros, pela navegação adulta (aba Meu perfil); Kids, pelo avatar/cabeçalho das duas abas, com a mesma capacidade de edição e linguagem simplificada.

## 2. Rastreabilidade Complementar de Design

| Referência | Código / Documento |
|---|---|
| Spec funcional vinculada | `SPEC-006-editar-perfil.md` |
| Telas e Modais existentes/alterados | TEL-030 (recorte), MOD-009, TEL-054 |
| Fluxos de navegação (User Flows) | UF-13 |
| Documentos de design consultados | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

*(Nota: regras de negócio, casos de uso e permissões de domínio são herdadas integralmente de SPEC-006. A ação "Sair da administração", também hospedada em TEL-030, pertence a UX-003 e não é alterada aqui.)*

## 3. Escopo da Experiência

- **Dentro do escopo:** o recorte de TEL-030 relativo a foto, apelido, total de participações e badges; o formulário MOD-009; o detalhe de marco TEL-054 e sua navegação até a missão (TEL-021, já existente).
- **Fora do escopo:** navegação de "Sair da administração" (UX-003); apresentação de progresso/participações/recompensa em Missões e conquistas (UX-016); qualquer tela de sinalização Kids (UX-012).

## 4. Jornada, Navegação e Preservação de Contexto

| Superfície Origem | Gatilho / Ação do Usuário | Superfície Destino | Tipo de Apresentação | Ação de Retorno / Cancelamento | Preservação de Contexto e Rascunho |
|---|---|---|---|---|---|
| TEL-030 (Meu perfil) | Tocar em "Editar" | MOD-009 (Editar meu perfil) | Sheet Modal (iPhone) / Form Sheet (iPad) | Fechar / Cancelar | Pergunta antes de descartar apenas se houver alteração não salva |
| MOD-009 | Tocar em "Salvar" com sucesso | TEL-030 | Dismiss automático | — | Atualiza foto/apelido exibidos imediatamente |
| TEL-030 | Tocar em um marco conquistado ou no próximo marco | TEL-054 (Detalhe do marco) | Push (NavigationStack) | Voltar | Preserva a posição de rolagem de TEL-030 |
| TEL-054 | Tocar em uma missão contribuinte | TEL-021 (Missão) | Push | Voltar | Retorna exatamente a TEL-054, não a TEL-030 |

- **Preservação de Estado:** campos digitados em MOD-009 permanecem preenchidos se a gravação falhar (RNF12/13 da spec funcional).
- **Prevenção de Perda de Dados:** se a pessoa alterar apelido ou escolher uma nova foto e tentar fechar MOD-009, exibir: *"Descartar alterações? O que você editou não será salvo."* Sem alteração, fechar direto.

## 5. Especificação de Superfícies, Anatomia e Componentes de UI

### 5.1. TEL-030 — Meu perfil (recorte desta entrega)

- **Objetivo da Superfície:** apresentar identificação pessoal e conquistas por participação.
- **Anatomia e Hierarquia Visual:**
  - **Cabeçalho:** avatar (foto ou identificação padrão), apelido (ou nome administrativo se não houver apelido), botão "Editar".
  - **Bloco de conquistas:** total de missões com participação; grade dos 4 marcos (bronze/prata/ouro/diamante), conquistados em destaque e não conquistados esmaecidos com contagem restante.
- **Componentes do Design System Utilizados:**
  - `AvatarView` com estado padrão sem foto.
  - `BadgeTierGrid` com 4 células, estado conquistado/pendente.
  - `PrimaryButton`/`IconButton` "Editar".
- **Apresentação por Perfil de Acesso:**
  - **Administrador/Membro:** cabeçalho e conquistas como descrito; ação "Sair da administração" (fora desta spec) permanece abaixo, quando aplicável.
  - **Kids:** acessado pelo avatar/cabeçalho das abas, sem terceira aba; mesmo conteúdo com ilustrações lúdicas e botões ampliados (mín. 56×56pt).

### 5.2. MOD-009 — Editar meu perfil

- **Objetivo da Superfície:** permitir adicionar/substituir/remover foto e configurar o apelido do titular.
- **Anatomia e Hierarquia Visual:**
  - **Barra Superior:** título "Editar perfil", botão fechar à esquerda, "Salvar" à direita (desabilitado até haver alteração válida).
  - **Corpo:**
    - Bloco 1: avatar com ações "Adicionar/Alterar foto" (abre seletor câmera ou galeria) e "Remover foto" (visível só com foto atual).
    - Bloco 2: campo de apelido com contador `{{current}}/20`.
  - **Rodapé:** nenhum (ação primária na barra superior).
- **Componentes do Design System Utilizados:**
  - `AvatarPicker` com ação sheet câmera/galeria (não é câmera direta — diferente da sinalização Kids).
  - `TextField` com contador de caracteres não-espaço.
  - `PrimaryButton` com estado de carregamento.
- **Apresentação por Perfil de Acesso:**
  - **Administrador/Membro:** formulário completo conforme descrito.
  - **Kids:** mesmo formulário, câmera/galeria disponíveis (apenas a sinalização de tarefa usa câmera direta, não esta tela), ilustrações e textos simplificados, áreas de toque ≥56×56pt.

### 5.3. TEL-054 — Detalhe do marco

- **Objetivo da Superfície:** mostrar as missões que contribuíram para um marco conquistado.
- **Anatomia e Hierarquia Visual:**
  - **Barra Superior:** título com o nome do marco (ex.: "Prata · 10 missões"), botão voltar.
  - **Corpo:** data de concessão; lista das missões contribuintes (título + data de conclusão), cada uma navegável a TEL-021.
- **Componentes do Design System Utilizados:** `List` com células de missão; `EmptyState` não se aplica aqui (só é acessível a partir de um marco já conquistado).
- **Apresentação por Perfil de Acesso:** idêntica para Administrador, Membro e Kids — cada um só acessa o próprio marco (titularidade exclusiva).

## 6. Ciclo de Vida da Interface e Máquina de Estados (ViewStates)

| Estado da View | Condição / Gatilho | O que o Usuário Vê | Ações Permitidas | Feedback / Transição |
|---|---|---|---|---|
| **TEL-030 · Loading** | Carregando perfil/badges | Esqueleto no cabeçalho e na grade de marcos | Nenhuma | Evita saltos visuais |
| **TEL-030 · Content** | Dados carregados | Avatar, apelido, total e grade de marcos | Editar, abrir marco | — |
| **TEL-030 · Empty (sem badges)** | `totalParticipations: 0` | Total 0 e "Faltam 5 para o bronze" | Editar | Sem simular conquista |
| **MOD-009 · Idle** | Abertura pré-interação | Formulário preenchido com dados atuais | Digitação, escolher foto | Foco inicial no apelido |
| **MOD-009 · Submitting** | Envio em andamento | "Salvar" com spinner; campos desabilitados | Nenhuma | Previne clique duplo |
| **MOD-009 · Error (não-bloqueante)** | Falha de validação ou rede | Banner/erro inline; dados preenchidos preservados | Corrigir e tentar de novo | Não limpa o formulário |
| **MOD-009 · Uploading foto** | Upload de imagem em andamento | Indicador sobre o avatar | Cancelar upload | Falha oferece repetir ou prosseguir sem foto |
| **TEL-054 · Loading** | Carregando contribuições | Esqueleto na lista | Nenhuma | — |
| **TEL-054 · Content** | Dados carregados | Lista de missões contribuintes | Abrir missão, voltar | — |

## 7. Interações, Microcopy e Chaves de Internacionalização (`i18n`)

| Elemento de UI | Tipo | Chave (`i18n key`) | Texto Padrão (pt-BR) | Cenário | Rastreabilidade |
|---|---|---|---|---|---|
| Título Meu perfil | `Text` | `profile.title` | "Meu perfil" | Cabeçalho TEL-030 | TEL-030 |
| Botão editar | `IconButton` | `profile.edit_button` | "Editar" | Cabeçalho TEL-030 | CA-02 |
| Total de participações | `Text` | `profile.badges.total` | "{{count}} missões com participação" | Bloco de conquistas | CA-01 |
| Próximo marco | `Text` | `profile.badges.next_tier` | "Faltam {{remaining}} para {{tier}}" | Marco não conquistado / estado vazio | CA-10 |
| Título editar perfil | `Text` | `profile.edit.title` | "Editar perfil" | Cabeçalho MOD-009 | MOD-009 |
| Ação adicionar foto | `Button` | `profile.edit.photo_add` | "Adicionar foto" | Sem foto atual | CA-02 |
| Ação alterar foto | `Button` | `profile.edit.photo_change` | "Alterar foto" | Com foto atual | CA-02 |
| Ação remover foto | `Button` | `profile.edit.photo_remove` | "Remover foto" | Com foto atual | CA-02 |
| Placeholder apelido | `TextField` | `profile.edit.nickname_placeholder` | "Como a família vai te chamar?" | Campo vazio | CA-02 |
| Contador apelido | `Text` | `profile.edit.nickname_counter` | "{{current}}/20" | Enquanto digita | CA-06 |
| Erro limite apelido | `Text` inline | `profile.edit.error_nickname_too_long` | "O apelido pode ter até 20 caracteres (sem contar espaços)" | Acima do limite | CA-06 |
| Erro foto não processada | `Toast` | `profile.edit.error_photo_processing` | "Sua foto ainda está sendo processada. Tente novamente em um instante." | `PHOTO_MEDIA_NOT_READY` | CA-07 |
| Erro formato de foto | `Toast` | `profile.edit.error_photo_format` | "Esse arquivo não é uma imagem compatível." | `MEDIA_FORMAT_UNSUPPORTED` | CA-08 |
| Erro foto muito grande | `Toast` | `profile.edit.error_photo_too_large` | "Essa foto é muito grande. Tente outra." | `MEDIA_TOO_LARGE` | CA-08 |
| Botão salvar | `PrimaryButton` | `profile.edit.button_save` | "Salvar" | Estado normal | CA-02 |
| Botão salvando | `PrimaryButton` | `profile.edit.button_saving` | "Salvando..." | Durante envio | CA-02 |
| Alerta de rede | `Toast` | `profile.common.error_network` | "Não foi possível conectar. Verifique sua internet." | Timeout ou erro de rede | CA-09 |
| Descartar alterações | `ActionSheet` | `profile.edit.discard_confirm` | "Descartar alterações? O que você editou não será salvo." | Fechar com edição pendente | — |
| Título detalhe do marco | `Text` | `profile.badge_detail.title` | "{{tier}} · {{count}} missões" | Cabeçalho TEL-054 | CA-11 |

## 8. Acessibilidade (A11y) e Adaptação de Dispositivo

### 8.1. VoiceOver e Tecnologias Assistivas (iOS)
- **Ordem de Foco Lógico (TEL-030):** Avatar → apelido → botão Editar → total de participações → grade de marcos.
- **Ordem de Foco Lógico (MOD-009):** Fechar → avatar/ações de foto → campo apelido → Salvar.
- **Rótulos Acessíveis:**
  - Avatar sem foto: *"Sem foto de perfil, identificação padrão"*.
  - Marco conquistado: *"Badge prata conquistado, dê dois toques para ver as missões"*.
  - Marco não conquistado: *"Badge ouro, faltam 15 missões, botão desabilitado"*.
- **Dicas de Ação:**
  - Botão Salvar: *"Dê dois toques para salvar seu apelido e foto"*.

### 8.2. Dynamic Type
- Contador de caracteres e textos de marco suportam todos os tamanhos, incluindo os de acessibilidade, sem truncar.

### 8.3. Contraste e Identificação Não-Cromática
- Marco conquistado vs. pendente é diferenciado por ícone e texto (“Conquistado” / “Faltam N”), não apenas por opacidade/cor (WCAG 2.1 AA).

### 8.4. Ergonomia e Área de Toque Mínima
- Botões de TEL-030/MOD-009: mínimo 44×44pt.
- Perfil Kids: botões principais com mínimo 56×56pt e feedback tátil de sucesso ao salvar.

### 8.5. Adaptação de Layout (iPhone vs. iPad)
- **iPhone:** MOD-009 como Bottom Sheet; TEL-054 em `NavigationStack`.
- **iPad:** MOD-009 como Form Sheet centralizado, largura máxima 540pt; TEL-054 integrado ao `NavigationSplitView`.

## 9. Referências Visuais e Design Tokens

- **Wireframes e Protótipos:** a definir pelo time de design; esta spec descreve apenas estrutura e estados, conforme `docs/design/screen-map.md` e `docs/design/user-flows.md` (UF-13).
- **Cores Semânticas:** `BackgroundPrimary`, `ActionPrimary`, `SemanticDestructive` (erro), `SemanticSuccess` (badge conquistado).
- **Tipografia:** estilos semânticos do sistema (`.headline`, `.body`, `.caption`).

## 10. Decisões e Esclarecimentos de UX

| # | Dúvida ou Cenário de UX | Decisão de Design Adotada | Responsável / Data | Altera a SPEC funcional ou docs/? |
|---|---|---|---|---|
| UX-01 | Onde mostrar "próximo marco" quando não há badges? | No bloco de conquistas de TEL-030, junto ao total (não apenas em TEL-054), conforme UC10 alternativas. | Decidido ao especificar / 2026-10-07 | Não |
| UX-02 | Seletor de foto em MOD-009 é câmera direta como na sinalização Kids? | Não — é uma ação sheet com câmera **ou** galeria, igual para todos os perfis incluindo Kids; a câmera direta é exclusiva da sinalização de tarefa. | Decidido ao especificar / 2026-10-07 | Não — já determinado por RN63. |

*Regra:* nenhuma decisão de UX desta spec altera regra de negócio, permissão ou contrato de dados da SPEC funcional vinculada.

## 11. Checklist de Aprovação da UX-Spec (Definition of Ready)

- [x] Está vinculada a uma SPEC funcional em elaboração.
- [x] Todas as superfícies citadas utilizam códigos estáveis existentes (TEL-030, MOD-009, TEL-054).
- [x] Entradas, saídas, cancelamento e preservação de rascunhos estão explicitados.
- [x] A máquina de estados completa foi descrita para as telas afetadas.
- [x] A tabela de microcopy define chaves `i18n` estruturadas para todos os textos e mensagens de erro.
- [x] Ações não permitidas por perfil estão configuradas para ficarem ocultas na interface (não há ação administrativa nestas superfícies).
- [x] Requisitos objetivos de acessibilidade foram contemplados.
- [x] Comportamento responsivo e adaptação para iPad estão especificados.
- [x] Nenhuma regra de negócio ou permissão de domínio foi inventada nesta UX-spec.
