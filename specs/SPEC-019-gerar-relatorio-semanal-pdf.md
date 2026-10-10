# SPEC-019: Gerar relatório semanal em PDF

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Usuária | **Em:** 2026-10-10  
**Base funcional:** 1.17  
**UX-spec:** [UX-019-gerar-relatorio-semanal-pdf.md](UX-019-gerar-relatorio-semanal-pdf.md)  
**Projetos envolvidos:** ambos  
**Tema do backlog:** Tema 5 — Acompanhamento e reconhecimento

## 1. Contexto e objetivo

Adultos geram uma visão semanal compartilhável da participação familiar. O backend fornece dados consistentes; o aplicativo compõe, visualiza, salva ou compartilha o PDF localmente.

## 2. Rastreabilidade e dependências

| Categoria | Códigos |
|---|---|
| Caso de uso | UC18 |
| Regras | RN28, RN30–31, RN60–62 |
| Requisito | RF61 |
| Não funcionais | RNF05–08, RNF10, RNF12–13, RNF22, RNF26–27 |
| Telas/fluxo | TEL-050, TEL-051, UF-14 |
| Arquitetura | MA-07, MA-09, MA-11, MA-12, MA-15; BA-05, BA-07–08, BA-13, BA-15, BA-20 |

- **Depende de:** SPEC-018 aprovada.
- **Dependências externas:** renderização, armazenamento e compartilhamento nativos do dispositivo; não há serviço de PDF remoto.

## 3. Escopo

- `GET /v1/reports/weekly-snapshot?referenceDate=YYYY-MM-DD` para adulto autorizado.
- PDF local com família, período/fuso, instante de geração, gráficos de carga/progresso e tabela por membro.
- Semana atual parcial, semana sem dados e linha “Membro removido” sem dados pessoais.
- Visualizar, salvar e compartilhar por ação explícita.

Fora: PDF diário, Kids, envio automático, histórico remoto, alterar tarefas ou regenerar automaticamente arquivo existente.

## 4. Autorização e privacidade

| Perfil | Pode | Não pode |
|---|---|---|
| Administrador/Membro | Snapshot e PDF da própria família | Semana futura ou família externa |
| Kids | — | Snapshot, PDF e compartilhamento familiar |

O backend deriva família da sessão; Kids recebem `403 INSUFFICIENT_PERMISSIONS`. O relatório nunca inclui foto de validação, credenciais ou configurações privadas.

## 5. Contrato

`GET /v1/reports/weekly-snapshot?referenceDate=YYYY-MM-DD` resolve segunda–domingo no fuso familiar. Retorna período/fuso/transição, `generatedAt`, `isPartial`, progresso familiar, carga e linhas por membro com peso e tarefas realizadas; removido usa `memberId: null` e “Membro removido”. Retorna `401 SESSION_EXPIRED`, `403 INSUFFICIENT_PERMISSIONS`, `422 VALIDATION_FAILED` para semana futura/sem interseção e `503 DEPENDENCY_UNAVAILABLE` para snapshot não confirmado.

## 6. Critérios de aceitação

| ID | Fase | Critério |
|---|---:|---|
| CA-01 | 1 | Adulto recebe snapshot consistente apenas da própria família para a semana resolvida pela data. |
| CA-02 | 1 | Kids, sessão inválida e semana inválida são recusados sem vazamento. |
| CA-03 | 1 | Snapshot usa tarefas distintas no total familiar e peso integral por responsável. |
| CA-04 | 1 | Semana atual é parcial; semana sem dados traz zeros/“Sem tarefas”; removido não expõe dado pessoal. |
| CA-05 | 2 | PDF contém período, geração, gráficos e tabela canônicos. |
| CA-06 | 2 | Falha não entrega arquivo incompleto e preserva seleção para nova tentativa. |
| CA-07 | 2 | Salvar/compartilhar é explícito e cancelar não altera dados. |

## 7. Fases

| Fase | Entrega | CAs | Status |
|---|---|---|---|
| 1 | Snapshot, autorização, validação e integridade | CA-01 a CA-04 | a fazer |
| 2 | TEL-051, PDF local e compartilhamento | CA-05 a CA-07 | a fazer |

Fase 1 não é publicável isoladamente.

## 8. Decisões

| # | Decisão | Data | Docs |
|---|---|---|---|
| E-01 | Semana é resolvida por `referenceDate` no fuso da família. | 2026-10-10 | RN62, UC18 e contratos atualizados. |
| E-02 | PDF usa “Membro removido” em créditos históricos. | 2026-10-10 | RN62, UC18 e contratos atualizados. |

## 9. Checklist

- [x] Dependência aprovada, contrato e decisões consolidados.
- [x] Autorização, isolamento, validação e falha na Fase 1.
- [x] Aprovação explícita da SPEC e UX-spec em 2026-10-10.
