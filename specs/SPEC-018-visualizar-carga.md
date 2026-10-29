# SPEC-018: Visualizar carga diária ou semanal

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Usuária | **Em:** 2026-10-10  
**Base funcional:** 1.16  
**UX-spec:** [UX-018-visualizar-carga.md](UX-018-visualizar-carga.md)  
**Projetos envolvidos:** ambos  
**Tema do backlog:** Tema 5 — Acompanhamento e reconhecimento

## 1. Contexto e objetivo

Adultos precisam perceber como a participação creditada se distribui na família, sem criar competição. Esta entrega fornece carga diária ou semanal a partir de um snapshot seguro e canônico. Sua apresentação na TEL-050 atual foi adiada; o snapshot também sustenta o relatório semanal da SPEC-019.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos |
|---|---|
| Casos de uso | UC13 |
| Regras | RN26, RN28, RN30, RN31, RN33, RN34, RN55–58, RN60–61 |
| Requisitos | RF18–21, RF56–57, RF66 |
| Não funcionais | RNF01, RNF03, RNF05–10, RNF12–14, RNF22, RNF25 |
| Telas e fluxo | TEL-050, UF-09 |
| Arquitetura | MA-07, MA-11, MA-15; BA-05, BA-07, BA-08, BA-13, BA-20 |

- **Depende de:** SPEC-010 e SPEC-013, aprovadas; SPEC-011 já assegura a reversão de crédito.
- **Fontes consultadas:** regras, requisitos, UC13, design, contratos e arquiteturas mobile/backend rastreáveis acima.

## 3. Escopo

### 3.1 Dentro

- `GET /v1/family/load` por Dia/Semana e data de referência.
- Carga individual, total e participação percentual, conforme conclusões válidas.
- Intervalo efetivo, fuso e transição; linha histórica “Membro removido” quando houver crédito válido.
- Apresentação acessível, neutra e sem ranking em entrega visual posterior à aba Família aprovada em 2026-10-27.

### 3.2 Fora

- Carga para Kids, edição de tarefas, progresso familiar, PDF (SPEC-019) e destaque semanal (SPEC-020).

### 3.3 Anti-requisitos

- Não há ranking, medalha, comparação competitiva, limiar de sobrecarga ou pontuação adicional.
- App não calcula carga; backend é autoritativo. Não aceita `familyId` nem dados de crédito do cliente.

## 4. Perfis e isolamento

| Perfil | Pode | Não pode |
|---|---|---|
| Administrador | Consultar carga da própria família | Consultar família externa |
| Membro | Consultar carga da própria família | Consultar família externa |
| Kids | — | Consultar carga ou entrar em Família |

Kids recebem `403 INSUFFICIENT_PERMISSIONS`; a família é sempre obtida da sessão. Não há ID de família exposto na rota.

## 5. Contrato

**`GET /v1/family/load?period=day|week&referenceDate=YYYY-MM-DD`** retorna `200 OK` com `period`, `referenceDate`, `effectivePeriod`, `totalLoad` e linhas por membro (`memberId`/`null`, `displayName`, `load`, `participationPercent`). `memberId: null` e nome “Membro removido” preservam crédito histórico sem expor perfil removido.

Erros: `401 SESSION_EXPIRED`, `403 INSUFFICIENT_PERMISSIONS`, `422 VALIDATION_FAILED` para período/data inválidos ou fora do intervalo e `503 DEPENDENCY_UNAVAILABLE`. O cliente preserva o último snapshot confirmado diante de falha e permite nova consulta.

## 6. Cálculo e estados

| Situação | Resultado |
|---|---|
| Tarefa concluída peso 3 por dois responsáveis | 3 para cada responsável; total familiar 6 |
| `pending` ou `awaitingConfirmation` | Não entra na carga |
| Reabertura autorizada | Remove uma vez o crédito do dia e semana da conclusão original |
| Sem conclusões válidas | `totalLoad: 0`, percentuais nulos, sem divisão por zero |
| Crédito de removido | Mantido na linha “Membro removido” |

## 7. Critérios de aceitação

| ID | Fase | Critério |
|---|---:|---|
| CA-01 | 1 | Adulto consulta carga da própria família por Dia/Semana com intervalo efetivo canônico. |
| CA-02 | 1 | Carga soma peso integral por responsável e totaliza as cargas individuais. |
| CA-03 | 1 | Pendentes/aguardando confirmação são excluídas; reabertura retira crédito uma única vez. |
| CA-04 | 1 | Crédito histórico de removido aparece como “Membro removido”, sem dado pessoal. |
| CA-05 | 1 | Kids recebe `403`; parâmetros inválidos recebem `422`; não há vazamento entre famílias. |
| CA-06 | 1 | Sem carga retorna total zero e percentuais nulos. |
| CA-07 | 2 | TEL-050 apresenta carga e participação sem ranking, com texto além de cores. |
| CA-08 | 2 | Falha preserva conteúdo confirmado; transição de fuso informa intervalo efetivo. |

## 8. Observabilidade

Métricas agregadas registram período, papel, presença de carga e transição, sem nomes, tokens, IDs de terceiros ou detalhes de perfil removido.

## 9. Decisões

| # | Decisão | Decidido por / data | Docs |
|---|---|---|---|
| E-01 | Crédito histórico de removido permanece como “Membro removido”. | Usuária / 2026-10-10 | RN30, RN31, RN61, RF18, RF20 e UC13 atualizados. |
| E-02 | `GET /family/load` expõe snapshot e erros estáveis descritos nesta SPEC. | Usuária / 2026-10-10 | Contratos backend 1.12 atualizado. |

## 10. Fases

| Fase | Objetivo | CAs | Status |
|---|---|---|---|
| 1 | Snapshot backend, autorização, isolamento e cálculo consistente | CA-01 a CA-06 | a fazer |
| 2 | Integração acessível em uma superfície visual futura, fora da TEL-050 atual | CA-07 a CA-08 | a fazer — apresentação adiada pela pessoa usuária em 2026-10-27 |

Fase 1 não é publicável isoladamente; depende da apresentação na Fase 2.

## 11. Checklist

- [x] Dependências aprovadas e rastreabilidade verificada.
- [x] Autorização, isolamento, validação e falhas na Fase 1.
- [x] Decisões documentais consolidadas.
- [x] Aprovação explícita da SPEC e UX-spec em 2026-10-10.
