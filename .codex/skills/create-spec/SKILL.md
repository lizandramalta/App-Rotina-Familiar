---
name: create-spec
description: Cria a prévia e conduz a aprovação de uma SPEC e UX-spec de entrega quando o usuário fornece um ID SPEC-NNN. Use para preparar specs do App-Rotina-Familiar; não use para implementar código.
---

# Criar specs

Use esta skill quando o usuário pedir para criar, planejar ou preparar uma entrega
identificada por `SPEC-NNN` no App-Rotina-Familiar. A entrada esperada é um único ID,
por exemplo: `$create-spec SPEC-007`.

## Preparar a prévia

1. Valide o ID e localize-o no mapa de `specs/README.md`. Se não existir, informe o
   problema e peça orientação; não crie uma entrega fora do mapa.
2. Leia `AGENTS.md`, `README.md`, `docs/DOCUMENTACAO.md`, `specs/README.md` e os
   templates `specs/SPEC-000-template.md` e `specs/UX-000-template.md`.
3. Valide as specs dependentes. Se não estiverem aprovadas, registre o impacto e
   pergunte se deve continuar apenas como planejamento ou aguardar.
4. Pesquise os códigos pertinentes antes de definir comportamento: `RN`, `RF`, `RNF`,
   `UC`, `TEL`, `MOD`, `UF`, `MA` e `BA`. Leia apenas as fontes e trechos necessários.
   Markdown é a fonte vigente; PDFs históricos não definem comportamento.
5. Prepare uma SPEC funcional e, quando a entrega alterar a experiência, uma UX-spec
   vinculada com a mesma numeração e nome curto. Para backend estritamente interno,
   justifique na SPEC por que a UX-spec não se aplica.

Não invente regras, permissões, limites, telas, textos, contratos, códigos de erro ou
decisões arquiteturais. Registre lacunas, ambiguidades e conflitos em
**Esclarecimentos** e identifique documentos que precisariam ser atualizados se uma
decisão mudasse o produto.

## Primeira resposta: sem escrita

Antes de criar ou editar qualquer arquivo, entregue uma prévia com:

- entrega identificada, tema, projetos e dependências;
- rastreabilidade e fontes consultadas;
- escopo, fora de escopo e anti-requisitos;
- autorização e isolamento familiar;
- contratos de dados/API sustentados pelas fontes;
- critérios BDD identificados como `CA-NN` e fases de entrega;
- proposta da UX-spec: jornada, superfícies, estados, microcopy com chaves i18n e
  acessibilidade;
- esclarecimentos numerados;
- arquivos exatos que seriam criados ou atualizados.

Peça aprovação explícita da prévia e respostas para os esclarecimentos. Não escreva
arquivos enquanto houver pendências ou sem essa aprovação.

## Após aprovação da prévia

Crie os documentos a partir dos templates e atualize o índice de `specs/README.md`.
Mantenha-os como `rascunho` ou `em esclarecimento` enquanto houver pendências; só
marque-os como `aprovada` quando o usuário autorizar explicitamente. Relate os arquivos
criados e as decisões registradas. Não altere código nesta etapa.

## Limite antes da implementação

Uma implementação exige SPEC e UX-spec aprovadas. Antes de editar código, apresente uma
segunda prévia técnica com arquivos afetados, fase e CAs cobertos, testes planejados,
riscos e impacto mobile/backend. Espere aprovação explícita novamente antes de fazer
qualquer alteração de código.
