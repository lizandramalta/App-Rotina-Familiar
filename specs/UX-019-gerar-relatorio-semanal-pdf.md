# UX Spec 019: Gerar relatório semanal em PDF

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Usuária | **Em:** 2026-10-10  
**Spec funcional vinculada:** [SPEC-019-gerar-relatorio-semanal-pdf.md](SPEC-019-gerar-relatorio-semanal-pdf.md)  
**Base funcional:** 1.17  
**Superfícies:** TEL-050, TEL-051, UF-14

## 1. Jornada

Adulto abre “Gerar relatório PDF” em TEL-050, escolhe uma semana e recebe preview do arquivo local. A data ativa na origem sugere a semana correspondente; voltar preserva o período da Família.

## 2. TEL-051

- Seletor semanal com rótulo segunda–domingo, fuso e período efetivo.
- Semana atual exibe “Parcial até {{generatedAt}}”; futura é indisponível.
- Preview mostra identificação da família, período/geração, gráfico de carga, gráfico de progresso e tabela de peso/tarefas por membro.
- “Membro removido” não exibe avatar, apelido ou navegação.
- Ações: “Gerar PDF”, “Salvar” e “Compartilhar”; compartilhamento usa a interface nativa.

## 3. Estados

| Estado | Comportamento |
|---|---|
| Seleção | Semana editável e dados anteriores preservados |
| Gerando | Progresso acessível; evita ação duplicada |
| Pronto | Preview, salvar ou compartilhar |
| Sem dados | Gera PDF íntegro com “Sem tarefas” |
| Falha | Preserva semana e oferece nova tentativa; nenhum arquivo parcial |
| Compartilhamento cancelado | Retorna ao preview sem afirmar envio |

## 4. Microcopy

| Chave | Texto pt-BR |
|---|---|
| `report.weekly.title` | Relatório semanal |
| `report.weekly.generate` | Gerar PDF |
| `report.weekly.partial` | Parcial até {{generatedAt}} |
| `report.weekly.empty` | Sem tarefas nesta semana. |
| `report.weekly.removed_member` | Membro removido |
| `report.weekly.error` | Não foi possível gerar o relatório. Tente novamente. |

## 5. Acessibilidade

- Gráficos têm resumo textual, tabela navegável e informação além de cor.
- VoiceOver anuncia período, parcialidade, progresso, carga e linhas da tabela.
- Dynamic Type, contraste e iPhone/iPad preservam leitura; alvos de toque têm ao menos 44×44 pt.

## 6. Critérios UX

| ID | Critério |
|---|---|
| UX-CA-01 | Semana, fuso e parcialidade são compreensíveis antes de gerar. |
| UX-CA-02 | Preview é equivalente em texto aos gráficos. |
| UX-CA-03 | Falha/cancelamento não afirmam arquivo ou envio concluído. |
| UX-CA-04 | Removido preserva métrica sem revelar identidade. |

## 7. Checklist

- [x] Jornada, estados, microcopy e acessibilidade definidos.
- [x] Revisão e aprovação explícita junto da SPEC funcional em 2026-10-10.
