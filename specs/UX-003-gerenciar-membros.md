# UX Spec 003: Gerenciar membros

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06  
**Spec funcional vinculada:** [SPEC-003-gerenciar-membros.md](SPEC-003-gerenciar-membros.md)  
**Base funcional:** 1.7  
**Superfícies de interface:** TEL-030, TEL-032, TEL-033, TEL-050, MOD-010, UF-12

## 1. Objetivo da experiência e jornada

- **Visão da experiência:** o Administrador inclui ou ajusta pessoas da família com clareza sobre papel, modo Kids e efeitos de uma remoção. Adultos podem continuar consultando o detalhe do membro, mas somente quem pode gerir vê os respectivos caminhos.
- **Perfis atendidos:** Administrador, inclusive Criador com suas proteções; Membro adulto apenas em consulta de TEL-032. Kids não acessam esta jornada. A saída voluntária de Administrador não-Criador começa no próprio perfil, TEL-030.

## 2. Rastreabilidade complementar

| Referência | Código / documento |
|---|---|
| Spec funcional vinculada | `SPEC-003-gerenciar-membros.md` |
| Telas e modal | TEL-030, TEL-032, TEL-033, TEL-050, MOD-010 |
| Fluxo | UF-12 |
| Design consultado | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

## 3. Escopo da experiência

- **Dentro:** entrada “Adicionar membro” em TEL-050 para Admin; criação e edição administrativa em TEL-033; ações autorizadas no detalhe TEL-032; confirmação de papel, modo Kids, remoção e saída de administração em MOD-010; retorno coerente à lista ou ao detalhe.
- **Fora:** credenciais e compartilhamento de convite em TEL-034; entrada por convite; formulário de apelido/foto próprio; conteúdo das tarefas do detalhe, seus filtros e sua consulta funcional.

## 4. Jornada, navegação e preservação de contexto

| Origem | Ação | Destino | Retorno / cancelamento | Contexto preservado |
|---|---|---|---|---|
| TEL-050 | Admin toca em “Adicionar membro” | TEL-033 | Cancelar retorna à Família | Período e rolagem da Família permanecem |
| TEL-033 | Salva nome e papel válidos | TEL-032 | — | Exibe somente estado confirmado; não abre TEL-034 |
| TEL-032 | Admin toca em editar | TEL-033 | Cancelar retorna ao detalhe | Membro e período selecionados permanecem |
| TEL-033 / TEL-032 | Alterar papel/modo ou remover | MOD-010 | Cancelar retorna sem gravar | Campos e detalhe permanecem íntegros |
| MOD-010 | Confirma mudança | TEL-032 | — | Recarrega capacidades e perfil confirmados |
| MOD-010 | Confirma remoção | TEL-050 | — | Lista confirmada sem o perfil removido; período preservado |
| TEL-030 | Admin não-Criador escolhe deixar administração | MOD-010 | Cancelar retorna ao perfil | Só muda navegação após confirmação da API |

- **Prevenção de perda:** fechar TEL-033 com alterações não salvas solicita confirmação de descarte. Erro de validação ou rede preserva o formulário; resposta incerta não é interpretada como sucesso.
- **Capacidades por perfil:** TEL-032 não apresenta editar, remover ou alterar papel a Membros. O Criador não recebe caminhos para remoção, rebaixamento ou saída da administração. TEL-050 não mostra “Adicionar membro” para Membro; Kids não entram na área Família.

## 5. Superfícies e componentes

### 5.1. TEL-050 — Família

- **Objetivo nesta entrega:** iniciar a criação para Administradores e abrir o detalhe de qualquer membro para adultos.
- **Anatomia:** a lista de membros continua como conteúdo existente; o botão “Adicionar membro” aparece apenas quando a capacidade `manageMembers` estiver confirmada.
- **Transição:** criar não gera credenciais nem navega para TEL-034. Após a confirmação, abre o perfil em TEL-032.

### 5.2. TEL-032 — Detalhe e tarefas do membro

- **Objetivo nesta entrega:** identificar o membro e oferecer gestão administrativa somente a Administradores autorizados.
- **Anatomia:** identificação do membro, papel e indicador textual de Criador; ações “Editar”, “Alterar papel ou modo Kids” e “Remover” apenas quando aplicáveis. O conteúdo de tarefas permanece sob sua spec própria.
- **Proteções visuais:** para Criador, mostrar a identificação especial sem ações proibidas. Para Membro consultando, não exibir controles de gestão nem configuração de apelido.

### 5.3. TEL-033 — Criar/editar membro

- **Objetivo:** coletar nome administrativo e papel, com a mesma superfície para criar e editar.
- **Anatomia:** título contextual; campo de nome; seletor de papel (`Administrador`, `Membro`, `Kids`); explicação curta e não-promissória do papel; ação primária Salvar/Criar e cancelar.
- **Validação local:** mostrar contador e erro de nome; o servidor continua autoridade. Não inclui foto, apelido, convite ou senha.

### 5.4. MOD-010 — Confirmar alteração de membro

- **Objetivo:** confirmar mudança que altera acesso, papel, modo Kids ou remoção.
- **Anatomia:** título específico à ação; resumo do membro e da alteração; efeitos relevantes; ações Cancelar e Confirmar.
- **Remoção:** explica que o acesso será revogado e que o histórico é preservado. Não promete remoção física nem enumera tarefas antes da resposta confirmada.
- **Saída da administração:** explica que a pessoa passa a Membro; não aparece para Criador.

## 6. Estados de interface

| Estado | TEL-050 / TEL-032 | TEL-033 / MOD-010 |
|---|---|---|
| Initial / Loading | Skeleton de lista, detalhe ou capacidades; nenhuma ação antecipada | Formulário pronto após dados necessários; modal não abre sem resumo carregado |
| Content | Lista, detalhe e controles condizentes com a capacidade atual | Campos editáveis e resumo da ação |
| Empty | Lista sem membros adicionais continua explícita, preservando o Criador | Não aplicável ao formulário |
| Submitting | Ações duplicadas ficam indisponíveis | Botão mostra progresso; cancelar e campos ficam bloqueados durante envio |
| Error não bloqueante | Mantém conteúdo confirmado e oferece atualizar | Mantém campos; erro associado ao campo ou banner com nova tentativa |
| Recurso alterado/removido | Recarrega lista/detalhe; não mostra ação concluída sem confirmação | Fecha somente quando estado confirmado exigir; informa indisponibilidade sem dados antigos |
| Offline / resposta incerta | Exibe último conteúdo confirmado, sem simular atualização | Mantém rascunho e orienta consultar estado antes de enviar de novo |

## 7. Microcopy e chaves i18n

| Elemento | Chave | Texto pt-BR proposto | Cenário |
|---|---|---|---|
| Ação de criação | `family.members.add.action` | “Adicionar membro” | TEL-050, somente Admin |
| Título de criação | `family.members.create.title` | “Adicionar membro” | TEL-033 |
| Título de edição | `family.members.edit.title` | “Editar membro” | TEL-033 |
| Campo nome | `family.members.name.label` | “Nome” | TEL-033 |
| Ajuda do campo | `family.members.name.hint` | “Use de 1 a 60 caracteres.” | TEL-033 |
| Erro de nome | `family.members.name.error_invalid` | “Informe um nome válido.” | Validação local ou `422` |
| Papel | `family.members.role.label` | “Papel na família” | TEL-033 |
| Confirmação de papel | `family.members.role_change.title` | “Confirmar alteração de papel” | MOD-010 |
| Remoção | `family.members.remove.title` | “Remover membro?” | MOD-010 |
| Efeito da remoção | `family.members.remove.message` | “O acesso será removido. O histórico da família será preservado.” | MOD-010 |
| Saída da administração | `profile.administration_exit.title` | “Deixar a administração?” | MOD-010 |
| Criador protegido | `family.members.creator_protected` | “O Criador da família não pode ser removido nem ter o papel alterado.” | Estado indisponível |
| Falha de rede | `family.members.error_network` | “Não foi possível confirmar a alteração. Verifique sua conexão e atualize os dados.” | Falha ou resposta incerta |

As mensagens recebem o código de erro estável da API como chave de decisão; textos não afirmam que uma operação foi salva antes da resposta confirmada.

## 8. Acessibilidade e adaptação

- VoiceOver anuncia, no detalhe, nome, papel e condição de Criador antes das ações disponíveis. MOD-010 anuncia o efeito da alteração e desloca foco para o título ao abrir.
- Rótulos e dicas: controles de papel anunciam o valor atual e a ação; remover anuncia que abre confirmação; a mensagem de Criador protegido é texto, não somente botão indisponível.
- Dynamic Type deve permitir múltiplas linhas em nomes, papéis e explicações, sem ocultar as ações essenciais.
- Papel, Kids, erro e remoção usam texto e ícone semântico, além de cor, conforme RNF05. Os alvos interativos têm ao menos 44×44 pt.
- Em iPhone, TEL-033 usa fluxo de navegação; em iPad, usa formulário centralizado e MOD-010 como `Form Sheet`, respeitando área segura e orientação.

## 9. Decisões de UX

| # | Decisão | Altera comportamento? |
|---|---|---|
| UX-01 | Criação salva o perfil e retorna ao detalhe; não inicia emissão de convite. | Não; aplica a fronteira da SPEC-004. |
| UX-02 | Controles proibidos são ocultos, enquanto a API permanece a autoridade. | Não; aplica RNF07. |
| UX-03 | MOD-010 é obrigatório para remover, mudar papel/modo e sair da administração. | Não; apresenta efeitos já definidos. |
| UX-04 | Ao falhar ou haver resposta incerta, formulário e contexto são preservados e a tela recarrega o estado confirmado antes de nova ação. | Não; aplica RNF12. |

## 10. Checklist de aprovação

- [x] Vinculada à SPEC-003 e às superfícies existentes.
- [x] Jornada, retornos, cancelamento e preservação de contexto definidos.
- [x] Estados de interface, i18n e acessibilidade definidos.
- [x] Ações proibidas ficam ocultas sem substituir autorização no backend.
- [x] Não cria convite, edição de perfil próprio ou comportamento de tarefas.
- [x] Status autorizado explicitamente como `aprovada` pela pessoa usuária em 2026-10-06.
