# Spec 002: Criar e configurar família

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06
**Base funcional:** 1.6
**UX-spec:** [UX-002-criar-configurar-familia.md](UX-002-criar-configurar-familia.md)
**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 1 - Acesso, família e perfis

## 1. Contexto e Objetivo

- **Problema / Necessidade:** depois do Sign in with Apple, uma pessoa ainda sem família precisa criar o espaço comum que delimita membros, calendário e dados. A família também precisa manter um fuso comum, configurável somente por Administradores, sem corromper ciclos ou reconhecimentos já encerrados.
- **Objetivo da entrega:** consumir o `creationGrant` emitido em `SPEC-001`, criar atomically a família e seu Criador/Administrador, e permitir a configuração segura do fuso familiar com aplicação imediata ou no próximo ciclo semanal.

## 2. Rastreabilidade e Dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Casos de uso | UC01 |
| Regras de negócio | RN01, RN09, RN28, RN44, RN65 |
| Requisitos funcionais | RF01, RF38, RF39, RF67 |
| Requisitos não funcionais | RNF06, RNF07, RNF08, RNF12, RNF13 |
| Telas e fluxos de navegação | TEL-002, TEL-053, MOD-012, UF-01, UF-16 |
| Decisões arquiteturais aplicáveis | MA: calendário, navegação e autorização mobile; BA-07, BA-08, BA-13, BA-20, BA-21 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-architecture.md`, `docs/architecture/mobile-feature-catalog.md`, `docs/architecture/backend-architecture.md`, `docs/architecture/backend-contracts.md`, `docs/architecture/backend-decisions.md`.
- **Depende de:** [SPEC-001-autenticar-com-apple.md](SPEC-001-autenticar-com-apple.md), aprovada. Esta entrega consome o `creationGrant` de dez minutos definido em BA-21.
- **Dependências externas e infraestrutura:** Sign in with Apple já entregue como pré-requisito; banco transacional e sessão própria do backend.

## 3. Escopo da Entrega

### 3.1. Dentro do escopo

- `POST /v1/families`: criação de uma família por uma identidade Apple sem vínculo, com `creationGrant`, nome e fuso IANA.
- Criação, na mesma transação, da família, do membro Criador com papel `administrator`, da marca `isFamilyCreator`, do ciclo semanal inicial e da sessão.
- Fuso inicial padrão `America/Sao_Paulo`, com escolha explícita na criação.
- Leitura da configuração vigente e de alteração programada em `GET /v1/family/settings`.
- Prévia não persistente e confirmação da alteração de fuso por Administrador, com `immediate` ou `nextCycle`.
- TEL-002, TEL-053 e MOD-012, seus estados de erro e a ocultação visual de configuração para quem não é Administrador.

### 3.2. Fora do escopo

- Criar, convidar, editar ou remover outros membros (SPEC-003 a SPEC-005).
- Perfil, foto e apelido (SPEC-006), tarefas, relatórios, missões e destaque semanal.
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
| Identidade Apple sem família | Consumir o próprio `creationGrant` para criar uma família | Consultar família ou configurar fuso | `401 CREATION_GRANT_INVALID` para grant inválido; nenhuma sessão de membro antes da criação |
| Criador / Administrador | Consultar e alterar o fuso da própria família | Alterar outra família ou confiar em `familyId` do cliente | `404 RESOURCE_NOT_FOUND` para recursos externos; escopo derivado da sessão |
| Membro | Usar a família conforme capacidades futuras | Ler configurações ou alterar fuso | `403 ACTION_NOT_ALLOWED`; ação oculta na UI |
| Kids | Nenhuma ação desta entrega | Ler configurações ou alterar fuso | `403 ACTION_NOT_ALLOWED`; ação oculta na UI |

- **Isolamento familiar (RNF06):** a família é derivada exclusivamente do grant ou da sessão autenticada. `familyId`, papel, flag de Criador, ciclos ou datas enviados pelo cliente não são aceitos como autoridade; campos desconhecidos são rejeitados.
- **Autorização no backend (RNF07):** a capacidade de configurar o fuso é conferida pelo backend em todas as rotas protegidas, inclusive após o lock transacional. A ocultação no mobile é apenas uma proteção de experiência.

## 5. Contrato de Dados, Interface e Validações

### 5.1. Dicionário de campos

| Campo | Tipo | Obrigatório | Validação | Erro de campo |
|---|---|---:|---|---|
| `creationGrant` | string opaca | Sim | Grant emitido para a identidade Apple sem família, válido por 10 minutos e restrito a uma criação | — |
| `name` | string | Sim | Após trim, de 1 a 60 caracteres Unicode visíveis; não aceita somente espaços nem caracteres de controle | `FAMILY_NAME_REQUIRED`, `FAMILY_NAME_INVALID_LENGTH`, `FAMILY_NAME_INVALID_CONTENT` |
| `timeZoneId` | string | Não | Identificador IANA válido; ausência usa `America/Sao_Paulo` | `TIME_ZONE_ID_INVALID` |
| `application` | enum | Sim, apenas em mudança de fuso | `immediate` ou `nextCycle` | `TIME_ZONE_APPLICATION_INVALID` |

### 5.2. Rotas e respostas

#### Criar família

- **Método e rota:** `POST /v1/families`
- **Autenticação:** `creationGrant` no corpo; não usa Bearer de membro.

```json
{
  "creationGrant": "opaque-grant",
  "name": "Casa Silva",
  "timeZoneId": "America/Sao_Paulo"
}
```

- **Sucesso:** `201 Created`, `Location: /v1/family`.

```json
{
  "family": {
    "id": "uuid",
    "name": "Casa Silva",
    "timeZoneId": "America/Sao_Paulo",
    "createdAt": "2026-10-06T12:00:00Z"
  },
  "member": {
    "id": "uuid",
    "role": "administrator",
    "isFamilyCreator": true
  },
  "session": {
    "sessionId": "uuid",
    "memberId": "uuid",
    "familyId": "uuid",
    "role": "administrator",
    "isFamilyCreator": true,
    "accessToken": "opaque-token",
    "accessTokenExpiresAt": "2026-10-06T12:15:00Z",
    "refreshToken": "opaque-token"
  }
}
```

#### Configurações de fuso

| Rota | Finalidade | Entrada / saída | Acesso |
|---|---|---|---|
| `GET /v1/family/settings` | Estado confirmado | `timeZoneId`, eventual `scheduledTimeZoneChange` e limites do ciclo atual | Administrador |
| `POST /v1/family/time-zone-changes/preview` | Prévia sem gravação | `timeZoneId`, `application` → fuso proposto, limites efetivos estimados e indicação de transição | Administrador |
| `POST /v1/family/time-zone-changes` | Confirmação | `timeZoneId`, `application` → configuração confirmada e limites efetivos | Administrador |

O servidor recalcula os limites no commit; uma prévia não reserva estado. Em aplicação imediata, preserva o início do ciclo aberto e fixa o próximo encerramento válido no novo fuso. Em `nextCycle`, preserva o ciclo atual e programa a mudança para seu encerramento.

### 5.3. Erros, concorrência e resultado incerto

| HTTP | Código | Situação |
|---:|---|---|
| 400 | `UNKNOWN_FIELD` | Campo não reconhecido, inclusive `familyId`, papel ou estado enviado pelo cliente |
| 401 | `CREATION_GRANT_INVALID` | Grant ausente, inválido, expirado ou não utilizável |
| 403 | `ACTION_NOT_ALLOWED` | Sessão válida sem papel Administrador para configurações de fuso |
| 404 | `RESOURCE_NOT_FOUND` | Recurso de outra família ou indisponível ao ator |
| 422 | `VALIDATION_FAILED` | Nome, fuso ou modo de aplicação semanticamente inválido; inclui `fieldErrors` |
| 503 | `DEPENDENCY_UNAVAILABLE` | Persistência incerta; não afirmar reversão da gravação |

- Todas as falhas usam `application/problem+json`, com `type`, `title`, `status`, `code`, `requestId` e `fieldErrors` quando aplicável.
- A criação e a mudança de fuso usam transação curta e lock da família/identidade aplicável (BA-08). Não existe `Idempotency-Key`, replay automático nem controle de versão otimista.
- Em resposta perdida de `POST /v1/families`, o mobile não repete a gravação automaticamente. Preserva o rascunho e direciona a pessoa a autenticar-se novamente com Apple; se a criação tiver persistido, a família vinculada é descoberta, e se não tiver, novo grant permite retomar o formulário.

## 6. Estados de domínio e transições

| Estado de | Evento | Estado para | Autor | Garantias |
|---|---|---|---|---|
| Identidade Apple sem família | Criar família com grant válido | Família ativa; Criador/Admin e sessão ativa | Identidade validada | Uma única associação; criação atômica |
| Fuso vigente | Aplicar `immediate` | Novo fuso vigente; ciclo aberto de transição | Administrador | Início preservado; novo fim é a próxima segunda-feira local válida |
| Fuso vigente | Aplicar `nextCycle` | Alteração programada | Administrador | Ciclo aberto preservado; última solicitação válida pode substituir programação anterior |
| Alteração programada | Encerramento do ciclo | Novo fuso vigente | Sistema | Ciclos contíguos, sem sobreposição; resultados já finalizados preservados |

## 7. Critérios de Aceitação

- **CA-01: criação com grant válido**
  - **DADO QUE** uma identidade Apple validada não possui família e recebeu `creationGrant` válido,
  - **QUANDO** enviar `POST /v1/families` com nome válido e fuso IANA válido ou omitido,
  - **ENTÃO O SISTEMA DEVE** criar a família, o Criador Administrador, o ciclo inicial e a sessão na mesma transação,
  - **E** responder `201 Created` com a projeção da família, do membro Criador e da sessão. *(UC01, RF01/RF38/RF39, RN01/RN44, BA-21)*

- **CA-02: fuso padrão e validação do nome**
  - **DADO QUE** o Criador preenche TEL-002,
  - **QUANDO** omitir `timeZoneId`,
  - **ENTÃO O SISTEMA DEVE** usar `America/Sao_Paulo`,
  - **E** rejeitar nome vazio, com mais de 60 caracteres visíveis ou contendo caracteres de controle com `422 VALIDATION_FAILED` e erro de campo correspondente. *(RF67; decisão E-01 desta spec)*

- **CA-03: associação única e resultado incerto**
  - **DADO QUE** duas tentativas concorrem para criar família da mesma identidade Apple ou uma resposta de criação se perde,
  - **QUANDO** uma criação for confirmada,
  - **ENTÃO O SISTEMA DEVE** manter uma única associação familiar para a identidade,
  - **E** uma nova autenticação Apple DEVE permitir descobrir a família existente, sem duplicar família. *(RN09, BA-08, BA-21, RNF12)*

- **CA-04: grant e entradas não autorizam atribuição indevida**
  - **DADO QUE** o cliente envia grant inválido/expirado ou inclui `familyId`, papel, flag de Criador ou estado no comando,
  - **QUANDO** a criação for processada,
  - **ENTÃO O SISTEMA DEVE** recusar grant inválido com `401 CREATION_GRANT_INVALID` e campos desconhecidos com `400 UNKNOWN_FIELD`,
  - **E** não DEVE persistir família parcial nem aceitar família ou papel fornecidos pelo cliente. *(RNF06, RNF07, BA-20)*

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
| E-03 | `POST /v1/families` retorna família, Criador e sessão no formato da seção 5.2. | Decidida em 2026-10-06 | Não |
| E-04 | Códigos de erro definidos na seção 5.3. | Decidida em 2026-10-06 | Não |
| E-05 | Resultado incerto preserva rascunho e pede nova autenticação Apple, sem retry automático. | Decidida em 2026-10-06 | Não |

## 10. Fases de implementação e conclusão

| Fase | Objetivo | CAs | Prontidão | Status |
|---|---|---|---|---|
| 1 | Criação vertical: grant, transação, sessão, validação, isolamento e TEL-002 | CA-01 a CA-04, CA-09 | Testes unitários, integração e UI verdes | a fazer |
| 2 | Configuração de fuso: leitura, prévia, confirmação, RBAC e TEL-053/MOD-012 | CA-05 a CA-08 | Testes de integração temporal e UX-spec verificada | a fazer |
| 3 | Auditoria, telemetria segura e regressão de transições | CA-03, CA-08, CA-09 | Regressão verde e QA | a fazer |

- **Fase 1:** não publica a alteração posterior de fuso; a família nasce com o fuso escolhido. Não deve ser publicada isoladamente sem a fase necessária de SPEC-001 que emite grant e sessão.
- **Fase 2:** não adiciona novas capacidades de membros, tarefas ou relatórios; apenas expõe a configuração permitida do fuso.
- **Fase 3:** não muda comportamento funcional; fortalece diagnóstico e cenários de transição.

## 11. Checklist de aprovação

- [x] Códigos funcionais, UX e arquiteturais pesquisados e existentes.
- [x] Dependência SPEC-001 aprovada e contrato de grant considerado.
- [x] RBAC e isolamento incluídos na Fase 1.
- [x] Contratos, códigos de erro e recuperação de resposta incerta definidos.
- [x] UX-spec vinculada.
- [x] Base funcional atualizada com o limite do nome familiar (E-01).
- [x] Status autorizado explicitamente como `aprovada` pela pessoa usuária.
