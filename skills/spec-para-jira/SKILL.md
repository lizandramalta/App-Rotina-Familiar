---
name: spec-para-jira
description: Converte uma SPEC/UX-spec aprovada em uma proposta de épico, cards e dependências no Jira, separando UX média, Backend, Mobile e alta fidelidade no backlog. Use quando uma spec aprovada ainda não estiver planejada no Jira ou precisar ser replanejada.
---

# Converter SPEC aprovada para Jira

Use esta skill para alimentar ou replanejar o Jira a partir de uma entrega aprovada. Ela não cria ou aprova specs e não implementa código.

## Pré-condições e leitura

1. Receba uma SPEC, UX-spec ou ID `SPEC-NNN` já existente no mapa de `specs/README.md`.
2. Confirme que a SPEC e, quando aplicável, a UX-spec estão `aprovada`. Se não estiverem, explique que a entrega ainda não entra no planejamento de implementação e pare.
3. Leia `AGENTS.md`, `README.md`, `docs/DOCUMENTACAO.md`, `specs/README.md`, a SPEC, a UX-spec e somente os documentos rastreáveis necessários para entender fases, dependências e contratos.
4. Quando houver acesso ao Jira, pesquise antes o épico, os cards, links e sprints existentes da entrega. Nunca crie duplicatas por não ter inspecionado o estado atual.

## Como decompor

Proponha somente o trabalho sustentado pelas fases e critérios da SPEC. Prefira cards independentes que permitam trabalho em paralelo, sem fragmentar por conveniência.

- Um épico representa uma capacidade coerente; reutilize um épico existente quando o novo recorte pertencer ao mesmo tema.
- Crie um card de **UX média fidelidade** para a experiência que ainda precisa orientar a implementação.
- Crie card(s) de **Backend** para dados, autorização, isolamento familiar, contratos, migrações, operações atômicas e testes que pertencem ao servidor.
- Crie card(s) de **Mobile** para o fluxo funcional, estados, integração de contrato e testes de interface.
- Crie um card de **UX alta fidelidade/handoff** somente como adequação visual posterior, no backlog. Ele depende da média e não entra como bloqueio de Mobile.
- Para trabalho estritamente interno de backend, não crie cards de UX ou Mobile sem evidência na SPEC.

## Dependências obrigatórias

Registre dependências formais no Jira e descreva-as no card quando ajudarem a execução:

```text
UX média ──→ UX alta
UX média ──→ Mobile
Backend  ──→ Mobile, quando o card consumir esse contrato
UX alta  ──→ backlog de adequação visual
```

- Nunca crie `UX alta → Mobile`.
- Não bloqueie Backend por protótipo visual, salvo decisão explícita da SPEC.
- Preserve dependências funcionais entre specs; não substitua um bloqueio real por ordem de sprint.
- Se o card já existir, ajuste apenas o que a SPEC aprovada e a decisão de planejamento sustentarem.

## Proposta antes de escrever no Jira

Antes de criar, editar, mover ou vincular qualquer item no Jira, apresente uma proposta para aprovação explícita contendo:

1. SPEC/UX-spec, status, fases e critérios que alimentam os cards;
2. épico a criar ou reutilizar;
3. tabela de cards: resumo, tipo, responsabilidade (`UX`, `Backend`, `Mobile`), escopo, fase, destino (sprint ou backlog) e dependências;
4. distribuição sugerida de sprint, marcos e riscos de capacidade;
5. links formais a criar, remover ou preservar;
6. labels e convenções propostas;
7. cards existentes que serão atualizados e qualquer duplicidade ou ambiguidade encontrada.

Sem aprovação explícita, não altere o Jira. Se a escolha de sprint, escopo ou card depender de uma decisão ainda não tomada, mantenha-o como proposta ou backlog; não presuma uma data.

## Escrita e verificação no Jira

Após aprovação explícita:

1. Crie ou atualize somente os épicos e cards aprovados, em português, com tipo e responsabilidade claros.
2. Atribua a sprint aprovada; itens de alta fidelidade ficam no backlog até que o planejamento os traga para uma sprint.
3. Aplique labels coerentes, incluindo a SPEC, a responsabilidade e a fase quando relevante.
4. Crie, ajuste ou remova apenas os links de dependência aprovados.
5. Leia de volta os itens afetados e valide épico, sprint/backlog, links e ausência de bloqueio de alta fidelidade sobre Mobile.
6. Entregue os links dos cards, o que foi criado/atualizado e pendências para o próximo planejamento.
