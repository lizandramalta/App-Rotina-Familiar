# SPEC-017: Resgatar recompensa da missão

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Usuária | **Em:** 2026-10-10  
**Base funcional:** 1.15  
**UX-spec:** [UX-017-resgatar-recompensa.md](UX-017-resgatar-recompensa.md)  
**Projetos envolvidos:** ambos  
**Tema do backlog:** Tema 4 — Missões e recompensas

## 1. Contexto e objetivo

Depois de concluir uma missão, a família pode escolher uma recompensa coletiva. Esta entrega permite exclusivamente ao Administrador sortear localmente os itens elegíveis e confirmar uma única recompensa, mantendo a decisão canônica e segura sob concorrência.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos |
|---|---|
| Casos de uso | UC16 |
| Regras de negócio | RN36, RN38, RN42, RN43, RN52, RN53 |
| Requisitos funcionais | RF35, RF51, RF52, RF53 |
| Requisitos não funcionais | RNF01, RNF05–08, RNF12–14, RNF22, RNF23, RNF25 |
| Telas e fluxos | TEL-021, TEL-023, TEL-024, UF-11 |
| Decisões arquiteturais | MA-07, MA-11, MA-15; BA-05, BA-07, BA-08, BA-15, BA-20 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-feature-catalog.md`, `docs/architecture/mobile-decisions.md`, `docs/architecture/backend-contracts.md` e `docs/architecture/backend-decisions.md`.
- **Depende de:** SPEC-014 e SPEC-015, aprovadas; SPEC-016 fornece a projeção de disponibilidade e recompensa aceita no detalhe.
- **Dependências externas:** nenhuma; sorteio e animação são locais (BA-15).

## 3. Escopo

### 3.1 Dentro do escopo

- Abrir TEL-024 somente de missão concluída, sem aceite, por Administrador.
- Consultar o catálogo elegível e sortear/anima-lo localmente, sem persistir resultados recusados.
- Aceitar um resultado por `POST /v1/missions/{missionId}/reward-acceptance` e registrar snapshot do item na missão.
- Bloquear novo resgate para toda a família após o aceite e reconciliar ações concorrentes pela projeção canônica.
- Tratar saída, falha e resposta perdida sem declarar aceite antes da confirmação remota.

### 3.2 Fora do escopo

- Cadastro, edição, exclusão ou desativação de itens (SPEC-015).
- Criação, edição, conclusão ou reabertura da missão/tarefa (SPEC-014 e SPEC-011).
- Persistência, auditoria ou validação pelo servidor de sorteios recusados.
- Resgate ou visualização operacional da roleta por Membro ou Kids.

### 3.3 Anti-requisitos

- O backend NÃO comprova aleatoriedade, animação ou o resultado local; persiste somente o item aceito.
- Não há limite de novos sorteios antes do aceite.
- Não há `Idempotency-Key`, reenvio automático ou histórico de resultados recusados.
- Aceitar recompensa não altera tarefas, progresso ou participações da missão.

## 4. Perfis, autorização e isolamento

| Perfil | Pode | Não pode | Tentativa remota |
|---|---|---|---|
| Administrador | Abrir roleta e aceitar item elegível de missão resgatável da própria família | Aceitar novamente após resgate | Sucesso ou conflito canônico |
| Membro | Consultar recompensa aceita via SPEC-016 | Abrir, sortear ou aceitar | `403 INSUFFICIENT_PERMISSIONS` |
| Kids | Consultar recompensa aceita via SPEC-016 | Abrir, sortear ou aceitar | `403 INSUFFICIENT_PERMISSIONS` |

Missão fora da família da sessão DEVE retornar `404 RESOURCE_NOT_FOUND`, sem revelar existência ou metadados. `rewardItemId` de item inexistente ou não elegível retorna `422 REWARD_ITEM_NOT_ELIGIBLE`, sem identificar item de outra família.

## 5. Contrato de dados e API

### 5.1 Aceitar recompensa

- **Método e rota:** `POST /v1/missions/{missionId}/reward-acceptance`
- **Autenticação:** sessão ativa de Administrador.
- **Request:**

```json
{ "rewardItemId": "uuid" }
```

- **Resposta `200 OK`:** projeção canônica da missão, contendo `id`, `status: "completed"`, `isRedemptionAvailable: false` e `acceptedReward` com snapshot de `id`, `title`, `details` e `source` do item aceito.

| HTTP | Código | Situação |
|---:|---|---|
| 401 | `SESSION_EXPIRED` | Sessão ausente, inválida ou revogada |
| 403 | `INSUFFICIENT_PERMISSIONS` | Ator não é Administrador |
| 404 | `RESOURCE_NOT_FOUND` | Missão ausente ou fora da família |
| 409 | `MISSION_REWARD_REDEMPTION_UNAVAILABLE` | Missão não está concluída ou não está disponível para resgate |
| 409 | `MISSION_REWARD_ALREADY_ACCEPTED` | Já há aceite, inclusive por ação concorrente |
| 422 | `REWARD_ITEM_NOT_ELIGIBLE` | Item inválido ou fora do catálogo elegível |

Campos desconhecidos, `familyId`, resultado do sorteio e campos controlados pela recompensa DEVEM ser rejeitados. O servidor revalida todas as pré-condições e grava o aceite em transação curta serializada por família.

### 5.2 Falhas e concorrência

Se a resposta do aceite se perder, o app NÃO DEVE afirmar sucesso nem reenviar automaticamente. Ele consulta `GET /v1/missions/{missionId}`; o registro canônico determina se exibe a recompensa aceita ou permite nova tentativa. Em concorrência, somente um aceite é persistido; o outro recebe `409 MISSION_REWARD_ALREADY_ACCEPTED` e atualiza o detalhe.

## 6. Estados de domínio

| Estado da missão | Evento | Resultado de resgate |
|---|---|---|
| `inProgress` | Tentar abrir/aceitar | Indisponível; `409 MISSION_REWARD_REDEMPTION_UNAVAILABLE` |
| `completed` sem aceite | Administrador aceita item elegível | `completed` com `acceptedReward`; resgate encerrado |
| `completed` com aceite | Nova tentativa | Sem mutação; `409 MISSION_REWARD_ALREADY_ACCEPTED` |
| `completed` com aceite | Reabertura confirmada de tarefa vinculada | Missão volta a andamento e remove aceite conforme SPEC-011 |

## 7. Critérios de aceitação

| ID | Fase | Critério verificável |
|---|---:|---|
| CA-01 | 1 | Administrador aceita item elegível de missão concluída sem aceite e recebe `200` com snapshot canônico; o resgate é encerrado para a família. |
| CA-02 | 1 | Membro e Kids não veem controles de resgate e recebem `403 INSUFFICIENT_PERMISSIONS` se chamarem a rota. |
| CA-03 | 1 | Missão de outra família retorna `404 RESOURCE_NOT_FOUND` sem vazamento; item não elegível retorna `422 REWARD_ITEM_NOT_ELIGIBLE`. |
| CA-04 | 1 | Missão em andamento ou indisponível para resgate retorna `409 MISSION_REWARD_REDEMPTION_UNAVAILABLE`, sem gravar recompensa. |
| CA-05 | 1 | Dois Administradores aceitando simultaneamente resultam em um único snapshot; a outra ação recebe `409 MISSION_REWARD_ALREADY_ACCEPTED`. |
| CA-06 | 2 | Sorteios repetidos, recusa e saída de TEL-024 não persistem resultado nem consomem o resgate. |
| CA-07 | 2 | Resposta perdida não confirma aceite; a consulta do detalhe reconcilia o estado antes de nova tentativa. |
| CA-08 | 2 | Ao confirmar aceite, TEL-021 mostra a recompensa aceita; Membro e Kids continuam sem ação de resgate. |

## 8. Observabilidade e segurança

Registrar resultado do comando, `missionId`, família pseudonimizada, papel e código estável de erro. Nunca registrar token, `rewardItemId` inelegível, resultado recusado da roleta ou dados de outra família.

## 9. Premissas e decisões

| # | Decisão | Decidido por / data | Altera docs? |
|---|---|---|---|
| E-01 | Aceite retorna `200` com missão canônica; conflitos usam os dois códigos `409` definidos e item inelegível usa `422 REWARD_ITEM_NOT_ELIGIBLE`. | Usuária / 2026-10-10 | Sim — consolidado em `docs/architecture/backend-contracts.md` 1.11. |

## 10. Fases de implementação

| Fase | Objetivo | CAs | Prontidão | Status |
|---|---|---|---|---|
| 1 | Aceite backend com RBAC, isolamento, validação, transação e concorrência | CA-01 a CA-05 | Testes unitários e de integração verdes | a fazer |
| 2 | TEL-024, roleta local, integração e recuperação de falha | CA-06 a CA-08 | Testes de ViewModel/UI e UX-spec verificada | a fazer |

Fase 1 não é publicável isoladamente; a ação exige a experiência de TEL-024 da Fase 2.

## 11. Checklist de aprovação

- [x] Códigos rastreáveis conferidos na base funcional 1.15.
- [x] Contrato, autorização, isolamento, concorrência e resultado incerto definidos na Fase 1.
- [x] UX-spec vinculada em rascunho.
- [x] Aprovação explícita da SPEC e da UX-spec em 2026-10-10.
