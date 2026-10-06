# Spec 010: Concluir tarefa

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06
**Base funcional:** 1.10
**UX-spec:** [UX-010-concluir-tarefa.md](UX-010-concluir-tarefa.md)
**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 2 — Tarefas e rotina

## 1. Contexto e objetivo

- **Problema / necessidade:** a família precisa concluir uma tarefa uma única vez, deixando inequívoco quem recebe o crédito e protegendo tarefas que envolvem perfis Kids.
- **Objetivo da entrega:** permitir conclusão adulta atômica com responsáveis finais e crédito correto, restringindo tarefa com responsável Kids ao Administrador.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos |
|---|---|
| Caso de uso | UC12 |
| Regras | RN21–23, RN26, RN30, RN35, RN48, RN55–56 |
| Requisitos | RF12, RF26, RF47, RF56 |
| Não funcionais | RNF01, RNF02, RNF05–14, RNF22, RNF25 |
| Telas e fluxo | TEL-012, MOD-004, UF-06 |
| Arquitetura | MA-07; BA-07, BA-08 |

- **Depende de:** [SPEC-007-gerenciar-tarefas.md](SPEC-007-gerenciar-tarefas.md), aprovada.
- **Fontes consultadas:** regras, requisitos, UC12, screen map, UF-06, contratos e arquiteturas mobile/backend.

## 3. Escopo

### Dentro

- Concluir `pending` ou `awaitingConfirmation` por `POST /v1/tasks/{taskId}/completion`.
- Escolher `keepAssignees` ou `takeOver`; sem responsável, `keepAssignees` atribui o autor adulto.
- Atualizar estado, créditos, progresso, missão e recursos afetados numa transação.
- Tarefa com ao menos um responsável Kids: somente Administrador conclui manualmente; Membro apenas visualiza.
- Conclusão manual administrativa encerra pendência Kids e preserva sinalização/foto para auditoria administrativa.
- Concorrência: uma conclusão válida; a segunda retorna `409 TASK_ALREADY_COMPLETED` e o mobile reconcilia silenciosamente.

### Fora

- Sinalizar, confirmar ou recusar Kids: SPEC-012 e SPEC-013.
- Reabrir tarefa: SPEC-011.
- Criar/editar/excluir tarefas, rotinas, carga e relatórios.

### Anti-requisitos

- Kids não concluem diretamente.
- Membro não conclui nem reabre tarefa que tenha responsável Kids.
- Não há conclusão parcial, divisão de peso, alteração de outras ocorrências de rotina ou reenvio automático de comando após resposta perdida.

## 4. Acesso e isolamento

| Perfil | Pode | Não pode |
|---|---|---|
| Administrador | Concluir qualquer tarefa elegível; concluir manualmente tarefa Kids | Duplicar conclusão ou burlar estado atual |
| Membro | Concluir tarefa elegível sem responsável Kids; visualizar tarefa Kids | Concluir ou reabrir tarefa com responsável Kids |
| Kids | Consultar/sinalizar em fluxos próprios | Concluir diretamente |

- Outra família: `404 RESOURCE_NOT_FOUND`, sem vazamento.
- O backend deriva ator/família da sessão e revalida papel, responsáveis e estado dentro da transação.

## 5. Contrato

**Rota:** `POST /v1/tasks/{taskId}/completion` — sessão adulta.

```json
{ "assignment": "keepAssignees" }
```

`assignment` aceita `keepAssignees` ou `takeOver`. O ator e `completedAt` não são aceitos do cliente. Sucesso é `200 OK` com tarefa canônica e `affectedResources`.

| HTTP | Código | Situação |
|---:|---|---|
| 403 | `ACTION_NOT_ALLOWED` | Kids ou Membro tentando concluir tarefa com responsável Kids |
| 404 | `RESOURCE_NOT_FOUND` | Tarefa indisponível/outra família |
| 409 | `TASK_ALREADY_COMPLETED` | Outra conclusão já foi confirmada |
| 422 | `VALIDATION_FAILED` | `assignment` inválido |
| 503 | `DEPENDENCY_UNAVAILABLE` | Resultado não confirmado |

Erros seguem `application/problem+json`. `409 TASK_ALREADY_COMPLETED` não é exibido como erro: o mobile consulta o estado atual e apresenta a tarefa concluída.

## 6. Estados

| De | Ação | Para | Regra |
|---|---|---|---|
| `pending` | Conclusão autorizada | `completed` | Define responsáveis finais e crédito uma vez |
| `awaitingConfirmation` | Conclusão manual por Admin | `completed` | Encerra pendência e preserva evidência Kids para auditoria Admin |
| `completed` | Nova conclusão | `completed` | Sem nova escrita; `409 TASK_ALREADY_COMPLETED` |

## 7. Critérios de aceitação

- **CA-01: manter responsáveis** — **DADO QUE** um adulto autorizado conclui tarefa sem responsável Kids, **QUANDO** enviar `keepAssignees`, **ENTÃO** a tarefa fica concluída para os responsáveis atuais, **E** crédito não é dado ao autor se não for responsável. *(UC12, RN21, RN56)*
- **CA-02: assumir tarefa** — **DADO QUE** adulto autorizado não é responsável, **QUANDO** confirmar `takeOver`, **ENTÃO** ele substitui todos os responsáveis e recebe o crédito integral. *(RN48, RF47)*
- **CA-03: sem responsável** — **DADO QUE** tarefa elegível não tem responsáveis, **QUANDO** adulto autorizado confirmar `keepAssignees`, **ENTÃO** o servidor atribui e conclui para esse adulto. *(UC12, RN48)*
- **CA-04: tarefa Kids só Admin** — **DADO QUE** tarefa tenha responsável Kids, **QUANDO** Membro tentar concluí-la, **ENTÃO** não há mudança, **E** a API responde `403 ACTION_NOT_ALLOWED`. *(RN21–23, RF12)*
- **CA-05: manual Kids preserva evidência** — **DADO QUE** Admin conclui tarefa Kids aguardando confirmação, **QUANDO** a transação confirmar, **ENTÃO** ela fica concluída e a pendência encerra, **E** sinalização/foto ficam auditáveis apenas por Admin. *(RN23, RF26)*
- **CA-06: concorrência reconciliada** — **DADO QUE** duas conclusões concorrem, **QUANDO** a segunda encontrar a primeira confirmada, **ENTÃO** responde `409 TASK_ALREADY_COMPLETED` sem duplicar crédito, **E** a interface mostra o estado concluído sem erro. *(RNF11, BA-07)*
- **CA-07: isolamento** — **DADO QUE** a tarefa pertença a outra família, **QUANDO** houver tentativa de conclusão, **ENTÃO** responde `404 RESOURCE_NOT_FOUND` sem dados. *(RNF06)*
- **CA-08: resposta incerta** — **DADO QUE** a resposta se perca, **QUANDO** o mobile não confirmar sucesso, **ENTÃO** não anuncia conclusão e consulta o estado antes de nova ação explícita. *(RNF12–13, MA-07)*

## 8. Observabilidade

| Evento | Dados permitidos |
|---|---|
| `task_completed` | `taskId`, `familyId`, `actorId`, `assignment`, `hasKidsAssignee` |
| `task_completion_reconciled` | `taskId`, `requestId`, `code` |
| `task_completion_denied` | `requestId`, `actorId`, `code` |

## 9. Decisões

| # | Decisão | Situação |
|---|---|---|
| E-01 | Conflito de conclusão usa `409 TASK_ALREADY_COMPLETED`; UI reconcilia silenciosamente. | Decidida pela pessoa usuária em 2026-10-06 |
| E-02 | Tarefa com pelo menos um responsável Kids só pode ser concluída manualmente por Administrador; Membro visualiza, mas não conclui/reabre. | Decidida pela pessoa usuária em 2026-10-06 |
| E-03 | Sinalização/foto Kids pendente é preservada para auditoria administrativa após conclusão manual. | Decidida pela pessoa usuária em 2026-10-06 |

## 10. Fases

| Fase | CAs | Prontidão | Status |
|---|---|---|---|
| 1 | CA-01 a CA-07 | API, transação, RBAC/isolation e testes verdes | a fazer |
| 2 | CA-01 a CA-06 | MOD-004 e TEL-012 integrados, UX e UI tests verdes | a fazer |
| 3 | CA-08 | Falhas/telemetria verificadas | a fazer |

## 11. Checklist

- [x] SPEC-007 aprovada.
- [x] Decisões E-01 a E-03 refletidas na base 1.10.
- [x] UX-spec vinculada.
- [x] Status `aprovada` autorizado pela pessoa usuária em 2026-10-06.
