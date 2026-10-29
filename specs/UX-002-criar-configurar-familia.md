# UX Spec 002: Criar e configurar família

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-19
**Spec funcional vinculada:** [SPEC-002-criar-configurar-familia.md](SPEC-002-criar-configurar-familia.md)
**Base funcional:** RN 1.18 / RF 1.17 / UC 1.16
**Superfícies de interface:** TEL-055, TEL-002, TEL-056, TEL-034, TEL-053, MOD-012

## 1. Objetivo da experiência e jornada

- **Visão da experiência:** a pessoa configura sua identificação, prepara família e membros em TEL-002, confirma a criação conjunta e, havendo membros, chega a TEL-056 para convidá-los ou adiar. Posteriormente, um Administrador entende os efeitos de mudar o fuso antes de confirmar.
- **Perfis atendidos:** futuro Criador em TEL-055/TEL-002; Criador Administrador em TEL-056; Administrador em TEL-053 e MOD-012. Membro e Kids não recebem caminho visual para configurações familiares.

## 2. Rastreabilidade complementar

| Referência | Código / documento |
|---|---|
| Spec vinculada | `SPEC-002-criar-configurar-familia.md` |
| Telas e modal | TEL-055, TEL-002, TEL-056, TEL-034, TEL-053, MOD-012 |
| Fluxos | UF-01, UF-12, UF-16 |
| Design consultado | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

## 3. Escopo da experiência

- **Dentro:** rascunho de perfil e membros, envio opcional da foto antes da criação, formulário de nome/fuso/membros em TEL-002, criação conjunta, TEL-056 para convites explícitos após a criação, retorno em modo de edição, configuração posterior de fuso por Administrador, falhas e recuperação de resultado incerto.
- **Fora:** botão Apple de TEL-001; regras, contratos e detalhes de gestão de membros/convites; navegação e conteúdo de TEL-010/TEL-050 além das entradas e retornos necessários.

## 4. Jornada, navegação e preservação de contexto

| Origem | Ação | Destino | Retorno / cancelamento | Preservação |
|---|---|---|---|---|
| TEL-001 | Backend entrega `creationGrant` | TEL-055 | Cancelar volta a TEL-001 sem salvar | Grant fica somente em memória |
| TEL-055 | Avançar com nome válido; foto opcional já enviada ou omitida | TEL-002 | Voltar preserva os dados do perfil | Foto enviada fica protegida e ainda não vinculada a perfil |
| TEL-002 | Confirmar família, Criador e membros iniciais | TEL-056 se houver membros; TEL-010 se não houver | Falha mantém rascunho e não cria parte dos perfis | Sessão e membros iniciais confirmados; nenhum convite automático |
| TEL-002 | Resposta incerta | TEL-002 com alerta | “Verificar acesso” retorna a TEL-001 | Perfil, nome e fuso ficam em memória até o resultado da nova entrada |
| TEL-056 | Escolher convidar membro já criado | Folha nativa por emissão inicial direta | Fechar retorna a TEL-056 sem desfazer a emissão | Lista e família criada permanecem |
| TEL-056 | Voltar | TEL-002 em edição da família existente | Prosseguir sem mudanças não grava | Alterações autorizadas são salvas; novos membros seguem gestão normal |
| TEL-056 | Adiar convites ou tocar “Avançar” | TEL-010 | — | Convites podem continuar não emitidos |
| TEL-050 | Administrador abre configurações | TEL-053 | Voltar preserva a origem em Família | Estado confirmado é recarregado ao retornar |
| TEL-053 | Selecionar novo fuso | MOD-012 | Cancelar volta a TEL-053 sem gravar | Seleção permanece para nova escolha |
| MOD-012 | Confirmar aplicação | TEL-053 | — | Exibe apenas estado confirmado pela API |

## 5. Superfícies e componentes

### 5.1. TEL-055 — Configurar perfil inicial

- **Objetivo:** coletar nome administrativo obrigatório, foto e etiqueta/apelido opcionais sem criar perfil persistido antes da família.
- **Anatomia:** título; explicação curta; campo Nome; avatar com ações de câmera/galeria/remover; campo opcional de etiqueta; botão “Continuar” e ação “Cancelar”.
- **Comportamento:** o nome é validado localmente. Escolher foto inicia envio protegido antes da criação; falha oferece repetir ou seguir sem foto e nunca bloqueia a continuação. A mídia não cria perfil nem dá acesso familiar. Cancelar descarta o rascunho e o grant, retornando a TEL-001.

### 5.2. TEL-002 — Criar família

- **Objetivo:** coletar nome, fuso e membros iniciais e criar família, Criador e esses membros juntos; no retorno de TEL-056, editar a família existente.
- **Anatomia:** título; nome; seletor de fuso IANA com `America/Sao_Paulo` pré-selecionado na criação; lista editável de membros com nome e papel; ação de adicionar/retirar membro; botão primário contextual e voltar.
- **Comportamento:** antes da criação, a lista é rascunho e o servidor valida tudo na operação conjunta. Com membros, sucesso abre TEL-056; sem membros, abre TEL-010. No retorno de TEL-056, a tela mostra os dados persistidos: prosseguir sem mudanças não grava, e salvar mudanças autorizadas não cria outra família. Alterar o fuso após a criação encaminha a TEL-053/MOD-012.

### 5.3. TEL-056 — Convites iniciais

- **Objetivo:** oferecer convite aos membros já criados com a família antes de usar a área principal.
- **Anatomia:** título; lista de membros criados; ação de convite por membro; voltar e botão “Avançar”.
- **Comportamento:** não cria membros ou convites automaticamente. A primeira emissão explícita abre diretamente a folha nativa, sem confirmação intermediária; reemissão exige aviso e confirmação. Fechar a folha não desfaz a emissão nem bloqueia “Avançar”. Voltar abre TEL-002 para editar a família existente.

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
| Initial | Rascunho de perfil; formulário de família com fuso padrão e lista inicial vazia em TEL-002; TEL-056 só aparece com membros já criados | Configurações ainda não carregadas |
| Loading | Não aplicável antes de interação | Skeleton para estado confirmado |
| Content | Nome/fuso e membros editáveis em TEL-002; foto antecipada ou omitida; TEL-056 lista membros criados e permite convidar/adiar | Fuso atual, mudança programada e seletor |
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
| Sem membros | `onboarding.members.empty` | “Você pode adicionar pessoas agora ou fazer isso depois.” | TEL-002 |
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

- A ordem VoiceOver é título, explicação, nome, foto opcional, etiqueta, ação primária e cancelar em TEL-055; título, nome, fuso, lista e controles de membros, ação primária e voltar em TEL-002; e título, lista de integrantes já criados, ações de convite, voltar e Avançar em TEL-056. Em TEL-053, título, fuso vigente, alteração programada, seletor e ação.
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
| UX-04 | Revisada: foto escolhida em TEL-055 é enviada antes da criação; falha permite repetir ou seguir sem foto, sem perfil persistido. | Pessoa usuária, 2026-10-19 | Sim; RN01/RN63/RF48 atualizados. |
| UX-05 | TEL-002 prepara os membros; TEL-056 é a etapa de convites após a criação e volta para TEL-002 em modo de edição, sem segunda criação. | Pessoa usuária, 2026-10-19 | Sim; RN01/RN07, RF01/RF38 e UC01/UC02 atualizados. |

## 10. Checklist de aprovação

- [x] Vinculada à SPEC-002 e às superfícies existentes.
- [x] Jornadas, retornos, falhas e preservação de rascunho especificados.
- [x] Estados, i18n e requisitos de acessibilidade definidos.
- [x] Controles proibidos ocultos a Membro e Kids, sem substituir backend.
- [x] SPEC vinculada, contrato técnico e esta UX-spec revisados e aprovados em 2026-10-19; aprovação anterior de 2026-10-06 preservada no histórico.
