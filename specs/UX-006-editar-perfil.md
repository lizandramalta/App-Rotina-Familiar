# UX Spec 006: Editar perfil e consultar badges

**Status:** aprovada
**Autor:** Claude | **Criada em:** 2026-10-07 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-07
**Spec funcional vinculada:** [SPEC-006-editar-perfil.md](SPEC-006-editar-perfil.md)
**Base funcional:** 1.19 (RN 1.19 / RF 1.18 / UC 1.17)
**Referência visual:** Figma `566:37` — variante padrão de média fidelidade: TEL-030 `566:40`, TEL-054 `567:37`, MOD-009 `567:294`, Kids `568:81`, iPad retrato `568:304`, iPad paisagem `645:13677`. A proposta gamificada (`580:59`) não faz parte desta entrega.
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

- **Dentro do escopo:** o recorte de TEL-030 relativo a identificação, seção "Papel na família" (somente leitura, hospedando a ação de SPEC-003), total de participações e badges; o formulário MOD-009; o detalhe de marco TEL-054 e sua navegação até a missão (TEL-021, já existente).
- **Fora do escopo:** navegação de "Sair da administração" (UX-003); apresentação de progresso/participações/recompensa em Missões e conquistas (UX-016); qualquer tela de sinalização Kids (UX-012).

## 4. Jornada, Navegação e Preservação de Contexto

| Superfície Origem | Gatilho / Ação do Usuário | Superfície Destino | Tipo de Apresentação | Ação de Retorno / Cancelamento | Preservação de Contexto e Rascunho |
|---|---|---|---|---|---|
| TEL-030 (Meu perfil) | Tocar em "Editar" | MOD-009 (Editar meu perfil) | Sheet Modal (iPhone) / Form Sheet (iPad) | `✕` / Cancelar | Pergunta antes de descartar apenas se houver alteração não salva |
| MOD-009 | Tocar em `✓` com sucesso | TEL-030 | Dismiss automático | — | Atualiza foto/apelido exibidos imediatamente |
| TEL-030 | Tocar em um marco conquistado (`isConquered == true`, `awardId != nil`) | TEL-054 (Detalhe do marco) | Push (NavigationStack) | Voltar | Preserva a posição de rolagem de TEL-030; marcos pendentes não são tocáveis |
| TEL-054 | Tocar em uma missão contribuinte | TEL-021 (Missão) | Push | Voltar | Retorna exatamente a TEL-054, não a TEL-030 |

- **Preservação de Estado:** campos digitados em MOD-009 permanecem preenchidos se a gravação falhar (RNF12/13 da spec funcional).
- **Prevenção de Perda de Dados:** se a pessoa alterar apelido ou escolher uma nova foto e tentar fechar MOD-009, exibir: *"Descartar alterações? O que você editou não será salvo."* Sem alteração, fechar direto.

## 5. Especificação de Superfícies, Anatomia e Componentes de UI

### 5.1. TEL-030 — Meu perfil (recorte desta entrega)

- **Objetivo da Superfície:** apresentar identificação pessoal, papel na família e conquistas por participação.
- **Anatomia e Hierarquia Visual (Adulto):**
  - **Identidade:** avatar (foto ou identificação padrão) e botão "Editar". Sem apelido: título = nome e subtítulo `"<Papel> · <Nome da Família>"` (ex.: "Administrador · Família Silva", "Membro · Família Silva"). Com apelido: título = apelido (ex.: "Jojô") e subtítulo `"<Nome> · <Papel>"` (ex.: "Jô · Administrador").
  - **Seção "PAPEL NA FAMÍLIA":** linha `"Papel: Administrador"` ou `"Papel: Membro"` e rodapé conforme o perfil (ver abaixo). Omitida no Modo Kids.
  - **Conquistas:** card de participações com total, barra de progresso até o próximo marco e `"Faltam X para a <tier>"`; grade dos 4 marcos (bronze/prata/ouro/diamante), conquistados em destaque e tocáveis, pendentes esmaecidos com contagem restante e não tocáveis; rodapé explicativo.
- **Seção "Papel na família" por perfil:**
  - **Criador:** "Papel: Administrador"; rodapé "O Criador da família não pode deixar a administração."
  - **Administrador não Criador:** "Papel: Administrador"; ação destrutiva "Deixar a administração" (abre MOD-010, SPEC-003); rodapé "Ao deixar a administração, você passa a ser Membro. Para voltar, outro Administrador precisa promover você."
  - **Membro:** "Papel: Membro"; rodapé "A gestão de membros e das configurações da família fica com os Administradores."
- **Rodapé das Conquistas:** com participações: "Cada missão encerrada com a sua participação conta uma vez. Os marcos são cumulativos."; com 0 participações: "Participe de uma missão da família para começar. Cada missão encerrada com a sua participação conta uma vez."
- **Componentes do Design System Utilizados:**
  - `AvatarView` com estado padrão sem foto.
  - `BadgeTierGrid` com 4 células, estado conquistado/pendente.
  - `IconButton`/botão "Editar".
  - Card de progresso com barra até o próximo marco.
- **Apresentação por Perfil de Acesso:**
  - **Administrador/Membro:** identidade, "Papel na família" e conquistas como descrito.
  - **Kids:** acessado pelo avatar/cabeçalho das abas, sem terceira aba; subtítulo "Kids · <Nome da Família>" (ex.: "Kids · Família Silva") sem "Papel na família"; conquistas com "<N> missões com você", "Faltam X para a <tier>" e rodapé "Cada missão da família em que você ajudou conta uma vez."; ilustrações lúdicas e botões ampliados (mín. 56×56pt).
- **Erro de carregamento:** card com `exclamationmark.circle.fill`, "Não foi possível carregar seu perfil. Tente novamente." e botão "Tentar novamente".

### 5.2. MOD-009 — Editar meu perfil

- **Objetivo da Superfície:** permitir adicionar/substituir/remover foto, editar o nome (adultos) e configurar o apelido do titular.
- **Anatomia e Hierarquia Visual:**
  - **Barra Superior:** título "Editar perfil"; botão `✕` à esquerda e `✓` à direita (desabilitado até haver alteração válida; vira `ProgressView` ao salvar).
  - **Subtítulo (Adulto):** "É assim que a família vai ver você.\nFoto e etiqueta são opcionais."
  - **Foto:** avatar e botão único "Adicionar foto" (sem foto) / "Alterar foto" (com foto), com a legenda "Foto (opcional) · câmera ou galeria" (Kids: "Câmera ou galeria"). O botão abre `confirmationDialog` com "Tirar foto", "Escolher da galeria", "Remover foto" (destrutivo, só com foto) e "Cancelar".
  - **Campos (Adulto):** "Seu nome" (obrigatório) e "Etiqueta (opcional)" com placeholder "Ex.: Pai, vó, filha mais velha, caçula", apoio "Visível para a família. Só você pode alterar." e contador `{{current}}/20`.
  - **Campo (Kids):** apenas "Seu apelido", com apoio "A família vai ver esse nome." (sem "Seu nome").
  - **Rodapé:** nenhum (ação primária na barra superior).
- **Componentes do Design System Utilizados:**
  - `AvatarPicker` com `confirmationDialog` câmera/galeria (não é câmera direta — diferente da sinalização Kids).
  - `TextField` com contador de caracteres não-espaço.
  - Botão `✓` com estado de carregamento.
- **Apresentação por Perfil de Acesso:**
  - **Administrador/Membro:** formulário completo (foto, nome, etiqueta), em iPhone e iPad.
  - **Kids:** foto e apelido; câmera/galeria disponíveis, textos simplificados, áreas de toque ≥56×56pt.

### 5.3. TEL-054 — Detalhe do marco

- **Objetivo da Superfície:** mostrar as missões que contribuíram para um marco conquistado.
- **Anatomia e Hierarquia Visual:**
  - **Topo:** botão voltar flutuante.
  - **Cabeçalho:** medalha de 56pt, `"<Tier> · <N> missões"` (ex.: "Prata · 10 missões") e "Conquistado em <data>" (no esqueleto, "Carregando…").
  - **Lista:** seção "Missões que contaram" (Adulto) / "Missões em que você ajudou" (Kids); cada item mostra o título e "Concluída em <data>" e navega a TEL-021.
- **Componentes do Design System Utilizados:** `List` com células de missão; `EmptyState` não se aplica aqui (só é acessível a partir de um marco já conquistado).
- **Apresentação por Perfil de Acesso:** idêntica para Administrador, Membro e Kids, salvo o título da seção — cada um só acessa o próprio marco (titularidade exclusiva).

## 6. Ciclo de Vida da Interface e Máquina de Estados (ViewStates)

| Estado da View | Condição / Gatilho | O que o Usuário Vê | Ações Permitidas | Feedback / Transição |
|---|---|---|---|---|
| **TEL-030 · Loading** | Carregando perfil/badges | Esqueleto na identidade e na grade de marcos | Nenhuma | Evita saltos visuais |
| **TEL-030 · Content** | Dados carregados | Identidade, "Papel na família" (adulto), total, progresso e grade de marcos | Editar, abrir marco conquistado, "Deixar a administração" (Admin não Criador) | — |
| **TEL-030 · Empty (sem badges)** | `totalParticipations: 0` | Total 0, "Faltam 5 para a bronze" e rodapé de início | Editar | Sem simular conquista |
| **TEL-030 · Error** | Falha ao carregar | Card com `exclamationmark.circle.fill`, "Não foi possível carregar seu perfil. Tente novamente." | "Tentar novamente" | Recarrega perfil e badges |
| **MOD-009 · Idle** | Abertura pré-interação | Formulário preenchido com dados atuais | Digitação, escolher foto | Foco inicial no primeiro campo (nome, adulto; apelido, Kids) |
| **MOD-009 · Submitting** | Envio em andamento | `✓` vira `ProgressView`; campos desabilitados | Nenhuma | Previne clique duplo |
| **MOD-009 · Error (não-bloqueante)** | Falha de validação ou rede | Erro inline/banner; dados preenchidos preservados | Corrigir e tentar de novo | Não limpa o formulário |
| **MOD-009 · Uploading foto** | Upload de imagem em andamento | "Enviando foto…" sobre o avatar | "Cancelar envio" | — |
| **MOD-009 · Falha de upload** | Falha de rede/servidor no envio da foto | "Não foi possível enviar a foto. Sua foto atual continua." | "Tentar novamente", "Manter foto atual" | Mantém a foto vigente |
| **MOD-009 · Erro de arquivo** | `MEDIA_FORMAT_UNSUPPORTED` / `MEDIA_TOO_LARGE` | "Esse arquivo não é uma imagem compatível." / "Essa foto é muito grande. Tente outra." | "Escolher outra foto" | Mantém a foto vigente |
| **TEL-054 · Loading** | Carregando contribuições | Esqueleto no cabeçalho ("Carregando…") e na lista | Nenhuma | — |
| **TEL-054 · Content** | Dados carregados | Medalha, tier, data de conquista e lista de missões | Abrir missão, voltar | — |

## 7. Interações, Microcopy e Chaves de Internacionalização (`i18n`)

| Elemento de UI | Tipo | Chave (`i18n key`) | Texto Padrão (pt-BR) | Cenário | Rastreabilidade |
|---|---|---|---|---|---|
| Título Meu perfil | `Text` | `profile.title` | "Meu perfil" | Cabeçalho TEL-030 | TEL-030 |
| Botão editar | `IconButton` | `profile.edit_button` | "Editar" | Cabeçalho TEL-030 | CA-02 |
| Subtítulo identidade (sem apelido) | `Text` | `profile.identity.subtitle_role_family` | "{{role}} · {{familyName}}" | Sem apelido; Kids usa "Kids · {{familyName}}" | CA-01 |
| Subtítulo identidade (com apelido) | `Text` | `profile.identity.subtitle_name_role` | "{{name}} · {{role}}" | Com apelido | CA-01 |
| Seção papel | `Text` | `profile.role.section` | "PAPEL NA FAMÍLIA" | Adulto | — |
| Papel administrador | `Text` | `profile.role.administrator` | "Papel: Administrador" | Criador e Admin | — |
| Papel membro | `Text` | `profile.role.member` | "Papel: Membro" | Membro | — |
| Ação deixar administração | `Button` | `profile.role.leave_administration` | "Deixar a administração" | Admin não Criador (abre MOD-010, SPEC-003) | SPEC-003 |
| Rodapé papel — Criador | `Text` | `profile.role.footer_creator` | "O Criador da família não pode deixar a administração." | Criador | — |
| Rodapé papel — Admin | `Text` | `profile.role.footer_admin` | "Ao deixar a administração, você passa a ser Membro. Para voltar, outro Administrador precisa promover você." | Admin não Criador | — |
| Rodapé papel — Membro | `Text` | `profile.role.footer_member` | "A gestão de membros e das configurações da família fica com os Administradores." | Membro | — |
| Total de participações | `Text` | `profile.badges.total` | "{{count}} missões com participação" (Kids: "{{count}} missões com você") | Bloco de conquistas | CA-01 |
| Próximo marco | `Text` | `profile.badges.next_tier` | "Faltam {{remaining}} para a {{tier}}" | Marco não conquistado / estado vazio | CA-10 |
| Rodapé conquistas | `Text` | `profile.badges.footer` | "Cada missão encerrada com a sua participação conta uma vez. Os marcos são cumulativos." | Com participações | CA-01 |
| Rodapé conquistas vazio | `Text` | `profile.badges.footer_empty` | "Participe de uma missão da família para começar. Cada missão encerrada com a sua participação conta uma vez." | 0 participações | CA-10 |
| Rodapé conquistas Kids | `Text` | `profile.badges.footer_kids` | "Cada missão da família em que você ajudou conta uma vez." | Kids | CA-01 |
| Erro de carregamento | `Text` | `profile.error_load` | "Não foi possível carregar seu perfil. Tente novamente." | TEL-030 Error | CA-01 |
| Tentar novamente | `Button` | `profile.common.retry` | "Tentar novamente" | Erro de carregamento / upload | — |
| Título editar perfil | `Text` | `profile.edit.title` | "Editar perfil" | Cabeçalho MOD-009 | MOD-009 |
| Subtítulo editar (adulto) | `Text` | `profile.edit.subtitle` | "É assim que a família vai ver você.\nFoto e etiqueta são opcionais." | MOD-009 adulto | CA-02 |
| Ação adicionar foto | `Button` | `profile.edit.photo_add` | "Adicionar foto" | Sem foto atual | CA-02 |
| Ação alterar foto | `Button` | `profile.edit.photo_change` | "Alterar foto" | Com foto atual | CA-02 |
| Legenda foto | `Text` | `profile.edit.photo_caption` | "Foto (opcional) · câmera ou galeria" (Kids: "Câmera ou galeria") | Abaixo do botão de foto | CA-02 |
| Opção tirar foto | `Button` | `profile.edit.photo_take` | "Tirar foto" | `confirmationDialog` | CA-02 |
| Opção galeria | `Button` | `profile.edit.photo_pick` | "Escolher da galeria" | `confirmationDialog` | CA-02 |
| Opção remover foto | `Button` | `profile.edit.photo_remove` | "Remover foto" | `confirmationDialog`, destrutivo, só com foto | CA-02 |
| Cancelar dialog | `Button` | `profile.common.cancel` | "Cancelar" | `confirmationDialog` | — |
| Enviando foto | `Text` | `profile.edit.photo_uploading` | "Enviando foto…" | Upload em andamento | CA-02 |
| Cancelar envio | `Button` | `profile.edit.photo_upload_cancel` | "Cancelar envio" | Upload em andamento | CA-02 |
| Falha de upload | `Text` | `profile.edit.error_photo_upload` | "Não foi possível enviar a foto. Sua foto atual continua." | Falha de upload | CA-09 |
| Manter foto atual | `Button` | `profile.edit.photo_keep_current` | "Manter foto atual" | Falha de upload | CA-09 |
| Escolher outra foto | `Button` | `profile.edit.photo_choose_another` | "Escolher outra foto" | Erro de arquivo | CA-08 |
| Campo nome | `TextField` | `profile.edit.name_label` | "Seu nome" | Somente adulto | CA-13 |
| Campo etiqueta | `TextField` | `profile.edit.nickname_label` | "Etiqueta (opcional)" | Adulto | CA-02 |
| Placeholder etiqueta | `TextField` | `profile.edit.nickname_placeholder` | "Ex.: Pai, vó, filha mais velha, caçula" | Campo vazio (adulto) | CA-02 |
| Apoio etiqueta | `Text` | `profile.edit.nickname_help` | "Visível para a família. Só você pode alterar." | Adulto | CA-02 |
| Campo apelido Kids | `TextField` | `profile.edit.nickname_label_kids` | "Seu apelido" | Kids | CA-12 |
| Apoio apelido Kids | `Text` | `profile.edit.nickname_help_kids` | "A família vai ver esse nome." | Kids | CA-12 |
| Contador etiqueta | `Text` | `profile.edit.nickname_counter` | "{{current}}/20" | Enquanto digita | CA-06 |
| Erro limite etiqueta | `Text` inline | `profile.edit.error_nickname_too_long` | "A etiqueta pode ter até 20 caracteres (sem contar espaços)." | Acima do limite | CA-06 |
| Erro foto não processada | `Toast` | `profile.edit.error_photo_processing` | "Sua foto ainda está sendo processada. Tente novamente em um instante." | `PHOTO_MEDIA_NOT_READY` | CA-07 |
| Erro formato de foto | `Toast` | `profile.edit.error_photo_format` | "Esse arquivo não é uma imagem compatível." | `MEDIA_FORMAT_UNSUPPORTED` | CA-08 |
| Erro foto muito grande | `Toast` | `profile.edit.error_photo_too_large` | "Essa foto é muito grande. Tente outra." | `MEDIA_TOO_LARGE` | CA-08 |
| Botão salvar (acessibilidade) | `IconButton` `✓` | `profile.edit.button_save` | "Salvar" (rótulo VoiceOver) | Estado normal | CA-02 |
| Botão salvando | `ProgressView` | `profile.edit.button_saving` | "Salvando…" (rótulo VoiceOver) | Durante envio | CA-02 |
| Botão fechar (acessibilidade) | `IconButton` `✕` | `profile.edit.button_close` | "Fechar" (rótulo VoiceOver) | Barra superior | — |
| Erro de rede ao salvar | `Text` inline | `profile.common.error_network` | "Não foi possível conectar. Verifique sua internet. Seus dados continuam aqui." | Timeout ou erro de rede | CA-09 |
| Descartar alterações | `Alert` | `profile.edit.discard_confirm` | Título "Descartar alterações?", mensagem "O que você editou não será salvo.", ações "Descartar alterações" (destrutiva) e "Continuar editando" | Fechar com edição pendente | — |
| Título detalhe do marco | `Text` | `profile.badge_detail.title` | "{{tier}} · {{count}} missões" | Cabeçalho TEL-054 | CA-11 |
| Data de conquista | `Text` | `profile.badge_detail.awarded_at` | "Conquistado em {{date}}" ("Carregando…" no esqueleto) | Cabeçalho TEL-054 | CA-11 |
| Seção missões (adulto) | `Text` | `profile.badge_detail.section` | "Missões que contaram" | TEL-054 adulto | CA-11 |
| Seção missões (Kids) | `Text` | `profile.badge_detail.section_kids` | "Missões em que você ajudou" | TEL-054 Kids | CA-11 |
| Data de conclusão | `Text` | `profile.badge_detail.completed_at` | "Concluída em {{date}}" | Item de missão | CA-11 |

## 8. Acessibilidade (A11y) e Adaptação de Dispositivo

### 8.1. VoiceOver e Tecnologias Assistivas (iOS)
- **Ordem de Foco Lógico (TEL-030):** Avatar → título/subtítulo da identidade → botão Editar → papel na família (adulto) → total de participações → grade de marcos.
- **Ordem de Foco Lógico (MOD-009):** Fechar → botão de foto → nome (adulto) → etiqueta/apelido → Salvar.
- **Rótulos Acessíveis:**
  - Avatar sem foto: *"Sem foto de perfil, identificação padrão"*.
  - Marco conquistado: *"Badge prata conquistado, dê dois toques para ver as missões"*.
  - Marco não conquistado: *"Badge ouro, faltam 15 missões, botão desabilitado"*.
- **Dicas de Ação:**
  - Botão Salvar (`✓`): *"Dê dois toques para salvar suas alterações"*.

### 8.2. Dynamic Type
- Contador de caracteres e textos de marco suportam todos os tamanhos, incluindo os de acessibilidade, sem truncar.

### 8.3. Contraste e Identificação Não-Cromática
- Marco conquistado vs. pendente é diferenciado por ícone e texto (“Conquistado” / “Faltam N”), não apenas por opacidade/cor (WCAG 2.1 AA).

### 8.4. Ergonomia e Área de Toque Mínima
- Botões de TEL-030/MOD-009: mínimo 44×44pt.
- Perfil Kids: botões principais com mínimo 56×56pt e feedback tátil de sucesso ao salvar.

### 8.5. Adaptação de Layout (iPhone vs. iPad)
- **iPhone:** MOD-009 como Sheet Modal; TEL-054 em `NavigationStack`.
- **iPad retrato (`568:304`):** TEL-030 em coluna central de 600pt; marcos em uma linha de 4 colunas (grade 1×4).
- **iPad paisagem (`645:13677`):** TEL-030 em 2 colunas — esquerda de 420pt com Identidade + Papel na família; direita flexível com Conquistas e grade de marcos em 4 colunas.
- **iPad (MOD-009):** Form Sheet de 540×620pt, com os mesmos campos do iPhone (adulto com "Seu nome"). TEL-054 segue em push na navegação.

## 9. Referências Visuais e Design Tokens

- **Wireframes e Protótipos:** Figma `566:37` (média fidelidade, variante padrão; ver cabeçalho). Em divergência de apresentação, o Figma prevalece sobre esta spec; permissões e regras seguem SPEC-006. Referências em `docs/design/screen-map.md` e `docs/design/user-flows.md` (UF-13).
- **Cores Semânticas:** `BackgroundPrimary`, `ActionPrimary`, `SemanticDestructive` (erro), `SemanticSuccess` (badge conquistado).
- **Tipografia:** estilos semânticos do sistema (`.headline`, `.body`, `.caption`).

## 10. Decisões e Esclarecimentos de UX

| # | Dúvida ou Cenário de UX | Decisão de Design Adotada | Responsável / Data | Altera a SPEC funcional ou docs/? |
|---|---|---|---|---|
| UX-01 | Onde mostrar "próximo marco" quando não há badges? | No bloco de conquistas de TEL-030, junto ao total (não apenas em TEL-054), conforme UC10 alternativas. | Decidido ao especificar / 2026-10-07 | Não |
| UX-02 | Seletor de foto em MOD-009 é câmera direta como na sinalização Kids? | Não — é uma ação sheet com câmera **ou** galeria, igual para todos os perfis incluindo Kids; a câmera direta é exclusiva da sinalização de tarefa. | Decidido ao especificar / 2026-10-07 | Não — já determinado por RN63. |

| UX-03 | Qual variante do Figma implementar? | A variante padrão de média fidelidade (iPhone, Kids, iPad retrato e paisagem); a proposta gamificada (`580:59`) fica fora. | Pessoa usuária / 2026-10-22 | Não |
| UX-04 | Quem abre TEL-054? | Somente marcos conquistados (`isConquered == true`, `awardId != nil`); marcos pendentes não são tocáveis. Corrige a redação anterior ("ou no próximo marco"). | Pessoa usuária / 2026-10-22 | Não |
| UX-05 | MOD-009 adulto tem "Seu nome"; Kids só "Seu apelido". | Segue o Figma; exige `name` no `PATCH` e `familyName` no `GET` (SPEC-006 E-04/E-05). | Pessoa usuária / 2026-10-22 | Sim — SPEC-006 E-04/E-05; RN63, RF48, UC10. |
| UX-06 | O Figma não traz a mensagem de erro de "Seu nome" inválido nem a de limite do apelido Kids. | **Pendente:** definir o texto antes da implementação; até lá, o limite do apelido Kids reaproveita o texto de "Etiqueta" com o termo "apelido". | Aguardando design / 2026-10-22 | Não |

*Regra:* nenhuma decisão de UX desta spec altera regra de negócio, permissão ou contrato de dados da SPEC funcional vinculada (as mudanças de contrato desta revisão estão registradas em SPEC-006 E-04 a E-06).

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

## Histórico de revisões

| Data | Alteração |
|---|---|
| 2026-10-22 | Alinhamento ao Figma `566:37` (SCRUM-52): identidade com nome da família, seção "Papel na família", conquistas com progresso e rodapés, MOD-009 com "Seu nome" (adulto), foto por `confirmationDialog`, estados de upload/erro, TEL-054 com cabeçalho e seções por perfil, layouts iPad retrato/paisagem. Marcos pendentes não abrem TEL-054. |
