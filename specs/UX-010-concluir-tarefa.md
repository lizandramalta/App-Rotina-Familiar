# UX Spec 010: Concluir tarefa

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06
**Spec funcional vinculada:** [SPEC-010-concluir-tarefa.md](SPEC-010-concluir-tarefa.md)
**Base funcional:** UC 1.18; RN/RF conforme SPEC-010
**Revisão de interface:** 2026-10-26 — atualização imediata em TEL-010
**Superfícies:** TEL-010, TEL-012, UF-06

## 1. Jornada

Adultos concluem uma tarefa diretamente, sem alerta. Para tarefa com responsável Kids, somente Administrador vê a ação; Membro permanece em consulta.

| Origem | Ação | Destino | Retorno |
|---|---|---|---|
| TEL-012 | Admin/Membro autorizado toca Concluir | TEL-012 concluída | Atualiza estado e origem |
| TEL-010 | Admin/Membro autorizado toca o círculo | TEL-010, mesma data | Atualiza a linha e o progresso; tocar no restante da linha abre TEL-012 |
| TEL-012 Kids | Membro abre detalhe | TEL-012 consulta | Não exibe Concluir; Reabrir segue UX-011 |

## 2. Superfícies e estados

- **Tarefa Kids:** somente Admin vê Concluir; a foto de sinalização não aparece nesse fluxo e continua no fluxo administrativo de validação.
- **TEL-012 enviando:** desabilita Concluir e impede toque duplicado no detalhe.
- **TEL-010 enviando:** o círculo segue acionável; novo toque atualiza a intenção imediatamente. O app serializa os comandos da tarefa e consulta o estado canônico antes de repetir uma operação de resultado incerto.
- **TEL-010 falha:** recusa confirmada restaura linha e progresso e abre alerta; resultado indeterminado bloqueia novo envio até consulta do estado.
- **Conflito já concluída:** fecha modal, atualiza detalhe para Concluída, sem alerta de erro.
- **Falha não reconciliada:** mantém modal e mostra ação de consultar estado/tentar novamente.

## 3. Microcopy e acessibilidade

| Chave | Texto-base |
|---|---|
| `task.complete.pending` | `Concluindo tarefa…` |

- VoiceOver anuncia “Concluir tarefa” e, após sucesso, o estado “Concluída”.
- Ação indisponível a Membro em tarefa Kids não recebe foco nem é mostrada.
- Após sucesso ou reconciliação, foco vai ao estado “Concluída”.

## 4. Critérios UX

- Concluir não abre modal nem salva mudança de responsáveis quando já houver responsáveis.
- Membro não vê Concluir em tarefa com responsável Kids; Reabrir segue UC17/UX-011.
- `TASK_ALREADY_COMPLETED` atualiza para Concluída sem mensagem de erro.
- A foto Kids não é exposta no fluxo de conclusão de Membro.

## 5. Checklist

- [x] Jornada, estados, microcopy e acessibilidade definidos.
- [x] Restrição Kids e reconciliação refletidas.
- [x] Status `aprovada` autorizado pela pessoa usuária em 2026-10-06.
- [x] Decisão posterior em 2026-10-07: remover MOD-004 do fluxo e concluir diretamente.
