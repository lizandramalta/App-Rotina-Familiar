# UX Spec 002: Criar e configurar família

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06
**Spec funcional vinculada:** [SPEC-002-criar-configurar-familia.md](SPEC-002-criar-configurar-familia.md)
**Base funcional:** 1.6
**Superfícies de interface:** TEL-002, TEL-053, MOD-012

## 1. Objetivo da experiência e jornada

- **Visão da experiência:** a pessoa que acabou de entrar com Apple cria sua família sem confundir o grant com uma sessão. Posteriormente, um Administrador encontra e entende o efeito da mudança de fuso antes de confirmá-la.
- **Perfis atendidos:** futuro Criador em TEL-002; Administrador em TEL-053 e MOD-012. Membro e Kids não recebem caminho visual para configurações familiares.

## 2. Rastreabilidade complementar

| Referência | Código / documento |
|---|---|
| Spec vinculada | `SPEC-002-criar-configurar-familia.md` |
| Telas e modal | TEL-002, TEL-053, MOD-012 |
| Fluxos | UF-01, UF-16 |
| Design consultado | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

## 3. Escopo da experiência

- **Dentro:** formulário de nome/fuso, confirmação da criação, configuração do fuso por Administrador, prévia dos efeitos, falhas e recuperação de resultado incerto.
- **Fora:** botão Apple de TEL-001, gestão de membros, navegação e conteúdo de TEL-010/TEL-050 além das entradas e retornos necessários.

## 4. Jornada, navegação e preservação de contexto

| Origem | Ação | Destino | Retorno / cancelamento | Preservação |
|---|---|---|---|---|
| TEL-001 | Backend entrega `creationGrant` | TEL-002 | Cancelar volta a TEL-001 sem salvar | Grant fica somente em memória |
| TEL-002 | Enviar dados válidos e criação confirmada | TEL-010 | — | Sessão confirmada passa à raiz do app |
| TEL-002 | Resposta incerta | TEL-002 com alerta | “Verificar acesso” retorna a TEL-001 | Nome e fuso ficam em memória até o resultado da nova entrada |
| TEL-050 | Administrador abre configurações | TEL-053 | Voltar preserva a origem em Família | Estado confirmado é recarregado ao retornar |
| TEL-053 | Selecionar novo fuso | MOD-012 | Cancelar volta a TEL-053 sem gravar | Seleção permanece para nova escolha |
| MOD-012 | Confirmar aplicação | TEL-053 | — | Exibe apenas estado confirmado pela API |

## 5. Superfícies e componentes

### 5.1. TEL-002 — Criar família

- **Objetivo:** coletar nome e fuso inicial e criar a família autorizada pelo grant.
- **Anatomia:** título; explicação curta; campo de nome; seletor pesquisável de fuso IANA com `America/Sao_Paulo` pré-selecionado; botão primário de criação; ação secundária de cancelar.
- **Comportamento:** o botão só envia com nome localmente válido. O servidor continua sendo a autoridade. Cancelar descarta o formulário e retorna a TEL-001.

### 5.2. TEL-053 — Configurações da família

- **Objetivo:** mostrar fuso vigente, alteração programada quando existir e iniciar uma mudança consciente.
- **Anatomia:** título; valor do fuso vigente; resumo de alteração programada; seletor de fuso; ação “Ver efeitos”; sem controles administrativos para Membro/Kids, que não navegam para esta tela.
- **Comportamento:** seleção não persiste. A prévia solicitada abre MOD-012 e o estado confirmado permanece visível até nova resposta de API.

### 5.3. MOD-012 — Efeitos da alteração de fuso

- **Objetivo:** apresentar o fuso proposto, o modo de aplicação e os limites efetivos devolvidos pela prévia.
- **Anatomia:** título, resumo do fuso atual/proposto, aviso de ciclo de transição quando aplicável, opção explícita para aplicar agora ou no próximo ciclo, ações Cancelar e Confirmar.
- **Comportamento:** confirmar entra em `Submitting`; cancelar nunca grava. O modal não promete sucesso até a resposta confirmada.

## 6. Estados de interface

| Estado | TEL-002 | TEL-053 / MOD-012 |
|---|---|---|
| Initial | Formulário vazio com fuso padrão | Configurações ainda não carregadas |
| Loading | Não aplicável antes de interação | Skeleton para estado confirmado |
| Content | Nome/fuso editáveis | Fuso atual, mudança programada e seletor |
| Submitting | Botão bloqueado com progresso | Confirmação bloqueia ações duplicadas |
| Error não bloqueante | Campos preservados, erro localizado | Estado confirmado preservado; erro e nova tentativa |
| Resultado incerto | Orienta verificar o acesso por Apple; não marca criação como concluída | Não afirma alteração; mantém seleção para ação explícita |
| Offline | Informa indisponibilidade sem perder rascunho | Mostra último estado confirmado, sem permitir confirmar |

Não há estado vazio: a criação é um formulário e a configuração sempre possui fuso vigente após carregar.

## 7. Microcopy e i18n

| Elemento | Chave | Texto pt-BR proposto | Cenário |
|---|---|---|---|
| Título | `family.create.title` | “Crie sua família” | TEL-002 |
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

- A ordem VoiceOver é título, explicação, nome, fuso, ação primária e cancelar; em TEL-053, título, fuso vigente, alteração programada, seletor e ação.
- O seletor anuncia o fuso selecionado; MOD-012 anuncia se haverá transição e o modo escolhido. Erros e alertas usam anúncio acessível.
- Todos os textos usam Dynamic Type, sem truncar nome do fuso, datas ou explicação de transição.
- Cor nunca é a única indicação de erro, alteração programada ou transição; usar texto e ícone semântico com contraste WCAG AA.
- Alvos de toque têm no mínimo 44×44 pt. Em iPad, TEL-002 e TEL-053 usam coluna/formulário centralizado de até 540 pt; MOD-012 é `Form Sheet`.

## 9. Decisões e esclarecimentos de UX

| # | Decisão | Situação | Altera comportamento? |
|---|---|---|---|
| UX-01 | Apenas Administrador visualiza a entrada para TEL-053 e os controles de fuso. O backend permanece a autoridade. | Decidida em 2026-10-06 | Não; aplica RNF07/RF67 |
| UX-02 | Resposta incerta na criação preserva o rascunho e oferece verificação por nova entrada Apple, sem retry automático. | Decidida em 2026-10-06 | Não; aplica RNF12 |
| UX-03 | MOD-012 apresenta prévia antes de qualquer gravação e não trata prévia como reserva. | Decidida em 2026-10-06 | Não |

## 10. Checklist de aprovação

- [x] Vinculada à SPEC-002 e às superfícies existentes.
- [x] Jornadas, retornos, falhas e preservação de rascunho especificados.
- [x] Estados, i18n e requisitos de acessibilidade definidos.
- [x] Controles proibidos ocultos a Membro e Kids, sem substituir backend.
- [x] Base funcional atualizada e SPEC vinculada aprovada.
