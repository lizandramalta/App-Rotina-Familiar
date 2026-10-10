# UX Spec 018: Visualizar carga diária ou semanal

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Usuária | **Em:** 2026-10-10  
**Spec funcional vinculada:** [SPEC-018-visualizar-carga.md](SPEC-018-visualizar-carga.md)  
**Base funcional:** 1.16  
**Superfícies:** TEL-050, UF-09

## 1. Objetivo

Administradores e Membros entendem a distribuição da participação creditada no período selecionado sem competição ou julgamento de desempenho.

## 2. Escopo e jornada

Na TEL-050, a pessoa escolhe Dia/Semana e data de referência; a carga atualiza mantendo o contexto. Em semana, o período mostra segunda–domingo ou o intervalo efetivo de transição. Gerar PDF continua seguindo a semana correspondente, fora desta entrega.

## 3. TEL-050 — Carga integrada

- Cartão “Distribuição da carga” com período, carga total e explicação de participação creditada.
- Gráfico segmentado neutro e lista textual por pessoa: nome, peso e percentual. A lista usa ordem neutra estável, não ordem de maior carga.
- “Membro removido” identifica somente crédito histórico, sem avatar, apelido ou atalho de perfil.
- Sem carga: “Não há conclusões válidas neste período.” Sem percentual ou visualização enganosa.
- Kids não veem a tela, caminho ou informação de carga.

## 4. Estados

| Estado | Comportamento |
|---|---|
| Carregando | Skeleton de resumo e linhas; não exibe números provisórios |
| Conteúdo | Total, segmentos e lista textual coerentes |
| Sem carga | Orientação sem divisão por zero |
| Atualizando | Mantém snapshot confirmado e indica atualização discreta |
| Falha | Mantém conteúdo confirmado ou mostra tentativa de recarregar |
| Transição | Explicita fuso e intervalo efetivo |

## 5. Microcopy

| Chave | Texto pt-BR |
|---|---|
| `family.load.title` | Distribuição da carga |
| `family.load.total` | Carga total: {{load}} |
| `family.load.share` | {{name}}: {{load}} ({{percent}}%) |
| `family.load.removed_member` | Membro removido |
| `family.load.empty` | Não há conclusões válidas neste período. |
| `family.load.transition` | Período de transição de fuso: {{start}} a {{end}}. |
| `family.load.error` | Não foi possível atualizar a carga. Tente novamente. |

## 6. Acessibilidade e adaptação

- Cada segmento tem equivalente textual; VoiceOver anuncia nome, peso, percentual e período.
- Dynamic Type não trunca nomes ou métricas; alvos de toque mínimos de 44×44 pt.
- iPhone usa coluna única; iPad mantém gráfico e lista sem omitir dados.
- A carga não usa vermelho/verde, posição ou medalhas para sugerir mérito.

## 7. Critérios UX

| ID | Critério |
|---|---|
| UX-CA-01 | Distribuição apresenta peso e percentual sem ranking. |
| UX-CA-02 | Estado vazio, falha e transição têm explicação acessível. |
| UX-CA-03 | Linha histórica removida preserva privacidade e total. |
| UX-CA-04 | Seleção de período preserva contexto e não concede acesso a Kids. |

## 8. Checklist

- [x] Navegação, estados, microcopy e acessibilidade definidos.
- [x] Revisão e aprovação explícita junto da SPEC funcional em 2026-10-10.
