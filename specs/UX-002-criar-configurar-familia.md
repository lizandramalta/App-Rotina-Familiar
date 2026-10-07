# UX Spec 002: Criar e configurar família

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06
**Spec funcional vinculada:** [SPEC-002-criar-configurar-familia.md](SPEC-002-criar-configurar-familia.md)
**Base funcional:** 1.14
**Superfícies de interface:** TEL-055, TEL-002, TEL-056, TEL-033, TEL-034, TEL-053, MOD-012

## 1. Objetivo da experiência e jornada

- **Visão da experiência:** a pessoa que acabou de entrar com Apple configura sua identificação, cria a família, convida quem quiser e só então entra na área principal. Posteriormente, um Administrador encontra e entende o efeito da mudança de fuso antes de confirmá-la.
- **Perfis atendidos:** futuro Criador em TEL-055/TEL-002; Criador Administrador em TEL-056; Administrador em TEL-053 e MOD-012. Membro e Kids não recebem caminho visual para configurações familiares.

## 2. Rastreabilidade complementar

| Referência | Código / documento |
|---|---|
| Spec vinculada | `SPEC-002-criar-configurar-familia.md` |
| Telas e modal | TEL-055, TEL-002, TEL-056, TEL-033, TEL-034, TEL-053, MOD-012 |
| Fluxos | UF-01, UF-12, UF-16 |
| Design consultado | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

## 3. Escopo da experiência

- **Dentro:** rascunho de perfil, formulário de nome/fuso, confirmação da criação, foto opcional após a sessão, orquestração de membros e convites explícitos, configuração do fuso por Administrador, prévia dos efeitos, falhas e recuperação de resultado incerto.
- **Fora:** botão Apple de TEL-001; regras, contratos e detalhes de gestão de membros/convites; navegação e conteúdo de TEL-010/TEL-050 além das entradas e retornos necessários.

## 4. Jornada, navegação e preservação de contexto

| Origem | Ação | Destino | Retorno / cancelamento | Preservação |
|---|---|---|---|---|
| TEL-001 | Backend entrega `creationGrant` | TEL-055 | Cancelar volta a TEL-001 sem salvar | Grant fica somente em memória |
| TEL-055 | Avançar com nome válido | TEL-002 | Voltar preserva o rascunho local | Nome, foto e apelido permanecem somente no dispositivo |
| TEL-002 | Enviar dados válidos e criação confirmada | TEL-056 | — | Sessão confirmada passa à raiz de onboarding; foto pode concluir upload ou ser omitida |
| TEL-002 | Resposta incerta | TEL-002 com alerta | “Verificar acesso” retorna a TEL-001 | Perfil, nome e fuso ficam em memória até o resultado da nova entrada |
| TEL-056 | Adicionar membro | TEL-033 → TEL-034 opcional | Cancelar retorna a TEL-056 | Lista de membros adicionados nesta etapa permanece |
| TEL-056 | Tocar “Avançar” | TEL-010 | — | Permite zero membros; conclui o onboarding |
| TEL-050 | Administrador abre configurações | TEL-053 | Voltar preserva a origem em Família | Estado confirmado é recarregado ao retornar |
| TEL-053 | Selecionar novo fuso | MOD-012 | Cancelar volta a TEL-053 sem gravar | Seleção permanece para nova escolha |
| MOD-012 | Confirmar aplicação | TEL-053 | — | Exibe apenas estado confirmado pela API |

## 5. Superfícies e componentes

### 5.1. TEL-055 — Configurar perfil inicial

- **Objetivo:** coletar nome administrativo obrigatório, foto e etiqueta/apelido opcionais sem criar perfil persistido antes da família.
- **Anatomia:** título; explicação curta; campo Nome; avatar com ações de câmera/galeria/remover; campo opcional de etiqueta; botão “Continuar” e ação “Cancelar”.
- **Comportamento:** o nome é validado localmente; foto e etiqueta nunca bloqueiam a continuação. Cancelar descarta todo o rascunho e o grant, retornando a TEL-001.

### 5.2. TEL-002 — Criar família

- **Objetivo:** coletar nome e fuso inicial e criar a família autorizada pelo grant.
- **Anatomia:** título; explicação curta; campo de nome; seletor pesquisável de fuso IANA com `America/Sao_Paulo` pré-selecionado; botão primário de criação; ação secundária de cancelar.
- **Comportamento:** o botão só envia com nome localmente válido. O servidor continua sendo a autoridade. Cancelar descarta o formulário e retorna a TEL-001.

### 5.3. TEL-056 — Adicionar membros iniciais

- **Objetivo:** permitir que o Criador adicione zero ou mais pessoas antes de usar o aplicativo.
- **Anatomia:** título; lista de integrantes adicionados nesta etapa; ação “Adicionar membro”; botão persistente “Avançar”.
- **Comportamento:** abre TEL-033 sem variante de dados; depois do membro salvo, oferece TEL-034 como ação explícita de convite. Cancelar a folha nativa não remove o membro nem bloqueia “Avançar”.

### 5.4. TEL-053 — Configurações da família

- **Objetivo:** mostrar fuso vigente, alteração programada quando existir e iniciar uma mudança consciente.
- **Anatomia:** título; valor do fuso vigente; resumo de alteração programada; seletor de fuso; ação “Ver efeitos”; sem controles administrativos para Membro/Kids, que não navegam para esta tela.
- **Comportamento:** seleção não persiste. A prévia solicitada abre MOD-012 e o estado confirmado permanece visível até nova resposta de API.

### 5.5. MOD-012 — Efeitos da alteração de fuso

- **Objetivo:** apresentar o fuso proposto, o modo de aplicação e os limites efetivos devolvidos pela prévia.
- **Anatomia:** título, resumo do fuso atual/proposto, aviso de ciclo de transição quando aplicável, opção explícita para aplicar agora ou no próximo ciclo, ações Cancelar e Confirmar.
- **Comportamento:** confirmar entra em `Submitting`; cancelar nunca grava. O modal não promete sucesso até a resposta confirmada.

## 6. Estados de interface

| Estado | TEL-055 / TEL-002 / TEL-056 | TEL-053 / MOD-012 |
|---|---|---|
| Initial | Rascunho de perfil; formulário de família com fuso padrão; lista inicial vazia em TEL-056 | Configurações ainda não carregadas |
| Loading | Não aplicável antes de interação | Skeleton para estado confirmado |
| Content | Nome/fuso editáveis; foto opcional em envio ou omitida; lista de membros e Avançar | Fuso atual, mudança programada e seletor |
| Submitting | Botão bloqueado com progresso | Confirmação bloqueia ações duplicadas |
| Error não bloqueante | Campos preservados; falha de foto permite tentar novamente ou seguir sem ela | Estado confirmado preservado; erro e nova tentativa |
| Resultado incerto | Orienta verificar o acesso por Apple; não marca criação como concluída | Não afirma alteração; mantém seleção para ação explícita |
| Offline | Informa indisponibilidade sem perder rascunho | Mostra último estado confirmado, sem permitir confirmar |

Não há estado vazio: a criação é um formulário e a configuração sempre possui fuso vigente após carregar.

## 7. Microcopy e i18n

| Elemento | Chave | Texto pt-BR proposto | Cenário |
|---|---|---|---|
| Título | `family.create.title` | “Crie sua família” | TEL-002 |
| Título | `onboarding.profile.title` | “Seu perfil” | TEL-055 |
| Nome | `onboarding.profile.name.label` | “Seu nome” | TEL-055 |
| Foto | `onboarding.profile.photo.optional` | “Foto (opcional)” | TEL-055 |
| Etiqueta | `onboarding.profile.nickname.optional` | “Etiqueta (opcional)” | TEL-055 |
| Avançar | `onboarding.members.continue` | “Avançar” | TEL-056 |
| Sem membros | `onboarding.members.empty` | “Você pode adicionar pessoas agora ou fazer isso depois.” | TEL-056 |
| Nome | `family.create.name.label` | “Nome da família” | Campo de entrada |
| Fuso | `family.create.time_zone.label` | “Fuso horário” | Seletor |
| Criar | `family.create.submit` | “Criar família” | Ação primária |
| Cancelar | `family.create.cancel` | “Cancelar” | Retorno sem gravação |
| Nome inválido | `family.create.error_name_invalid` | “Informe um nome de família válido.” | Erro de validação |
| Resultado incerto | `family.create.error_uncertain` | “Não foi possível confirmar se sua família foi criada. Entre com Apple novamente para verificar seu acesso.” | Resposta perdida |
| Verificar acesso | `family.create.verify_access` | “Verificar acesso” | Ação de recuperação |
| Título | `family.settings.title` | “Configurações da família” | TEL-053 |
| Fuso atual | `family.settings.time_zone.current` | “Fuso atual” | Estado confirmado |
| Ver efeitos | `family.settings.time_zone.preview` | “Ver efeitos” | Abre MOD-012 |
| Aplicar agora | `family.time_zone.apply_now` | “Aplicar agora” | MOD-012 |
| Próximo ciclo | `family.time_zone.apply_next_cycle` | “Aplicar no próximo ciclo” | MOD-012 |
| Falha de rede | `family.common.error_network` | “Não foi possível conectar. Verifique sua internet.” | Falha de rede |

## 8. Acessibilidade e adaptação

- A ordem VoiceOver é título, explicação, nome, foto opcional, etiqueta, ação primária e cancelar em TEL-055; título, nome, fuso, ação primária e cancelar em TEL-002; e título, lista de integrantes, Adicionar membro e Avançar em TEL-056. Em TEL-053, título, fuso vigente, alteração programada, seletor e ação.
- O seletor anuncia o fuso selecionado; MOD-012 anuncia se haverá transição e o modo escolhido. Erros e alertas usam anúncio acessível.
- Todos os textos usam Dynamic Type, sem truncar nome do fuso, datas ou explicação de transição.
- Cor nunca é a única indicação de erro, alteração programada ou transição; usar texto e ícone semântico com contraste WCAG AA.
- Alvos de toque têm no mínimo 44×44 pt. Em iPad, TEL-055, TEL-002, TEL-056 e TEL-053 usam coluna/formulário centralizado de até 540 pt; MOD-012 é `Form Sheet`.

## 9. Decisões e esclarecimentos de UX

| # | Decisão | Situação | Altera comportamento? |
|---|---|---|---|
| UX-01 | Apenas Administrador visualiza a entrada para TEL-053 e os controles de fuso. O backend permanece a autoridade. | Decidida em 2026-10-06 | Não; aplica RNF07/RF67 |
| UX-02 | Resposta incerta na criação preserva o rascunho e oferece verificação por nova entrada Apple, sem retry automático. | Decidida em 2026-10-06 | Não; aplica RNF12 |
| UX-03 | MOD-012 apresenta prévia antes de qualquer gravação e não trata prévia como reserva. | Decidida em 2026-10-06 | Não |
| UX-04 | A foto selecionada em TEL-055 fica somente no rascunho até a família e a sessão existirem; falha posterior oferece repetir ou seguir sem foto. | Pessoa usuária, 2026-10-07 | Não; aplica RN01/RN63/RF48. |

## 10. Checklist de aprovação

- [x] Vinculada à SPEC-002 e às superfícies existentes.
- [x] Jornadas, retornos, falhas e preservação de rascunho especificados.
- [x] Estados, i18n e requisitos de acessibilidade definidos.
- [x] Controles proibidos ocultos a Membro e Kids, sem substituir backend.
- [x] Base funcional atualizada e SPEC vinculada aprovada.
