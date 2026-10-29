# SPEC-020: Apurar e compartilhar destaque semanal

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Usuária | **Em:** 2026-10-10  
**Base funcional:** 1.17  
**UX-spec:** [UX-020-destaque-semanal.md](UX-020-destaque-semanal.md)  
**Projetos envolvidos:** ambos  
**Tema do backlog:** Tema 5 — Acompanhamento e reconhecimento

## 1. Objetivo

Reconhecer a maior participação semanal sem ranking completo, permitindo à pessoa reconhecida celebrar opcionalmente com a família.

## 2. Rastreabilidade e dependências

| Categoria | Códigos |
|---|---|
| Caso de uso | UC19 |
| Regras | RN28, RN30, RN65 |
| Requisitos | RF63–64 |
| Não funcionais | RNF01, RNF04–08, RNF10, RNF12–13, RNF22, RNF26–27 |
| Telas/fluxo | TEL-010, TEL-040, TEL-052, UF-15 |
| Arquitetura | MA-07, MA-09–11, MA-13, MA-15; BA-05–08, BA-13, BA-17, BA-20 |

- **Depende de:** SPEC-018 aprovada.
- **Infraestrutura:** job/outbox PostgreSQL e APNs; WhatsApp é integração local opcional.

## 3. Escopo

- `FinalizeWeeklyHighlight` por família/ciclo, recuperável e idempotente por chave natural.
- Maior pontuação positiva, empate, semana sem vencedor e resultado final imutável.
- Intenção de notificação por reconhecido, consulta apenas do próprio resultado e abertura monotônica.
- TEL-052, mensagem editável, WhatsApp ou cópia local.

Fora: ranking completo, revisão tardia do resultado, envio automático, garantia de entrega/leitura, carga/PDF para Kids e endpoint de WhatsApp.

## 4. Autorização e privacidade

| Perfil | Pode | Não pode |
|---|---|---|
| Reconhecido A/M/K | Consultar apenas seu resultado | Consultar resultado alheio |
| Não reconhecido | Não recebe resultado de terceiros | Inferir pontuação/classificação alheia |

O job avalia ativos no ciclo. `recognitionId` fora da titularidade responde `404 RESOURCE_NOT_FOUND`; sessão inválida responde `401 SESSION_EXPIRED`.

## 5. Contratos

- `GET /v1/me/weekly-recognitions`: lista finalizada do titular.
- `GET /v1/me/weekly-recognitions/{recognitionId}`: período/fuso, pontos, tarefas realizadas, empate e dados de apresentação.
- `POST /v1/me/weekly-recognitions/{recognitionId}/opening`: registra primeira abertura sem alegar leitura/envio.

APNs recebe apenas tipo e ID; falha ou ausência de dispositivo não remove a consulta interna. WhatsApp é aberto somente pelo app após ação humana.

## 6. Critérios de aceitação

| ID | Fase | Critério |
|---|---:|---|
| CA-01 | 1 | Job apura uma vez cada família/ciclo no fuso aplicável, sem depender do app. |
| CA-02 | 1 | Maior pontuação positiva reconhece todos os empatados; zero positivo registra ausência de vencedor. |
| CA-03 | 1 | Falha/reprocessamento não duplicam resultado ou intenção de notificação. |
| CA-04 | 1 | Edição/reabertura tardia não revisa resultado final. |
| CA-05 | 1 | Consulta é exclusiva do titular; sessão removida/inválida não acessa resultado. |
| CA-06 | 1 | Push não comprova entrega/leitura nem condiciona consulta interna. |
| CA-07 | 2 | TEL-052 mostra período, pontos, tarefas e variante de empate/Kids. |
| CA-08 | 2 | WhatsApp/cópia exige ação explícita, é editável e cancelável. |

## 7. Fases

| Fase | Entrega | CAs | Status |
|---|---|---|---|
| 1 | Ciclos, apuração, outbox, consultas e autorização | CA-01 a CA-06 | a fazer |
| 2 | TEL-052 e compartilhamento local | CA-07 a CA-08 | a fazer |

Fase 1 não é publicável isoladamente.

## 8. Checklist

- [x] Dependência, regras e contrato técnico mapeados.
- [x] Segurança, titularidade e falhas presentes na Fase 1.
- [x] Aprovação explícita da SPEC e UX-spec em 2026-10-10.
