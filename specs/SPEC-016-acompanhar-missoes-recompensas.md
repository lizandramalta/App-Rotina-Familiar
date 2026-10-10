# Spec 016: Acompanhar missões e recompensas

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-10  
**Base funcional:** 1.15  
**UX-spec:** [UX-016-acompanhar-missoes-recompensas.md](UX-016-acompanhar-missoes-recompensas.md)  
**Projetos envolvidos:** ambos  
**Tema do backlog:** Tema 4 - Missões e recompensas

## 1. Contexto e objetivo

- **Problema / necessidade:** depois de criar uma missão, a família precisa entender seu progresso coletivo, as tarefas que faltam, as participações geradas no encerramento e a situação da recompensa, sem prazo artificial ou competição individual.
- **Objetivo da entrega:** disponibilizar listas e detalhes canônicos de missões para todos os perfis da família, com progresso, estado, participações autorizadas e recompensa aceita; a ação de resgate continua fora desta entrega.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Casos de uso | UC14 |
| Regras de negócio | RN26, RN33, RN35, RN36, RN38, RN39, RN43, RN51, RN52, RN53, RN55, RN58, RN63, RN64 |
| Requisitos funcionais | RF30, RF31, RF36, RF58, RF62, RF65 |
| Requisitos não funcionais | RNF01, RNF04, RNF05, RNF06, RNF07, RNF08, RNF09, RNF11, RNF12, RNF13, RNF14, RNF22, RNF23, RNF25 |
| Telas e fluxos | TEL-020, TEL-021, UF-10 |
| Decisões arquiteturais | MA-07, MA-11, MA-15; BA-05, BA-08, BA-20 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/backend-contracts.md`, `docs/architecture/backend-decisions.md`, `docs/architecture/mobile-decisions.md` e `docs/architecture/mobile-feature-catalog.md`.
- **Depende de:** [SPEC-014-gerenciar-missoes.md](SPEC-014-gerenciar-missoes.md), aprovada — fornece a missão, o encerramento e os dados derivados consultados.
- **Dependências externas e infraestrutura:** nenhuma além da sessão e do banco transacional já adotados.

## 3. Escopo da entrega

### 3.1. Dentro do escopo

- Ampliar `GET /v1/missions` e `GET /v1/missions/{missionId}` para projetar progresso canônico, tarefas vinculadas, estado, situação de resgate, recompensa aceita e participações conforme o perfil.
- Exibir listas de missões em andamento e concluídas em TEL-020 e o detalhe completo autorizado em TEL-021.
- Permitir a todos os perfis consultar a recompensa aceita; participações são ocultadas para Kids.
- Refletir, por nova consulta, a conclusão e a reabertura confirmada que removem dados derivados.
- Manter isolamento familiar, sessão válida, projeções por perfil e consistência transacional já exigidos pelas dependências.

### 3.2. Fora do escopo

- Criar, editar, vincular ou desvincular missões (SPEC-014).
- Cadastrar itens de recompensa (SPEC-015).
- Sortear ou aceitar recompensa e expor a ação de resgate (SPEC-017).
- Consultar badges por marco no perfil (SPEC-006).
- Alterar/reabrir tarefa ou missão (SPEC-011).

### 3.3. Fora de questão

- Missões não têm prazo, expiração ou penalidade por demora.
- Progresso não conta tarefa `awaitingConfirmation` e não duplica tarefa com vários responsáveis.
- A leitura não concede ação de resgate nem gestão a Membro ou Kids.
- Não há gravação offline, `Idempotency-Key` ou controle de versão otimista nesta consulta.

## 4. Perfis, autorização e isolamento

| Perfil | Pode | Não pode |
|---|---|---|
| Administrador | Consultar todas as projeções da própria família, incluindo participações, situação de resgate e recompensa aceita | Editar missão concluída ou aceitar recompensa nesta entrega |
| Membro | Consultar todas as projeções da própria família, incluindo participações, situação de resgate e recompensa aceita | Gerir missão ou resgatar recompensa |
| Kids | Consultar lista/detalhe simplificados, progresso, tarefas, status e recompensa aceita | Ver participações, gerir missão ou resgatar recompensa |

Toda rota DEVE conferir a sessão e o perfil no servidor. Recurso de outra família DEVE responder `404 RESOURCE_NOT_FOUND`, sem revelar existência ou metadados (RNF06).

## 5. Contrato de dados e interface

### 5.1. Consultas

| Rota | Resposta canônica | Acesso |
|---|---|---|
| `GET /v1/missions` | Coleções `inProgress` e `completed`, cada missão com `id`, `title`, `status`, `taskCount`, `completedTaskCount`, `progressPercent`, `isRedemptionAvailable` e resumo de recompensa aceita quando houver | Todos da família; Kids em projeção simplificada |
| `GET /v1/missions/{missionId}` | Dados da lista, `note`, tarefas vinculadas e seus estados, `completedAt`, situação de resgate, recompensa aceita e participações | Admin/Membro: projeção completa; Kids: sem `participations` |

`progressPercent` é calculado no servidor como tarefas vinculadas concluídas dividido pelo total de tarefas vinculadas, multiplicado por 100. A recompensa aceita contém apenas a identificação e o título registrado no aceite; nunca expõe informações de outra família.

### 5.2. Falhas, concorrência e rede

| HTTP | Código | Situação |
|---:|---|---|
| 401 | `SESSION_EXPIRED` | Sessão ausente, inválida ou revogada |
| 404 | `RESOURCE_NOT_FOUND` | Missão inexistente ou de outra família |
| 503 | `DEPENDENCY_UNAVAILABLE` | Consulta não confirmada por indisponibilidade transitória |

- Consultas observam um estado transacional: não podem retornar missão reaberta com participações ou recompensa do encerramento anterior.
- Após timeout ou retorno perdido, o app preserva o conteúdo confirmado, informa indisponibilidade e permite nova consulta; não inventa o resultado remoto.
- Atualização por pull-to-refresh, retorno à tela ou notificação local recarrega a projeção remota.

## 6. Estados de domínio projetados

| Estado | Progresso | Resgate/recompensa | Participações |
|---|---|---|---|
| `inProgress` | Menor que 100%; pendentes e aguardando confirmação não concluídos | Indisponível; sem recompensa aceita | Não há participações desta missão |
| `completed` sem aceite | 100% | Resgate disponível; sem recompensa aceita | Presentes para Admin/Membro |
| `completed` com aceite | 100% | Resgate encerrado; recompensa aceita exibida | Presentes para Admin/Membro |
| Reaberta confirmadamente | Recalculado abaixo de 100% | Indisponível; recompensa removida | Removidas na mesma transação |

## 7. Critérios de aceitação

- **CA-01: listar missões da própria família**
  - **DADO QUE** a sessão ativa pertence a uma família com missões em andamento e concluídas,
  - **QUANDO** consultar `GET /v1/missions`,
  - **ENTÃO O SISTEMA DEVE** retornar somente missões daquela família, com contagens e percentual canônicos,
  - **E** cada tarefa vinculada DEVE contribuir no máximo uma vez. *(UC14, RN35, RF30)*

- **CA-02: tarefa aguardando confirmação**
  - **DADO QUE** uma tarefa vinculada está `awaitingConfirmation`,
  - **QUANDO** o progresso da missão for consultado,
  - **ENTÃO O SISTEMA DEVE** não contá-la como concluída,
  - **E** manter a missão em andamento enquanto ela impedir 100%. *(RN26, RF30/31)*

- **CA-03: detalhe por perfil**
  - **DADO QUE** Administrador, Membro e Kids consultam a mesma missão concluída com recompensa aceita,
  - **QUANDO** receberem o detalhe,
  - **ENTÃO O SISTEMA DEVE** apresentar a recompensa aceita aos três perfis,
  - **E** omitir participações da projeção Kids e a ação de resgate dos perfis não administrativos. *(RF36, RNF07)*

- **CA-04: isolamento familiar**
  - **DADO QUE** uma missão pertence a outra família,
  - **QUANDO** um perfil autenticado tentar consultá-la,
  - **ENTÃO O SISTEMA DEVE** responder `404 RESOURCE_NOT_FOUND`,
  - **E** não revelar seus dados ou sua existência. *(RNF06)*

- **CA-05: missão sem resgate ou sem recompensa**
  - **DADO QUE** uma missão está em andamento ou concluída sem aceite,
  - **QUANDO** o detalhe for exibido,
  - **ENTÃO O SISTEMA DEVE** comunicar a situação verdadeira do resgate,
  - **E** não apresentar uma recompensa como aceita antes do registro canônico. *(RN36, RN38, RN43, RF36)*

- **CA-06: reabertura consistente**
  - **DADO QUE** uma missão concluída com participações e recompensa aceita é reaberta validamente,
  - **QUANDO** a consulta for feita após a transação,
  - **ENTÃO O SISTEMA DEVE** retornar missão em andamento com progresso recalculado,
  - **E** não retornar recompensa, participações ou badges derivados daquele encerramento. *(RN38, RN58, RF58, RNF25)*

- **CA-07: falha de consulta recuperável**
  - **DADO QUE** a carga ou atualização da missão falha por rede ou indisponibilidade,
  - **QUANDO** o app identificar que não recebeu uma resposta confirmada,
  - **ENTÃO O APLICATIVO DEVE** preservar o último conteúdo confirmado e informar uma falha recuperável,
  - **E** permitir nova consulta sem afirmar mudança de estado. *(RNF12, RNF13)*

## 8. Observabilidade, métricas e auditoria

| Evento | Gatilho | Propriedades permitidas |
|---|---|---|
| `missions_list_viewed` | Lista carregada com sucesso | `familyId`, `role`, `inProgressCount`, `completedCount` |
| `mission_detail_viewed` | Detalhe carregado com sucesso | `missionId`, `familyId`, `role`, `status`, `hasAcceptedReward` |
| `mission_query_failed` | Falha recuperável | `route`, `status`, `requestId` |

Logs e métricas nunca registram tokens, senhas ou dados excluídos da projeção Kids.

## 9. Premissas e esclarecimentos

| # | Decisão | Decidido por / data | Altera docs? |
|---|---|---|---|
| E-01 | RF36 prevalece: Kids consultam recompensa aceita, mas não participações nem resgate. | Pessoa usuária / 2026-10-10 | Sim — `screen-map.md`, `user-flows.md` e SPEC-014 atualizados nesta entrega de especificação. |

## 10. Fases de implementação

| Fase | Objetivo | CAs | Prontidão | Status |
|---|---|---|---|---|
| 1 | Projeções backend, autorização, isolamento e consistência de leitura | CA-01 a CA-06 | Testes unitários e de integração cobrindo perfis, famílias e reabertura | a fazer |
| 2 | TEL-020/TEL-021 e recuperação de falhas no mobile | CA-07 e verificação visual dos CA-01 a CA-06 | Testes de ViewModel/UI e UX-spec revisada | a fazer |

Fase 1 não é publicável isoladamente: altera contrato de leitura ainda sem a experiência completa. Fase 2 é publicável com a Fase 1.

## 11. Checklist de aprovação

- [x] Códigos rastreáveis conferidos na base funcional 1.15.
- [x] Autorização, isolamento, validação de sessão e falhas incluídos na Fase 1.
- [x] Decisão sobre recompensa na projeção Kids consolidada nos documentos de design afetados.
- [x] Contrato e UX-spec revisados e aprovados explicitamente em 2026-10-10.
