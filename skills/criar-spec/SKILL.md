---
name: criar-spec
description: Prepara e cria um par rastreável de SPEC e UX-spec para uma entrega planejada, mantendo o status em rascunho até aprovação explícita. Use quando o pedido indicar SPEC-NNN ou solicitar uma nova especificação de entrega.
---

# Criar par de specs

Use esta skill para preparar uma entrega vertical para aprovação. Ela não implementa código nem muda o status para `aprovada` sem autorização explícita do usuário.

## Entrada e descoberta

- A entrada deve conter exatamente um ID `SPEC-NNN` previsto em `specs/README.md`.
- Se o ID estiver ausente, inválido ou não existir no mapa, solicite orientação e pare. Não crie uma entrega fora do mapa.
- Leia `AGENTS.md`, `README.md`, `docs/DOCUMENTACAO.md`, `specs/README.md`, `specs/SPEC-000-template.md` e `specs/UX-000-template.md`.
- Valide as dependências da entrega. Quando uma dependência não estiver aprovada, informe o impacto e pergunte se o trabalho deve ficar apenas em planejamento ou aguardar.

## Delimitação baseada em fontes

1. Pesquise os códigos que pertencem ao recorte antes de concluir regras ou permissões: `RN`, `RF`, `RNF`, `UC`, `TEL`, `MOD`, `UF`, `MA` e `BA`.
2. Leia apenas os documentos e trechos indispensáveis à rastreabilidade. Markdown é vigente; PDFs são históricos.
3. Crie uma SPEC funcional e uma UX-spec com mesma numeração e nome curto sempre que a entrega alterar a experiência.
   - A SPEC define comportamento, permissões, dados, validações, contratos, transições e critérios de aceite.
   - A UX-spec define apresentação, navegação, estados, microcopy localizável, acessibilidade e adaptação iPhone/iPad.
   - Em trabalho exclusivamente interno de backend, registre UX-spec como não aplicável e justifique na SPEC.
4. Não invente regras, permissões, limites, endpoints, erros, telas, textos ou decisões arquiteturais. Registre lacunas, ambiguidades e conflitos em **Esclarecimentos**. Se uma resposta alterar o produto, indique primeiro quais fontes em `docs/` precisam mudar.

## Primeira resposta: prévia, sem escrita

Na primeira execução não altere arquivos, documentação ou código. Entregue uma prévia com:

```md
# Prévia — SPEC-NNN

## Entrega identificada
## Dependências
## Rastreabilidade proposta
## SPEC funcional proposta
## UX-spec proposta
## Critérios de aceitação e fases
## Esclarecimentos necessários
## Arquivos que serão alterados após aprovação
## Próxima decisão necessária
```

Inclua tema, projetos envolvidos, escopo, fora de escopo, anti-requisitos, regras de acesso, isolamento familiar e contratos sustentados pelas fontes. Proponha critérios BDD como `CA-NN`; coloque autorização, isolamento, validação e falhas já na primeira fase que expõe a capacidade. Para a UX-spec, detalhe jornada, superfícies, estados, microcopy com chaves i18n e acessibilidade.

Liste dúvidas numeradas e acionáveis e a lista exata de arquivos a criar ou alterar. Peça aprovação explícita e as respostas aos esclarecimentos. Não escreva enquanto existir dúvida pendente ou não houver aprovação.

## Após aprovação da prévia

1. Crie os arquivos a partir dos templates, preservando as seções aplicáveis.
2. Atualize `specs/README.md` com links, status, projetos e resumo.
3. Mantenha o status em `rascunho` ou `em esclarecimento` enquanto houver pendências. Só use `aprovada` quando o usuário autorizar explicitamente.
4. Apresente os arquivos criados e as decisões registradas; não altere código nesta etapa.

## Encaminhamento para desenvolvimento

Quando a SPEC e a UX-spec estiverem aprovadas, aplique `desenvolver-card` para preparar o plano técnico. Essa etapa exige uma segunda prévia de arquivos de código, critérios, testes, riscos e impacto em Mobile/Backend antes de editar implementação.
