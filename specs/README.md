# Specs de entrega

Esta pasta contém as especificações aprovadas que transformam a base documental em
entregas pequenas, testáveis e rastreáveis entre `mobile/` e `backend/`.

As specs são contratos de trabalho, não uma nova fonte de verdade para o produto. Elas
delimitam o que será entregue, quais regras aplicam e quais critérios devem ser
verificados. A base funcional continua em `docs/`.

## Como criar uma spec funcional

1. Copie `SPEC-000-template.md` para `SPEC-NNN-nome-curto.md`.
2. Preencha a rastreabilidade com os códigos que realmente pertencem ao recorte.
3. Leia os documentos citados, convertendo os comportamentos relevantes em critérios
   de aceitação verificáveis.
4. Registre toda lacuna em **Esclarecimentos**. Se ela mudar o produto, atualize
   primeiro a documentação em `docs/`.
5. Associe cada critério a uma única fase e aprove a spec apenas após o checklist.

## UX-spec e fluxo de trabalho

Para toda entrega que altera a experiência de alguém no aplicativo, crie uma UX-spec
em paralelo usando `UX-000-template.md`. Use a mesma numeração e o mesmo nome curto da
spec funcional: por exemplo, `SPEC-001-criar-tarefa.md` e
`UX-001-criar-tarefa.md`. Para trabalho estritamente interno de backend, a spec deve
registrar **UX-spec: não aplicável** e justificar.

1. Crie a spec funcional e a UX-spec ainda como rascunhos, vinculando uma à outra.
2. A spec converte regras e casos de uso em critérios de aceitação; a UX-spec detalha
   entradas, navegação, conteúdo, feedback, microcopy e acessibilidade.
3. Revise e aprove as duas juntas. Se uma decisão de UX mudar uma regra, permissão ou
   estado, ela volta para a spec funcional e para `docs/` antes da aprovação.
4. Na implementação, mobile consulta as duas; backend consulta a spec funcional e os
   contratos técnicos. Cada PR aponta os critérios e a UX-spec que cobriu.

UX-spec não substitui wireframes ou protótipos: ela é o registro textual e rastreável
da experiência. Isso permite evoluir o visual sem perder decisões, estados e textos.

## Leitura por tipo de trabalho

| Trabalho | Consulte além da spec |
|---|---|
| Regra, permissão ou estado | `01-regras-de-negocio.md`, `02-requisitos.md`, `03-casos-de-uso.md` |
| Experiência e interface | `design/screen-map.md`, `design/user-flows.md` e a UX-spec vinculada |
| Mobile | `architecture/mobile-architecture.md`, `mobile-feature-catalog.md`, `mobile-decisions.md` |
| Backend ou API | `architecture/backend-architecture.md`, `backend-contracts.md`, `backend-decisions.md`, `05-modelo-de-dados.md` |
| Alteração compartilhada | As fontes mobile e backend acima, mais os contratos de API |

## Índice

| Spec | Status | Projetos | Resumo |
|---|---|---|---|
| Nenhuma spec criada ainda | — | — | Use o template para iniciar a primeira entrega. |

## Templates

- `SPEC-000-template.md`: comportamento, critérios de aceitação e fases.
- `UX-000-template.md`: experiência, navegação, estados e textos da interface.
