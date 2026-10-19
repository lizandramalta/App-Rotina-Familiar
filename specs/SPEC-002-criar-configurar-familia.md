# Spec 002: Criar e configurar família

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-19
**Base funcional:** RN 1.18 / RF 1.17 / UC 1.16
**UX-spec:** [UX-002-criar-configurar-familia.md](UX-002-criar-configurar-familia.md)
**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 1 - Acesso, família e perfis

## 1. Contexto e Objetivo

- **Problema / Necessidade:** depois do Sign in with Apple, uma pessoa sem família precisa configurar a própria identificação, criar o espaço comum e, já como Criador, poder incluir os primeiros integrantes sem ser forçada a fazê-lo. A família também precisa manter um fuso comum, configurável somente por Administradores, sem corromper ciclos ou reconhecimentos já encerrados.
- **Objetivo da entrega:** consumir o `creationGrant` emitido em `SPEC-001`, enviar opcionalmente a foto protegida antes da criação e criar atomicamente família, Criador/Administrador e membros preparados em TEL-002. TEL-056 oferece os convites após a criação, quando houver membros.

## 2. Rastreabilidade e Dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Casos de uso | UC01; UC02 no recorte de membros preparados e convites iniciais |
| Regras de negócio | RN01, RN07, RN09, RN28, RN44–RN46, RN63, RN65 |
| Requisitos funcionais | RF01–RF03, RF38–RF41, RF48, RF67 |
| Requisitos não funcionais | RNF06, RNF07, RNF08, RNF12, RNF13 |
| Telas e fluxos de navegação | TEL-055, TEL-002, TEL-056, TEL-034, TEL-053, MOD-012, UF-01, UF-12, UF-16 |
| Decisões arquiteturais aplicáveis | MA-18; MA: calendário, navegação e autorização mobile; BA-07, BA-08, BA-13, BA-20, BA-21, BA-35, BA-36 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-architecture.md`, `docs/architecture/mobile-feature-catalog.md`, `docs/architecture/backend-architecture.md`, `docs/architecture/backend-contracts.md`, `docs/architecture/backend-decisions.md`.
- **Depende de:** [SPEC-001-autenticar-com-apple.md](SPEC-001-autenticar-com-apple.md), aprovada. Esta entrega consome o `creationGrant` de dez minutos definido em BA-21.
- **Dependências externas e infraestrutura:** Sign in with Apple já entregue como pré-requisito; banco transacional e sessão própria do backend.

## 3. Escopo da Entrega

### 3.1. Dentro do escopo

- TEL-055: rascunho do perfil inicial, com nome administrativo obrigatório, apelido e foto opcionais; a foto escolhida é enviada antes da criação, com proteção e vínculo exclusivo ao futuro Criador. Falha permite repetir ou seguir sem foto, sem persistir perfil ou conceder acesso familiar.
- TEL-002: nome e fuso da família e zero ou mais membros com nome e papel, que podem ser adicionados, alterados e retirados do rascunho antes da confirmação.
- Criação de família, Criador com marca `isFamilyCreator`, ciclo inicial, sessão e todos os membros preparados em uma única operação. Falha em qualquer parte não deixa família ou perfil parcialmente criado; convite nunca é emitido automaticamente.
- TEL-056: após criação com membros, lista os perfis já criados e oferece o convite explícito de SPEC-004 para cada um, com opção de adiar e avançar. Sem membros, TEL-002 segue diretamente para TEL-010.
- Retorno de TEL-056 a TEL-002 em modo de edição da família existente: prosseguir sem mudanças não grava; mudanças autorizadas são salvas sem criar outra família. Inclusão posterior de membro usa as permissões e operação persistente de SPEC-003; mudança posterior do fuso usa TEL-053/MOD-012.
- Fuso inicial padrão `America/Sao_Paulo`, com escolha explícita na criação.
- Leitura da configuração vigente e de alteração programada em `GET /v1/family/settings`.
- Prévia não persistente e confirmação da alteração de fuso por Administrador, com `immediate` ou `nextCycle`.
- TEL-055, TEL-002, TEL-056, TEL-053 e MOD-012, seus estados de erro e a ocultação visual de configuração para quem não é Administrador.

### 3.2. Fora do escopo

- Gestão persistente de membros depois da criação, convite e ingresso (SPEC-003 a SPEC-005); esta SPEC inclui os membros iniciais na criação da família e TEL-056 apenas oferece convites.
- Edição posterior de apelido/foto, consulta de perfil e badges (SPEC-006), tarefas, relatórios, missões e destaque semanal.
- Implementação do login Apple, emissão ou renovação de sessão: pertencem a SPEC-001.

### 3.3. Fora de questão

- Não existe criação de mais de uma família para a mesma identidade Apple.
- `creationGrant` não é sessão de membro, não transporta papel e não autoriza leituras de dados familiares.
- Não há login por senha/e-mail, troca de família, transferência de histórico ou seleção de perfil.
- Membros e Kids não visualizam nem podem executar alteração de fuso.
- A troca de fuso não desloca datas civis de tarefas, não reapura ciclos já finalizados e não revisa destaque semanal já encerrado.

## 4. Perfis, Atores e Regras de Autorização (RBAC)

| Perfil / situação | Pode | Não pode | Reação do sistema |
|---|---|---|---|
| Identidade Apple sem família | Usar o próprio `creationGrant` para preparar perfil, membros e foto protegida e criar uma família | Consultar dados familiares, exercer gestão administrativa ou criar perfis persistentes isoladamente | Grant inválido é recusado; nenhuma sessão de membro antes da criação |
| Criador / Administrador | Gerir a própria família e membros após a criação e configurar seu fuso pelo fluxo autorizado | Alterar outra família, vincular mídia de terceiro ou confiar em `familyId`/`memberId` do cliente | Escopo derivado da sessão e permissões administrativas revalidadas |
| Membro | Usar a família conforme capacidades futuras | Ler configurações ou alterar fuso | `403 ACTION_NOT_ALLOWED`; ação oculta na UI |
| Kids | Nenhuma ação desta entrega | Ler configurações ou alterar fuso | `403 ACTION_NOT_ALLOWED`; ação oculta na UI |

- **Isolamento familiar (RNF06):** a família é derivada exclusivamente do grant ou da sessão autenticada. `familyId`, papel, flag de Criador, ciclos ou datas enviados pelo cliente não são aceitos como autoridade; campos desconhecidos são rejeitados.
- **Autorização no backend (RNF07):** a capacidade de configurar o fuso é conferida pelo backend em todas as rotas protegidas, inclusive após o lock transacional. A ocultação no mobile é apenas uma proteção de experiência.

## 5. Contrato de Dados, Interface e Validações

### 5.1. Dicionário de campos

| Campo | Tipo | Obrigatório | Validação | Erro de campo |
|---|---|---:|---|---|
| `creationGrant` | string opaca | Sim | Grant emitido para a identidade Apple sem família, válido por 10 minutos e restrito a uma criação | — |
| `creatorName` | string | Sim | Após trim, 1–60 caracteres Unicode visíveis e sem caracteres de controle | `MEMBER_NAME_REQUIRED`, `MEMBER_NAME_INVALID_LENGTH`, `MEMBER_NAME_INVALID_CONTENT` |
| `creatorNickname` | string ou `null` | Não | Opcional; limite e remoção seguem RF48/RN63; ausência ou `null` não configura apelido | `NICKNAME_INVALID_LENGTH` |
| `name` | string | Sim | Após trim, de 1 a 60 caracteres Unicode visíveis; não aceita somente espaços nem caracteres de controle | `FAMILY_NAME_REQUIRED`, `FAMILY_NAME_INVALID_LENGTH`, `FAMILY_NAME_INVALID_CONTENT` |
| `timeZoneId` | string | Não | Identificador IANA válido; ausência usa `America/Sao_Paulo` | `TIME_ZONE_ID_INVALID` |
| `initialMembers` | lista de `{name, role}` | Não | Zero ou mais; papéis `administrator`, `member` ou `kids`; rascunho sem persistência separada | Validação de qualquer item impede toda a criação |
| `creatorPhotoMediaId` | UUID de mídia protegida | Não | Só pode vincular foto `READY` enviada com o mesmo grant e instalação para este onboarding | `PHOTO_MEDIA_NOT_READY`, `PHOTO_MEDIA_NOT_OWNED` ou `PHOTO_MEDIA_PURPOSE_MISMATCH` |
| `application` | enum | Sim, apenas em mudança de fuso | `immediate` ou `nextCycle` | `TIME_ZONE_APPLICATION_INVALID` |

### 5.2. Rotas e respostas

#### Criar família

- **Comando de criação:** `POST /v1/families` recebe `creationGrant`, `creatorName`, `creatorNickname` opcional, `name`, `timeZoneId` opcional, `initialMembers` opcional e `creatorPhotoMediaId` opcional; a prova de instalação permanece no header. O corpo implementado anteriormente ainda não aceita os dois últimos campos.
- **Autenticação:** `creationGrant` restrito à identidade Apple; não usa Bearer de membro.

- **Sucesso esperado:** `201` devolve `family`, `member` (Criador), `initialMembers: [{id, name, role}]` e `session`. Não há sucesso parcial nem convites gerados implicitamente.

#### Enviar foto inicial opcional antes da criação

A escolha da foto em TEL-055 inicia `POST /v1/onboarding/media` multipart com `creationGrant`, `purpose: profilePhoto`, arquivo e prova de instalação no header, sem Bearer de membro. A mídia permanece protegida e ligada ao grant até `POST /v1/families` vinculá-la ao Criador no mesmo commit. Grant novo exige novo upload; foto não vinculada é limpa após 24 horas. A rota atual `/v1/media` autenticada continua voltada à edição de perfil (SPEC-006) e à sinalização Kids.

| Entrada | Regra | Recusa |
|---|---|---|
| Foto do onboarding | Imagem do próprio futuro Criador, opcional, protegida antes da família; processamento segue os limites de foto de perfil vigentes | Falha de envio permite repetir ou seguir sem foto; mídia alheia não pode ser vinculada |

No retorno de TEL-056, `GET /v1/family` e `GET /v1/family/members` carregam a versão confirmada. Rascunho sem diferenças não envia comando. Nome alterado usa `PATCH /v1/family`; inclusões e alterações de membros usam as rotas da SPEC-003, e fuso posterior usa as rotas de Configurações. Cada comando posterior tem resultado próprio e exige sessão de Administrador; `POST /v1/families` nunca é repetido.

O mobile não trata o envio como confirmação de criação, não repete automaticamente uma escrita incerta e permite continuar sem foto. Falha da criação não deixa perfis parcialmente persistidos; eventual mídia antecipada não concede acesso a dados familiares.

#### Configurações de fuso

| Rota | Finalidade | Entrada / saída | Acesso |
|---|---|---|---|
| `GET /v1/family/settings` | Estado confirmado | `timeZoneId`, eventual `scheduledTimeZoneChange` e limites do ciclo atual | Administrador |
| `POST /v1/family/time-zone-changes/preview` | Prévia sem gravação | `timeZoneId`, `application` → fuso proposto, limites efetivos estimados e indicação de transição | Administrador |
| `POST /v1/family/time-zone-changes` | Confirmação | `timeZoneId`, `application` → configuração confirmada e limites efetivos | Administrador |

O servidor recalcula os limites no commit; uma prévia não reserva estado. Em aplicação imediata, preserva o início do ciclo aberto e fixa o próximo encerramento válido no novo fuso. Em `nextCycle`, preserva o ciclo atual e programa a mudança para seu encerramento.

As três rotas respondem `200` com `Cache-Control: no-store`. `GET` e confirmação devolvem `timeZoneId`, `scheduledTimeZoneChange` (`{timeZoneId, effectiveAt}` ou `null`) e `limits` (`{startsAt, endsAt, timeZoneId, isTransition}`). A prévia devolve `proposedTimeZoneId`, `application`, `effectiveAt`, `effectiveLimits` e `isTransition`. Instantes em ISO 8601 UTC.

### 5.3. Erros, concorrência e resultado incerto

| HTTP | Código | Situação |
|---:|---|---|
| 400 | `UNKNOWN_FIELD` | Campo não reconhecido, inclusive `familyId`, papel do Criador ou estado enviado pelo cliente; papel dos membros iniciais é dado permitido |
| 401 | `CREATION_GRANT_INVALID` | Grant ausente, inválido, expirado ou não utilizável |
| 403 | `ACTION_NOT_ALLOWED` | Sessão válida sem papel Administrador para configurações de fuso |
| 404 | `RESOURCE_NOT_FOUND` | Recurso de outra família ou indisponível ao ator |
| 422 | `VALIDATION_FAILED` | Nome do Criador, da família ou de membro inicial, papel inicial, fuso ou modo de aplicação semanticamente inválido; inclui `fieldErrors` |
| 422 | `VALIDATION_FAILED` com `fieldErrors.timeZoneId = TIME_ZONE_UNCHANGED` | O fuso pedido já é o vigente, na prévia e na confirmação |
| 413 | `MEDIA_TOO_LARGE` | Arquivo de foto acima do limite operacional de entrada |
| 415 | `MEDIA_FORMAT_UNSUPPORTED` | Arquivo sem formato de imagem reconhecível |
| 422 | `VALIDATION_FAILED` com `fieldErrors.creatorPhotoMediaId` | Mídia ausente/não pronta, de outro grant/instalação ou com finalidade diferente; não cria família parcial |
| 503 | `DEPENDENCY_UNAVAILABLE` | Persistência incerta; não afirmar reversão da gravação |

- Todas as falhas usam `application/problem+json`, com `type`, `title`, `status`, `code`, `requestId` e `fieldErrors` quando aplicável.
- A criação e a mudança de fuso usam transação curta e lock da família/identidade aplicável (BA-08). Não existe `Idempotency-Key`, replay automático nem controle de versão otimista.
- Em resposta perdida de `POST /v1/families`, o mobile não repete a gravação automaticamente. Preserva o rascunho e direciona a pessoa a autenticar-se novamente com Apple; se a criação tiver persistido, a família vinculada é descoberta, e se não tiver, novo grant permite retomar o formulário.

## 6. Estados de domínio e transições

| Estado de | Evento | Estado para | Autor | Garantias |
|---|---|---|---|---|
| Identidade Apple sem família | Criar família com grant válido | Família ativa; Criador/Admin, membros iniciais e sessão ativa | Identidade validada | Uma única associação; criação atômica, sem convite automático |
| Fuso vigente | Aplicar `immediate` | Novo fuso vigente; ciclo aberto de transição | Administrador | Início preservado; novo fim é a próxima segunda-feira local válida |
| Fuso vigente | Aplicar `nextCycle` | Alteração programada | Administrador | Ciclo aberto preservado; última solicitação válida pode substituir programação anterior |
| Alteração programada | Encerramento do ciclo | Novo fuso vigente | Sistema | Ciclos contíguos, sem sobreposição; resultados já finalizados preservados |

## 7. Critérios de Aceitação

- **CA-01: criação atômica com grant válido**
  - **DADO QUE** uma identidade Apple validada não possui família e recebeu `creationGrant` válido,
  - **QUANDO** confirmar TEL-002 com nome do Criador, nome/fuso da família e zero ou mais membros iniciais válidos,
  - **ENTÃO O SISTEMA DEVE** criar família, Criador Administrador, ciclo inicial, sessão e todos os membros preparados na mesma operação,
  - **E** não persistir parte do conjunto se qualquer membro for inválido ou a operação falhar; a resposta confirmada deve incluir os membros criados, sem emitir convites automaticamente. *(UC01/UC02, RF01/RF02/RF38/RF40, RN01/RN07, BA-21)*

- **CA-02: fuso padrão e validação do nome**
  - **DADO QUE** o Criador preenche TEL-002,
  - **QUANDO** omitir `timeZoneId`,
  - **ENTÃO O SISTEMA DEVE** usar `America/Sao_Paulo`,
  - **E** rejeitar nome vazio, com mais de 60 caracteres visíveis ou contendo caracteres de controle com `422 VALIDATION_FAILED` e erro de campo correspondente. *(RF01/RF67; decisão E-01 desta spec)*

- **CA-03: associação única e resultado incerto**
  - **DADO QUE** duas tentativas concorrem para criar família da mesma identidade Apple ou uma resposta de criação se perde,
  - **QUANDO** uma criação for confirmada,
  - **ENTÃO O SISTEMA DEVE** manter uma única associação familiar para a identidade,
  - **E** uma nova autenticação Apple DEVE permitir descobrir a família existente, sem duplicar família. *(RN09, BA-08, BA-21, RNF12)*

- **CA-04: grant e entradas não autorizam atribuição indevida**
  - **DADO QUE** o cliente envia grant inválido/expirado ou inclui `familyId`, papel, flag de Criador ou estado no comando,
  - **QUANDO** a criação for processada,
  - **ENTÃO O SISTEMA DEVE** recusar grant inválido com `401 CREATION_GRANT_INVALID` e campos desconhecidos com `400 UNKNOWN_FIELD`,
  - **E** não DEVE persistir família parcial nem aceitar `familyId`, papel do Criador ou flag de Criador fornecidos pelo cliente; papéis dos membros iniciais seguem RF40. *(RNF06, RNF07, BA-20)*

- **CA-05: leitura de configurações restrita**
  - **DADO QUE** existe uma sessão ativa de Membro ou Kids,
  - **QUANDO** chamar `GET /v1/family/settings` ou uma rota de mudança de fuso,
  - **ENTÃO O SISTEMA DEVE** responder `403 ACTION_NOT_ALLOWED`,
  - **E** a interface NÃO DEVE exibir TEL-053 ou controles de alteração a esses perfis. *(RF67, RN28, RNF07)*

- **CA-06: aplicação imediata do fuso**
  - **DADO QUE** um Administrador visualiza a prévia de um fuso IANA válido em MOD-012,
  - **QUANDO** confirmar `application: "immediate"`,
  - **ENTÃO O SISTEMA DEVE** persistir o novo fuso e preservar o início do ciclo aberto,
  - **E** calcular o próximo encerramento na próxima segunda-feira local válida, estritamente após a mudança. *(RN28, RF67, BA-13)*

- **CA-07: aplicação no próximo ciclo**
  - **DADO QUE** um Administrador visualiza a prévia de um fuso IANA válido,
  - **QUANDO** confirmar `application: "nextCycle"`,
  - **ENTÃO O SISTEMA DEVE** manter o fuso e o limite do ciclo em curso,
  - **E** expor a alteração programada até a entrada do novo fuso no encerramento do ciclo. *(RN28, RF67, BA-13)*

- **CA-08: preservação dos efeitos históricos**
  - **DADO QUE** há tarefas com datas civis, ciclos encerrados ou destaque semanal finalizado,
  - **QUANDO** o fuso for alterado por qualquer modo válido,
  - **ENTÃO O SISTEMA DEVE** preservar as datas civis e os resultados finalizados,
  - **E** identificar a transição excepcional para consultas e relatórios futuros. *(RN28, RN65)*

- **CA-09: cancelamento e falha de persistência**
  - **DADO QUE** o Criador ou Administrador iniciou um formulário ou uma mudança de fuso,
  - **QUANDO** cancelar, houver falha de rede ou o resultado da gravação for incerto,
  - **ENTÃO O SISTEMA NÃO DEVE** apresentar a alteração como salva,
  - **E** DEVE preservar o conteúdo digitado, informar o próximo passo e exigir nova ação explícita para gravar. *(UC01, RNF12, RNF13)*

- **CA-10: foto inicial opcional não bloqueia a família nem a entrada**
  - **DADO QUE** o futuro Criador escolhe uma foto em TEL-055 antes de criar a família,
  - **QUANDO** o envio protegido for confirmado ou falhar,
  - **ENTÃO O SISTEMA DEVE** permitir repetir ou seguir sem foto após falha, sem criar perfil nem conceder acesso familiar,
  - **E** somente a criação confirmada pode vincular a mídia válida ao próprio Criador; a foto permanece opcional. *(UC01, RF01/RF48, RN01/RN63, RNF12–RNF13)*

- **CA-11: membros iniciais e convite são opcionais e explícitos**
  - **DADO QUE** TEL-002 contém zero ou mais membros preparados,
  - **QUANDO** a criação da família for confirmada,
  - **ENTÃO O APP DEVE** abrir TEL-010 diretamente se não houver membros ou abrir TEL-056 com os perfis já criados quando houver,
  - **E** TEL-056 DEVE oferecer convite inicial explícito, com compartilhamento direto e possibilidade de adiar, sem criar outro membro ou repetir a criação. *(UC01/UC02, RF02/RF38/RF40/RF41)*

- **CA-12: retorno de TEL-056 à família existente**
  - **DADO QUE** a família já foi criada e o Criador volta de TEL-056 a TEL-002,
  - **QUANDO** prosseguir sem alterações ou salvar alterações autorizadas,
  - **ENTÃO O APP NÃO DEVE** executar novamente a criação nem gravar se nada mudou,
  - **E** mudanças em família e membros seguem as permissões vigentes; alteração posterior do fuso segue a prévia e confirmação de TEL-053/MOD-012. *(UC01/UC02, RN01/RN07/RN28, RF01/RF03/RF67)*

## 8. Observabilidade, métricas e auditoria

| Evento | Gatilho | Dados permitidos |
|---|---|---|
| `family_created` | Criação confirmada | `familyId`, `timeZoneId` |
| `family_creation_rejected` | Grant ou validação recusada | `requestId`, motivo técnico sem grant/nome em claro |
| `family_time_zone_changed` | Aplicação confirmada | `familyId`, fuso anterior/novo, modo e limites efetivos |
| `family_time_zone_change_denied` | Tentativa sem permissão | `requestId`, ator, rota |

Segredos, tokens, `creationGrant`, cabeçalhos de instalação e dados de autenticação nunca entram em logs ou telemetria.

## 9. Premissas e esclarecimentos

| # | Decisão | Situação | Altera `docs/`? |
|---|---|---|---|
| E-01 | Nome da família: 1–60 caracteres Unicode visíveis após trim; sem apenas espaços ou caracteres de controle. | Decidida em 2026-10-06; sincronizada em RF01 | Sim — atualizado em `docs/02-requisitos.md` 1.6 |
| E-02 | `creationGrant` é enviado no corpo com o nome `creationGrant`. | Decidida em 2026-10-06 | Não |
| E-03 | Revisada: a resposta de criação inclui `initialMembers` com IDs dos perfis já criados, além de família, Criador e sessão; contrato em `backend-contracts.md` 1.16. | Pessoa usuária / 2026-10-19 | Sim — RN01, RF01/RF40 e UC01 atualizados. |
| E-04 | Códigos de erro definidos na seção 5.3. | Decidida em 2026-10-06 | Não |
| E-05 | Resultado incerto preserva rascunho e pede nova autenticação Apple, sem retry automático. | Decidida em 2026-10-06 | Não |
| E-06 | Revisada em 2026-10-19: a foto escolhida em TEL-055 é enviada antes da criação; falha permite repetir ou seguir sem foto, e só a criação confirmada a vincula ao próprio Criador. | Pessoa usuária / 2026-10-19 | Sim — RN01/RN63, RF01/RF48 e UC01 atualizados. |
| E-07 | Sem worker de apuração, um ciclo aberto vencido é liquidado antes de ler ou alterar o fuso: criam-se os ciclos semanais contíguos que faltam, sem apurar destaque, que continua na SPEC-020. | Pessoa usuária / 2026-10-08 | Sim — `backend-architecture.md` §11 |
| E-08 | Uma alteração `nextCycle` entra em vigor de forma preguiçosa, sob o lock da família, na primeira leitura ou alteração após o encerramento do ciclo. O worker futuro reutiliza a mesma operação. | Pessoa usuária / 2026-10-08 | Sim — `backend-architecture.md` §11 |
| E-09 | Pedir o fuso já vigente é recusado com `TIME_ZONE_UNCHANGED`. Uma mudança programada só é substituída por outra solicitação válida de fuso diferente, e não há cancelamento sem novo fuso. | Pessoa usuária / 2026-10-08 | Sim — `backend-contracts.md` §3 |
| E-10 | TEL-002 prepara membros antes da criação; família, Criador e membros iniciais são criados juntos. TEL-056 apenas oferece convite após a criação. | Pessoa usuária / 2026-10-19 | Sim — RN01/RN07/RN45, RF01/RF02/RF38/RF40 e UC01/UC02. |
| E-11 | Voltar de TEL-056 abre TEL-002 em edição da família existente; sem mudanças não há gravação, e o fuso posterior segue Configurações. | Pessoa usuária / 2026-10-19 | Sim — RN01, RF01/RF03/RF67 e UC01/UC02. |

**Contrato técnico revisado:** `backend-contracts.md` 1.16 e BA-35/BA-36 definem upload com grant, criação conjunta e comandos posteriores de edição. As rotas e o schema anteriores ainda precisam ser ampliados no backend; esta revisão não os declara implementados.

## 10. Fases de implementação e conclusão

| Fase | Objetivo | CAs | Prontidão | Status |
|---|---|---|---|---|
| 1 | Onboarding seguro: grant, foto antecipada, criação atômica de família/Criador/membros, sessão, validação, isolamento e TEL-055/TEL-002 | CA-01 a CA-04, CA-09, CA-10 | Contratos revisados e testes unitários, integração e UI verdes | em andamento — backend anterior SCRUM-18 não cobre membros/foto antecipada; Mobile pendente (SCRUM-20) |
| 2 | TEL-056 oferece convites após criação com membros; retorno a TEL-002 edita a família existente sem nova criação | CA-11, CA-12 | Testes de UI/iPhone/iPad e integração com SPEC-003/SPEC-004 verdes | a fazer |
| 3 | Configuração de fuso: leitura, prévia, confirmação, RBAC e TEL-053/MOD-012 | CA-05 a CA-08 | Testes de integração temporal e UX-spec verificada | em andamento — backend concluído (SCRUM-21); Mobile pendente (SCRUM-22) |
| 4 | Auditoria, telemetria segura e regressão de transições | CA-03, CA-08 a CA-11 | Regressão verde e QA | a fazer |

**Registro de execução (2026-10-19):** SCRUM-18 entregou a transação anterior de criação no backend; ela precisa ser ampliada para membros iniciais e foto antecipada. SCRUM-21 entregou leitura, prévia e alteração de fuso. As telas Mobile das Fases 1 e 3 ainda não foram concluídas.

- **Fase 1:** não publica a alteração posterior de fuso; a família nasce com o fuso escolhido. Não deve ser publicada isoladamente sem a fase necessária de SPEC-001 que emite grant e sessão.
- **Fase 2:** usa perfis já criados para convidar. Sem membros, TEL-056 não é aberta; no retorno, novas inclusões seguem SPEC-003.
- **Fase 3:** não adiciona membros, tarefas ou relatórios; apenas expõe a configuração permitida do fuso.
- **Fase 4:** não muda comportamento funcional; fortalece diagnóstico e cenários de transição.

## 11. Checklist de aprovação

- [x] Códigos funcionais, UX e arquiteturais pesquisados e existentes.
- [x] Dependência SPEC-001 aprovada e contrato de grant considerado.
- [x] RBAC e isolamento incluídos na Fase 1.
- [x] Contratos de foto antes da criação, membros iniciais e edição no retorno reconciliados com backend e mobile; implementação pendente.
- [x] UX-spec vinculada.
- [x] Base funcional atualizada com o limite do nome familiar (E-01).
- [x] Revisão de 2026-10-19 aprovada; aprovação anterior de 2026-10-06 preservada no histórico.
