# UX Spec 012: Sinalizar tarefa como realizada

**Status:** aprovada
**Autor:** Claude | **Criada em:** 2026-10-07 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-07
**Spec funcional vinculada:** [SPEC-012-sinalizar-tarefa-kids.md](SPEC-012-sinalizar-tarefa-kids.md)
**Base funcional:** 1.13
**Superfícies de interface:** TEL-041, MOD-011, UF-07 (somente ramo Kids)

## 1. Objetivo da Experiência e Jornada do Usuário

- **Visão da Experiência:** a criança, ao concluir sua parte de uma tarefa, precisa de um jeito simples e rápido de avisar a família — com a opção de mostrar uma foto, sem burocracia e sem a sensação de ter "terminado errado" caso não tenha foto.
- **Perfis Atendidos:** Kids, consultando e sinalizando apenas as próprias tarefas.

## 2. Rastreabilidade Complementar de Design

| Referência | Código / Documento |
|---|---|
| Spec funcional vinculada | `SPEC-012-sinalizar-tarefa-kids.md` |
| Telas e Modais existentes/alterados | TEL-041 (Detalhe da minha tarefa), MOD-011 (Sinalizar realização) |
| Fluxos de navegação (User Flows) | UF-07 (somente nós A–I, ramo Kids) |
| Documentos de design consultados | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

*(Regras de negócio, permissões e estados de domínio são herdados integralmente de SPEC-012.)*

## 3. Escopo da Experiência

- **Dentro do escopo:** TEL-041 no estado "pendente, própria" com a ação Sinalizar; MOD-011 completo (preparar sinalização, câmera direta, revisar/refazer/descartar, enviar com/sem foto); feedback de envio, sucesso e falha.
- **Fora do escopo:** TEL-015/TEL-016 (fila e avaliação administrativa — UX-013); qualquer alteração em TEL-040 (lista) além do já existente; conclusão manual e reabertura (já cobertas por UX-010/UX-011).

## 4. Jornada, Navegação e Preservação de Contexto

| Superfície Origem | Gatilho / Ação do Usuário | Superfície Destino | Tipo de Apresentação | Ação de Retorno / Cancelamento | Preservação de Contexto e Rascunho |
|---|---|---|---|---|---|
| TEL-040 (Minhas tarefas Kids) | Tocar na tarefa pendente | TEL-041 (Detalhe) | Navegação em pilha | Voltar retorna à lista, preservando filtro de dia | Nenhum dado de formulário a preservar |
| TEL-041 | Tocar "Avisar que terminei" | MOD-011 (Preparar sinalização) | Sheet Modal | Fechar/Cancelar mantém a tarefa como estava, sem foto nem sinalização | Foto capturada e ainda não enviada é descartada ao cancelar o modal |
| MOD-011 | Tocar "Adicionar foto" | Câmera do sistema (abertura direta) | Tela nativa do SO | Cancelar retorna ao MOD-011 sem foto | Permissão negada/câmera indisponível retorna ao MOD-011 com aviso, sem bloquear o envio sem foto |
| MOD-011 | Tocar "Enviar" (com ou sem foto) com sucesso | TEL-041 (Aguardando confirmação) | Dismiss automático do modal | — | Atualiza o estado da tarefa imediatamente |

- **Preservação de Estado:** se a foto for capturada mas o envio falhar, o modal permanece aberto com a foto revisada, permitindo repetir o envio ou prosseguir sem foto — nunca descarta a captura por conta própria.
- **Prevenção de Perda de Dados:** como não há campos de texto nesta sinalização, não é necessário alerta de descarte de digitação; fechar o modal com foto capturada e não enviada pede confirmação simples: *"Sair sem avisar que você terminou?"*.

## 5. Especificação de Superfícies, Anatomia e Componentes de UI

### 5.1. TEL-041 — Detalhe da minha tarefa (Kids)

- **Objetivo da Superfície:** mostrar os dados da tarefa própria e, quando pendente, permitir sinalizar a realização.
- **Anatomia e Hierarquia Visual:**
  - **Barra Superior:** botão voltar à esquerda; sem ação de edição (Kids não edita tarefas).
  - **Corpo da Tela:**
    - Bloco 1: título da tarefa em destaque, com ilustração/ícone lúdico conforme o peso.
    - Bloco 2: estado atual (`Pendente`, `Aguardando confirmação`, `Concluída`) com ícone e texto, nunca só por cor (RNF05).
    - Bloco 3 (opcional): observação da tarefa, quando houver.
  - **Rodapé:** botão primário "Avisar que terminei" fixo acima da área segura, visível **somente** quando a tarefa está `Pendente` e o Kids é responsável.
- **Componentes do Design System Utilizados:**
  - `StatusBadge` com ícone (não depende só de cor).
  - `PrimaryButton` com área de toque mínima 56×56pt e haptic feedback de sucesso.
- **Apresentação por Perfil de Acesso:**
  - **Kids:** único perfil que acessa esta tela; interface lúdica, linguagem direta, botões ampliados.

### 5.2. MOD-011 — Sinalizar realização

- **Objetivo da Superfície:** permitir à criança confirmar que realizou a tarefa, com foto opcional capturada na hora.
- **Anatomia e Hierarquia Visual:**
  - **Cabeçalho:** título "Avisar que terminei", botão fechar.
  - **Corpo:**
    - Bloco 1: nome da tarefa, para confirmação visual do que está sendo sinalizado.
    - Bloco 2: botão "Adicionar foto" (opcional) — ao tocar, abre a câmera diretamente, sem seletor câmera/galeria.
    - Bloco 3 (após captura): preview da foto com ações "Refazer" e "Usar foto"/"Remover".
  - **Rodapé:** botão primário "Enviar" (envia com ou sem foto), sempre habilitado exceto durante o envio.
- **Componentes do Design System Utilizados:**
  - `CameraLauncher` (abre câmera nativa diretamente).
  - `PhotoPreview` com ações refazer/descartar.
  - `PrimaryButton` com estado de carregamento (spinner) durante envio.
- **Apresentação por Perfil de Acesso:**
  - **Kids:** único perfil que abre este modal; botões com área mínima 56×56pt e feedback tátil.

## 6. Ciclo de Vida da Interface e Máquina de Estados (ViewStates)

| Estado da View | Condição / Gatilho | O que o Usuário Vê | Ações Permitidas | Feedback / Transição |
|---|---|---|---|---|
| **TEL-041 `Idle`** | Tarefa `pending`, Kids responsável | Detalhe completo com botão "Avisar que terminei" visível | Tocar no botão | Abre MOD-011 |
| **TEL-041 `Content` (Aguardando)** | Tarefa `awaitingConfirmation` | Detalhe sem botão de ação; estado "Aguardando confirmação" | Nenhuma ação de sinalização | Não permite nova sinalização (RN23) |
| **TEL-041 `Content` (Concluída)** | Tarefa `completed` | Detalhe sem botão de ação; estado "Concluída" | Nenhuma | — |
| **MOD-011 `Idle`** | Modal recém-aberto | Botão "Adicionar foto" e "Enviar" (sem foto) disponíveis | Adicionar foto ou enviar direto | — |
| **MOD-011 `Capturing`** | Câmera aberta | Interface nativa da câmera | Capturar, cancelar | Cancelar retorna a `Idle` |
| **MOD-011 `Reviewing`** | Foto capturada | Preview da foto com "Refazer"/"Usar foto" | Refazer (volta à câmera) ou confirmar | Confirmar volta a `Idle` com foto anexada |
| **MOD-011 `Submitting`** | Toque em "Enviar" | Botão com spinner; demais controles desabilitados | Nenhuma (evita duplo envio) | Mantém foco no botão |
| **MOD-011 `Error (foto)`** | Falha no upload da foto | Banner: foto não foi salva | Tentar de novo ou enviar sem foto | Não bloqueia o envio da sinalização |
| **MOD-011 `Error (sinalização)`** | Falha ao enviar a sinalização em si (ex.: rede) | Banner/Toast de falha; modal permanece aberto com os dados | Tentar novamente | Não anuncia sucesso; não fecha o modal |
| **TEL-041 `Success`** | Sinalização confirmada | Dismiss automático do modal; estado atualizado para "Aguardando confirmação" | — | Transição suave |

## 7. Interações, Microcopy e Chaves de Internacionalização (`i18n`)

| Elemento de UI | Tipo de Componente | Chave de Localização | Texto Padrão (pt-BR) | Cenário de Exibição | Rastreabilidade (CA) |
|---|---|---|---|---|---|
| Botão sinalizar (TEL-041) | `PrimaryButton` | `tasks.signal.button` | "Avisar que terminei" | Tarefa `pending`, Kids responsável | CA-01 |
| Título do modal | `Text` | `tasks.signal.modal_title` | "Avisar que terminei" | Cabeçalho de MOD-011 | CA-01 |
| Botão adicionar foto | `SecondaryButton` | `tasks.signal.add_photo` | "Adicionar foto (opcional)" | Estado `Idle` | CA-02 |
| Botão refazer | `TextButton` | `tasks.signal.retake_photo` | "Tirar outra foto" | Estado `Reviewing` | CA-02 |
| Botão usar foto | `PrimaryButton` | `tasks.signal.use_photo` | "Usar essa foto" | Estado `Reviewing` | CA-02 |
| Botão enviar | `PrimaryButton` | `tasks.signal.submit` | "Enviar" | Estado `Idle`/`Reviewing` | CA-01, CA-02 |
| Enviando | `PrimaryButton` (loading) | `tasks.signal.submitting` | "Enviando..." | Estado `Submitting` | CA-01, CA-02 |
| Erro ao salvar foto | `BannerAlert` | `tasks.signal.error_photo_upload` | "Não deu para salvar a foto. Quer tentar de novo ou enviar sem foto?" | Falha no upload da foto | CA-07 |
| Câmera indisponível/permissão negada | `Toast` | `tasks.signal.camera_unavailable` | "Não conseguimos abrir a câmera agora. Você pode continuar sem foto." | Permissão negada ou câmera indisponível | CA-07 |
| Erro ao enviar sinalização | `BannerAlert` | `tasks.signal.error_submit` | "Não foi possível avisar agora. Vamos tentar de novo?" | Falha de rede/servidor ao enviar | CA-08 |
| Tarefa já decidida (estado mudou) | `Toast` | `tasks.signal.already_decided` | "Essa tarefa já foi atualizada. Confira o estado mais recente." | `409 TASK_NOT_PENDING` ao tentar enviar | CA-05 |
| Confirmação de saída com foto pendente | `AlertDialog` | `tasks.signal.discard_confirm` | "Sair sem avisar que você terminou?" | Fechar modal com foto capturada não enviada | — |

## 8. Acessibilidade (A11y) e Adaptação de Dispositivo

### 8.1. VoiceOver e Tecnologias Assistivas

- **Ordem de Foco Lógico (TEL-041):** Voltar → Título da tarefa → Estado → Botão "Avisar que terminei".
- **Ordem de Foco Lógico (MOD-011):** Fechar → Nome da tarefa → Adicionar foto → Enviar.
- **Rótulos Acessíveis:**
  - Botão sinalizar: *"Avisar que terminei a tarefa, botão"*.
  - Botão adicionar foto: *"Adicionar foto opcional, botão"*.
  - Preview da foto: *"Foto capturada. Dê dois toques para tirar outra ou usar essa foto"*.
- **Dicas de Ação:**
  - Botão enviar: *"Dê dois toques para contar à família que você terminou"*.
- **Atributos:** botões como `.button`; estado da tarefa como texto simples com `.staticText`, nunca apenas um indicador de cor.

### 8.2. Dynamic Type

- Textos e botões suportam todos os tamanhos de Dynamic Type, incluindo tamanhos de acessibilidade; botões expandem verticalmente sem truncar "Avisar que terminei" ou "Adicionar foto (opcional)".

### 8.3. Contraste e Identificação Não-Cromática

- Estado da tarefa (`Pendente`/`Aguardando confirmação`/`Concluída`) sempre acompanhado de ícone e texto, nunca só de cor (RNF05).
- Contraste mínimo WCAG 2.1 AA (4.5:1 texto normal, 3:1 texto grande/gráficos).

### 8.4. Ergonomia e Área de Toque Mínima

- Perfil Kids: botões principais ("Avisar que terminei", "Adicionar foto", "Enviar") com área mínima **56×56 pt** e haptic feedback de sucesso ao concluir o envio, conforme padrão Kids já estabelecido no produto.

### 8.5. Adaptação de Layout (iPhone vs. iPad)

- **iPhone:** MOD-011 como Bottom Sheet; TEL-041 em `NavigationStack` de coluna única.
- **iPad:** MOD-011 como Form Sheet centralizado, largura máxima 540pt; suporte a retrato e paisagem.

## 9. Referências Visuais e Design Tokens

- **Wireframes e Protótipos:** ainda não produzidos; esta UX-spec é o registro textual precedente ao design visual (conforme convenção do projeto).
- **Cores Semânticas:** `BackgroundPrimary`, `ActionPrimary`, `SemanticDestructive` (erro), `SemanticSuccess` (confirmação).
- **Tipografia:** San Francisco, estilos semânticos padrão (`.headline`, `.body`, `.caption`), com variante lúdica Kids já definida no design system do app.

## 10. Decisões e Esclarecimentos de UX

| # | Dúvida ou Cenário de UX | Decisão de Design Adotada | Responsável / Data | Altera a SPEC funcional ou docs/? |
|---|---|---|---|---|
| UX-01 | O que fazer se a criança fechar o modal com foto capturada mas não enviada? | Exibir confirmação simples ("Sair sem avisar que você terminou?"), sem o alerta genérico de descarte de digitação (não há campo de texto nesta tela). | Claude / 2026-10-07 | Não |
| UX-02 | Como comunicar `409 TASK_NOT_PENDING` (outro adulto concluiu ou sinalização já existente) sem parecer erro técnico? | Toast neutro informando que a tarefa já foi atualizada, seguido de atualização automática do estado em TEL-041 — sem bloquear a navegação. | Claude / 2026-10-07 | Não |

## 11. Checklist de Aprovação da UX-Spec (Definition of Ready)

- [x] Está vinculada à SPEC-012 (em elaboração).
- [x] Todas as superfícies citadas usam códigos existentes (TEL-041, MOD-011) ou novos documentados.
- [x] Entradas, saídas, cancelamento e preservação de contexto estão explicitados.
- [x] Máquina de estados completa descrita para TEL-041 e MOD-011.
- [x] Tabela de microcopy com chaves `i18n` para todos os textos e mensagens de erro.
- [x] Ações não permitidas por perfil ficam ocultas (Admin/Membro nunca veem esta superfície Kids).
- [x] Acessibilidade (VoiceOver, Dynamic Type, área de toque mínima Kids) contemplada.
- [x] Adaptação iPhone/iPad especificada.
- [x] Nenhuma regra de negócio ou permissão de domínio foi inventada nesta UX-spec.
- [x] Status `aprovada` autorizado pela pessoa usuária em 2026-10-07.
