# UX Spec 010: Concluir tarefa

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06
**Spec funcional vinculada:** [SPEC-010-concluir-tarefa.md](SPEC-010-concluir-tarefa.md)
**Base funcional:** 1.10
**Superfícies:** TEL-012, UF-06

## 1. Jornada

Adultos concluem uma tarefa diretamente, sem alerta. Para tarefa com responsável Kids, somente Administrador vê a ação; Membro permanece em consulta.

| Origem | Ação | Destino | Retorno |
|---|---|---|---|
| TEL-012 | Admin/Membro autorizado toca Concluir | TEL-012 concluída | Atualiza estado e origem |
| TEL-012 Kids | Membro abre detalhe | TEL-012 consulta | Não exibe Concluir/Reabrir |

## 2. Superfícies e estados

- **Tarefa Kids:** somente Admin vê Concluir; a foto de sinalização não aparece nesse fluxo e continua no fluxo administrativo de validação.
- **Enviando:** desabilita Concluir e impede toque duplicado.
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
- Membro não vê Concluir/Reabrir em tarefa com responsável Kids.
- `TASK_ALREADY_COMPLETED` atualiza para Concluída sem mensagem de erro.
- A foto Kids não é exposta no fluxo de conclusão de Membro.

## 5. Checklist

- [x] Jornada, estados, microcopy e acessibilidade definidos.
- [x] Restrição Kids e reconciliação refletidas.
- [x] Status `aprovada` autorizado pela pessoa usuária em 2026-10-06.
- [x] Decisão posterior em 2026-10-07: remover MOD-004 do fluxo e concluir diretamente.
