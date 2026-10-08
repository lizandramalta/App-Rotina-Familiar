---
name: desenvolver-card
description: Implementa um card já planejado de Backend ou Mobile para uma SPEC/UX-spec aprovada, com validação de dependências, prévia técnica e testes rastreáveis. Use quando o pedido for desenvolver, implementar ou preparar tecnicamente um card.
---

# Desenvolver card

Use esta skill para transformar um card de implementação já planejado em código verificável. Ela não cria SPECs, não aprova documentação e não distribui backlog.

## Entrada e limites

- Receba uma chave/link de card, uma SPEC aprovada ou uma indicação inequívoca do recorte a implementar.
- Identifique a responsabilidade do card: `Backend`, `Mobile` ou integração entre ambos. Não implemente responsabilidades de outro card sem autorização explícita.
- Trate a SPEC funcional como fonte do comportamento e a UX-spec como fonte de apresentação. Documentos de arquitetura definem decisões técnicas; nenhum deles autoriza inventar regras, permissões ou estados.
- Só altere Jira, Figma, serviços externos ou o status de um card se o usuário pedir isso explicitamente.

## Verificação de prontidão

Antes de propor ou alterar código:

1. Leia `AGENTS.md`, `README.md`, `docs/DOCUMENTACAO.md` e `specs/README.md`.
2. Localize a SPEC e a UX-spec vinculadas e confirme que ambas estão com status `aprovada`; para uma capacidade puramente interna, a SPEC deve justificar UX-spec não aplicável.
3. Leia somente os documentos e os trechos citados na seção **Rastreabilidade** da SPEC, mais a arquitetura e as convenções aplicáveis à responsabilidade do card:
   - Mobile: `docs/architecture/mobile-code-conventions.md`.
   - Backend: `docs/architecture/backend-code-conventions.md`.
   - Integração: ambas, respeitando a fronteira entre os projetos.
4. Confirme a fase e os critérios de aceite que o card cobre. Não implemente critérios de outra fase por conveniência.
5. Se houver acesso ao Jira, confira os vínculos de bloqueio. Caso não haja, peça a informação necessária ou declare a limitação, sem supor que uma dependência foi concluída.

### Regra para design e dependências

- Backend pode começar com a SPEC aprovada e suas dependências funcionais prontas.
- Mobile depende do protótipo de **média fidelidade** correspondente e dos contratos de backend que consome.
- Alta fidelidade depende da média, mas **não bloqueia** a implementação funcional Mobile. Sua adaptação visual acontece depois, em card próprio no backlog.
- A ausência de média fidelidade bloqueia somente a parte Mobile afetada; não autoriza substituir decisões de UX por suposições.

## Prévia técnica obrigatória

Antes de editar qualquer arquivo de código, entregue uma prévia e aguarde aprovação explícita. Inclua:

1. card, SPEC/UX-spec, fase e critérios de aceite cobertos;
2. dependências verificadas e pendências que bloqueiam o início;
3. arquivos a criar ou modificar, separados em Mobile e Backend quando aplicável;
4. contratos, migrações, autorização, isolamento familiar, validações e tratamento de falhas que serão preservados;
5. estratégia de testes (unidade, integração, UI/contrato), incluindo os critérios que cada grupo verifica;
6. riscos ou esclarecimentos que impedem uma implementação segura.

Não faça mudanças enquanto a prévia não for aprovada. Se uma lacuna mudar comportamento, permissão, dado, contrato, limite ou estado, registre-a como esclarecimento e peça uma decisão; não preencha a lacuna com uma escolha técnica.

## Implementação

Depois da aprovação técnica:

- Prepare o Git antes de editar código. Confirme que não há alterações não relacionadas no worktree; não faça stash, reset ou descarte automático. Execute `git fetch origin develop`, valide a referência `origin/develop` e crie a branch diretamente dela com `git switch --create feature/<CHAVE-JIRA>_<descricao-curta> origin/develop`.
- Use a chave Jira do card como identificador preservado (`SCRUM-123`) e uma descrição curta em minúsculas, ASCII e `kebab-case` (`feature/SCRUM-123_create-family`). Se a branch já existir ou `origin/develop` não estiver acessível, pare e peça orientação em vez de reutilizar, sobrescrever ou partir de outra referência.
- Implemente somente o recorte e a fase aprovados.
- Inclua autorização, isolamento entre famílias, validação e falhas recuperáveis na primeira exposição da capacidade; não trate esses itens como acabamento.
- Use nomes de código, arquivos, APIs e testes em inglês. Mantenha documentação explicativa em português e textos de interface localizáveis.
- Preserve os limites do card: um card Backend não cria telas; um card Mobile não altera regra ou contrato não sustentado pela SPEC.
- Quando a implementação depender de resposta incerta ou concorrência, siga exatamente o comportamento definido na SPEC e no contrato, incluindo reconciliação antes de repetir uma ação.

## Verificação e entrega

1. Execute os testes planejados que estiverem disponíveis e reporte resultado, limitações e testes não executados.
2. Verifique cada critério de aceite atribuído à fase, sem marcar como coberto o que não foi implementado.
3. Resuma arquivos alterados, comportamento entregue, critérios cobertos, testes e riscos residuais.
4. Ao criar uma PR ou atualizar Jira sob solicitação do usuário, cite a SPEC, a UX-spec e os critérios cobertos.
5. Sempre encerre com **Como testar**, destinado a quem desenvolverá/revisará o card. Sugira passos manuais concretos, proporcionais ao escopo e ligados aos critérios de aceite:
   - Mobile: pré-requisitos de ambiente, rota/tela a abrir, ações, estados esperados, acessibilidade e cenários de erro ou permissão relevantes.
   - Backend: configuração necessária, comando para iniciar/testar, chamada HTTP ou fluxo consumidor, status/corpo esperado e cenários de validação, autorização ou isolamento relevantes.
   - Integração: fluxo de tela que dispara a chamada, contrato observado e como confirmar o resultado canônico após uma falha/reconciliação quando aplicável.
   Não invente endpoints, telas ou dados de teste: derive o roteiro da SPEC, UX-spec, contrato e implementação entregue.
