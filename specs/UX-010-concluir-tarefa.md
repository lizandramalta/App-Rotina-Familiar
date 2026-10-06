# UX Spec 010: Concluir tarefa

**Status:** aprovada
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06
**Spec funcional vinculada:** [SPEC-010-concluir-tarefa.md](SPEC-010-concluir-tarefa.md)
**Base funcional:** 1.10
**Superfícies:** TEL-012, MOD-004, UF-06

## 1. Jornada

Adultos concluem uma tarefa com clareza sobre crédito. Para tarefa com responsável Kids, somente Administrador vê a ação; Membro permanece em consulta.

| Origem | Ação | Destino | Retorno |
|---|---|---|---|
| TEL-012 | Admin/Membro autorizado toca Concluir | MOD-004 | Cancelar mantém tarefa |
| MOD-004 | Confirma manter/assumir | TEL-012 concluída | Atualiza estado e origem |
| TEL-012 Kids | Membro abre detalhe | TEL-012 consulta | Não exibe Concluir/Reabrir |

## 2. Superfícies e estados

- **MOD-004:** mostra responsáveis, efeito de crédito e opções aplicáveis. Sem responsável, informa atribuição automática ao autor.
- **Tarefa Kids:** Admin pode abrir MOD-004; a foto de sinalização não aparece ali e continua no fluxo administrativo de validação.
- **Enviando:** desabilita confirmação e impede toque duplicado.
- **Conflito já concluída:** fecha modal, atualiza detalhe para Concluída, sem alerta de erro.
- **Falha não reconciliada:** mantém modal e mostra ação de consultar estado/tentar novamente.

## 3. Microcopy e acessibilidade

| Chave | Texto-base |
|---|---|
| `task.complete.keepAssignees` | `Manter responsáveis` |
| `task.complete.takeOver` | `Assumir tarefa` |
| `task.complete.creditNotice` | `O crédito será atribuído aos responsáveis finais.` |
| `task.complete.unassignedNotice` | `Você será definido como responsável ao concluir.` |
| `task.complete.pending` | `Concluindo tarefa…` |

- VoiceOver anuncia responsáveis finais e efeito da opção selecionada antes da confirmação.
- Ação indisponível a Membro em tarefa Kids não recebe foco nem é mostrada.
- Após sucesso ou reconciliação, foco vai ao estado “Concluída”.

## 4. Critérios UX

- MOD-004 não salva mudanças antes de confirmar.
- Membro não vê Concluir/Reabrir em tarefa com responsável Kids.
- `TASK_ALREADY_COMPLETED` atualiza para Concluída sem mensagem de erro.
- A foto Kids não é exposta no fluxo de conclusão de Membro.

## 5. Checklist

- [x] Jornada, estados, microcopy e acessibilidade definidos.
- [x] Restrição Kids e reconciliação refletidas.
- [x] Status `aprovada` autorizado pela pessoa usuária em 2026-10-06.
