# UX Spec NNN: [Nome curto da funcionalidade]

**Status:** rascunho | em esclarecimento | aprovada | em implementação | em validação qa | implementada  
**Autor:** | **Criada em:** AAAA-MM-DD | **Aprovada por:** | **Em:** AAAA-MM-DD  
**Spec funcional vinculada:** [SPEC-NNN-nome-curto.md]  
**Base funcional:** [versão vigente da documentação em docs/, ex.: 1.5]  
**Superfícies de interface:** TEL-.., MOD-.., UF-..  

<!--
================================================================================
DIRETRIZES DE ENGENHARIA DE PRODUTO E UX (SPECIFICATION-DRIVEN DEVELOPMENT - SDD)
================================================================================
1. PROPÓSITO: Esta UX-spec é o REGISTRO TEXTUAL, TÉCNICO E RASTREÁVEL da experiência
   de usuário. Ela define COMO a pessoa percebe, navega e opera a funcionalidade.
2. HIERARQUIA DE AUTORIDADE:
   - A SPEC funcional vinculada é SOBERANA em comportamento, dados, regras de negócio
     e critérios de aceite. Não invente regras ou permissões aqui!
   - Esta UX-spec é SOBERANA em apresentação visual, hierarquia, máquina de estados da
     interface (ViewStates), componentes, microcopy (chaves i18n) e acessibilidade.
   - Qualquer conflito detectado é uma pendência a resolver antes da aprovação.
3. ESTADOS DE INTERFACE: Todas as superfícies devem modelar seu ciclo de vida completo
   (Idle, Loading, Refreshing, Empty, Content, Submitting, Error bloqueante vs. não-bloqueante).
4. MICROCOPY E INTERNACIONALIZAÇÃO: Strings propostas devem vir acompanhadas de chaves
   canônicas de localização (i18n keys). Textos nunca prometem persistência antes da
   confirmação da API.
5. PERFIS E AUTORIZAÇÃO VISUAL: Usuários sem permissão NÃO visualizam botões ou caminhos
   para ações bloqueadas (ações são ocultas, não apenas desabilitadas). Perfis Kids
   recebem interface lúdica, com botões ampliados e linguagem direta.
================================================================================
-->

## 1. Objetivo da Experiência e Jornada do Usuário

- **Visão da Experiência:** [Descreva em 1 ou 2 frases o que a pessoa usuária precisa entender ou realizar e em qual momento de sua rotina familiar].
- **Perfis Atendidos:** [Ex.: Pais com perfil Administrador organizando a semana; Filhos com perfil Kids visualizando tarefas lúdicas e sinalizando conclusão].

## 2. Rastreabilidade Complementar de Design

| Referência | Código / Documento |
|---|---|
| Spec funcional vinculada | `SPEC-NNN-nome-curto.md` |
| Telas e Modais existentes/alterados | TEL-.., MOD-.. |
| Fluxos de navegação (User Flows) | UF-.. |
| Documentos de design consultados | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

*(Nota: Regras de negócio, casos de uso e permissões de domínio são herdados integralmente da SPEC funcional vinculada).*

## 3. Escopo da Experiência

- **Dentro do escopo:** [Superfícies, jornadas e fluxos visuais detalhados nesta UX-spec].
- **Fora do escopo:** [Interações resolvidas por outra UX-spec ou comportamentos já existentes na base].

## 4. Jornada, Navegação e Preservação de Contexto

Mapeia a origem, transição de tela, destino, retorno e como os dados preenchidos são preservados.

| Superfície Origem | Gatilho / Ação do Usuário | Superfície Destino | Tipo de Apresentação | Ação de Retorno / Cancelamento | Preservação de Contexto e Rascunho |
|---|---|---|---|---|---|
| TEL-007 (Tarefas) | Tocar em "+ Nova Tarefa" | MOD-002 (Criar Tarefa) | Sheet Modal | Fechar / Deslizar para baixo | Solicita confirmação de descarte se houver texto digitado |
| MOD-002 | Tocar em "Salvar" com sucesso | TEL-007 (Tarefas) | Dismiss automático | - | Atualiza a lista e destaca brevemente o novo item |

- **Preservação de Estado:** [Ex.: Mantém o filtro de data previamente selecionado na tela de tarefas após o retorno do modal].
- **Prevenção de Perda de Dados:** Se o usuário iniciar o preenchimento e tentar fechar a tela, DEVE ser exibido um alerta de confirmação: *"Deseja descartar as alterações? Os dados não salvos serão perdidos"*.

## 5. Especificação de Superfícies, Anatomia e Componentes de UI

Para cada tela ou modal novo ou modificado, detalhe sua estrutura visual e componentes.

### 5.1. [TEL-.. ou MOD-..] — [Nome da Superfície]

- **Objetivo da Superfície:** [O que esta tela apresenta e permite realizar].
- **Anatomia e Hierarquia Visual:**
  - **Barra Superior (Top Bar):** Título da tela, botão de fechar/voltar à esquerda, botão de ação primária à direita.
  - **Corpo da Tela (Content Area):**
    - Bloco 1: Campo de título em destaque.
    - Bloco 2: Seletor de data e hora com calendário expansível.
    - Bloco 3: Seletor horizontal de membros com avatares visíveis.
  - **Rodapé / Barra Inferior (Sticky Footer):** Botão de ação primária ("Salvar") fixo acima da área segura (*safe area*).
- **Componentes do Design System Utilizados:**
  - `TextField` com contador de caracteres (limite especificado na SPEC).
  - `AvatarSelector` para atribuição de responsável.
  - `PrimaryButton` com suporte nativo a estado de carregamento (*spinner*).
  - `StatusBadge` com cores semânticas da identidade visual.
- **Apresentação por Perfil de Acesso:**
  - **Administrador:** Visualiza todos os campos de configuração e atribuição livre.
  - **Membro:** Visualiza os campos com opções restritas conforme regras da SPEC.
  - **Kids:** Quando acessado pelo perfil infantil, a tela exibe ilustrações lúdicas, botões com áreas de toque maiores e elementos simplificados. Ações administrativas são **completamente ocultadas**.

## 6. Ciclo de Vida da Interface e Máquina de Estados (ViewStates)

Toda superfície reativa DEVE modelar os seguintes estados canônicos de interface:

| Estado da View (`ViewState`) | Condição / Gatilho | O que o Usuário Vê na Tela | Ações Permitidas | Feedback / Transição |
|---|---|---|---|---|
| **`Idle / Initial`** | Abertura pré-interação | Formulário limpo com campos prontos e foco inicial | Digitação livre | Transição suave de entrada |
| **`Loading (Carga Inicial)`** | Carregando dados da API | Esqueleto (*Skeleton/Shimmer*) nos cartões e campos | Nenhuma (bloqueia toques) | Evita saltos visuais (*layout shifts*) |
| **`Refreshing`** | Pull-to-refresh na lista | Indicador nativo de atualização no topo; conteúdo atual preservado | Rolagem permitida | Atualiza dados sem piscar a tela |
| **`Empty State (Sem dados)`** | Lista sem registros cadastrados | Ilustração amigável, texto orientador e botão primário de criação | Criar primeiro item | Conduz o usuário ao próximo passo |
| **`Content / Success`** | Dados carregados com sucesso | Interface completa com informações renderizadas | Todas as ações do perfil | Transição suave ao carregar |
| **`Submitting`** | Envio do formulário em andamento | Botão de ação exibe *spinner* interno; campos ficam desabilitados | Nenhuma (previne clique duplo) | Mantém o foco no botão de ação |
| **`Error (Bloqueante)`** | Falha total na carga inicial da tela | Tela com ilustração de falha, mensagem explicativa e botão "Tentar Novamente" | Tocar em "Tentar Novamente" | Reexecuta a consulta inicial |
| **`Error (Não-Bloqueante)`** | Falha ao submeter ação / validação | *Banner* de erro no topo ou *Toast*; formulário permanece preenchido | Ajustar dados e tentar de novo | Não limpa dados digitados |
| **`Offline / Sem Conexão`** | Dispositivo sem conectividade | Barra informativa discreta no topo: "Modo offline. Conecte-se para atualizar" | Consultar dados locais em cache | Reenvia ao recuperar conexão |

## 7. Interações, Microcopy e Chaves de Internacionalização (`i18n`)

Os textos da interface utilizam linguagem simples, acolhedora e acessível.  
*Regra de Ouro:* Mensagens de erro NUNCA devem culpar o usuário; devem explicar o que aconteceu e como resolver.

| Elemento de UI | Tipo de Componente | Chave de Localização (`i18n key`) | Texto Padrão (pt-BR) | Cenário de Exibição / Validação | Rastreabilidade (CA / RN da SPEC) |
|---|---|---|---|---|---|
| Título da tela | `Text` | `tasks.create.title` | "Nova Tarefa" | Cabeçalho da tela modal | TEL-007 |
| Campo Título | `TextField` placeholder | `tasks.create.input_title_placeholder` | "Ex.: Arrumar a cama" | Campo vazio | CA-01 |
| Contador | `Text` | `tasks.create.counter` | "{{current}}/{{max}} caracteres" | Enquanto digita | CA-04 |
| Erro de Título | `Text` inline | `tasks.create.error_title_required` | "Informe um título para a tarefa" | Submissão com campo vazio | CA-04 |
| Erro Limite | `Text` inline | `tasks.create.error_title_too_long` | "O título pode ter no máximo 80 caracteres" | Digitação excede 80 chars | CA-04 |
| Botão Salvar | `PrimaryButton` | `tasks.create.button_submit` | "Salvar Tarefa" | Estado normal do botão | CA-01 |
| Botão Enviando | `PrimaryButton` | `tasks.create.button_submitting` | "Salvando..." | Durante envio à API | CA-01 |
| Alerta Conflito | `BannerAlert` | `tasks.create.error_already_completed` | "Esta tarefa acabou de ser concluída por outro familiar." | Resposta HTTP 409 | CA-05 |
| Alerta de Rede | `Toast` | `tasks.common.error_network` | "Não foi possível conectar. Verifique sua internet." | Timeout ou erro de rede | CA-06 |

## 8. Acessibilidade (A11y) e Adaptação de Dispositivo

### 8.1. VoiceOver e Tecnologias Assistivas (iOS)
- **Ordem de Foco Lógico:** Top bar (Voltar) → Título da tela → Campo de entrada → Seletor de membros → Botão de submissão.
- **Rótulos Acessíveis (`Accessibility Labels`):**
  - Botão de fechar: *"Fechar criação de tarefa, botão"*
  - Avatar do membro selecionado: *"Responsável selecionado: Maria, botão. Dê dois toques para alterar"*
- **Dicas de Ação (`Accessibility Hints`):**
  - Botão salvar: *"Dê dois toques para registrar a nova tarefa na rotina da família"*
- **Atributos (`Accessibility Traits`):**
  - Todos os botões mapeados como `.button`; títulos como `.header`; seleções como `.selected`.

### 8.2. Dynamic Type (Escala de Fontes)
- A interface DEVE suportar todos os tamanhos de Dynamic Type do iOS, incluindo os tamanhos de acessibilidade.
- Textos longos quebram em múltiplas linhas; células de listas e botões expandem verticalmente conforme necessário sem truncar palavras essenciais.

### 8.3. Contraste e Identificação Não-Cromática
- Taxa de contraste de texto e elementos funcionais atende ao padrão mínimo WCAG 2.1 AA (4.5:1 para texto normal, 3:1 para texto grande e componentes gráficos).
- Status e alertas NUNCA dependem apenas de cor: todo indicador colorido é acompanhado de ícone específico e texto explícito.

### 8.4. Ergonomia e Área de Toque Mínima
- Todos os alvos de toque interativos possuem no mínimo **44x44 pt** de área clicável no iOS.
- Para o perfil Kids, os botões principais utilizam área mínima de **56x56 pt** com feedback tátil (*haptic feedback* de sucesso).

### 8.5. Adaptação de Layout (iPhone vs. iPad)
- **iPhone:** Modais apresentados como *Bottom Sheet* interativo; listas em coluna única com `NavigationStack`.
- **iPad:** Modais apresentados como *Form Sheet* centralizado com largura fixa máxima de 540 pt (evita que campos fiquem excessivamente esticados na tela grande). Suporte completo ao modo retrato e paisagem e integração com `NavigationSplitView`.

## 9. Referências Visuais e Design Tokens

- **Wireframes e Protótipos:** [Link para arquivo ou documentação visual de referência].
- **Cores Semânticas:**
  - Fundo principal: `BackgroundPrimary`
  - Ação primária: `ActionPrimary` (Azul da identidade da família)
  - Erro / Alerta: `SemanticDestructive`
  - Sucesso / Conclusão: `SemanticSuccess`
- **Tipografia:** Tipografia do sistema (San Francisco) utilizando estilos semânticos (`.headline`, `.body`, `.caption`).

## 10. Decisões e Esclarecimentos de UX

| # | Dúvida ou Cenário de UX | Decisão de Design Adotada | Responsável / Data | Altera a SPEC funcional ou docs/? |
|---|---|---|---|---|
| UX-01 | O que exibir se o usuário tentar sair com dados digitados? | Exibir ActionSheet de confirmação para prevenir descarte acidental. | Design Lead / 2026-10-06 | Não |

*Regra:* Se uma decisão de UX impactar regras de negócio, permissões ou contratos de dados, a alteração DEVE ser registrada na SPEC funcional vinculada antes da aprovação desta UX-spec.

## 11. Checklist de Aprovação da UX-Spec (Definition of Ready)

Antes de aprovar esta UX-spec, confirme:

- [ ] Está vinculada a uma SPEC funcional em elaboração ou aprovada.
- [ ] Todas as superfícies citadas utilizam códigos estáveis existentes (`TEL-..`, `MOD-..`) ou possuem novos códigos documentados.
- [ ] Entradas, saídas, cancelamento e preservação de rascunhos estão explicitados.
- [ ] A máquina de estados completa (`Loading`, `Refreshing`, `Empty`, `Content`, `Submitting`, `Error`) foi descrita para as telas afetadas.
- [ ] A tabela de microcopy define chaves `i18n` estruturadas para todos os textos e mensagens de erro.
- [ ] Ações não permitidas por perfil estão configuradas para ficarem ocultas na interface.
- [ ] Requisitos objetivos de acessibilidade (VoiceOver, Dynamic Type, área de toque mínima) foram contemplados.
- [ ] Comportamento responsivo e adaptação para iPad (largura máxima, formulário centralizado) estão especificados.
- [ ] Nenhuma regra de negócio ou permissão de domínio foi inventada nesta UX-spec.
