# Criar par de specs

O ID recebido é: `$ARGUMENTS`.

Você é responsável por preparar uma entrega vertical do repositório App-Rotina-Familiar para aprovação. A entrada deve conter somente um ID no formato `SPEC-NNN`, por exemplo `SPEC-007`.

## Objetivo

Localize a entrega correspondente em `specs/README.md`, elabore a prévia do par `SPEC-NNN-nome-curto.md` e `UX-NNN-nome-curto.md` quando houver impacto na experiência, esclareça ambiguidades e só então prepare a implementação.

## Processo obrigatório

1. Valide o argumento. Se não houver exatamente um ID `SPEC-NNN`, solicite somente o ID correto e pare.
2. Leia integralmente `AGENTS.md`, `README.md`, `docs/DOCUMENTACAO.md`, `specs/README.md`, `specs/SPEC-000-template.md` e `specs/UX-000-template.md`.
3. Localize o ID no mapa de implementação. Se ele não existir, informe isso e peça orientação; não crie uma entrega fora do mapa.
4. Valide as dependências. Se alguma estiver ausente ou não aprovada, registre o impacto e pergunte se o trabalho deve seguir apenas como planejamento ou aguardar a dependência.
5. Pesquise os códigos relacionados antes de concluir qualquer regra ou permissão:
   - comportamento: `RN`, `RF`, `RNF`, `UC`;
   - experiência: `TEL`, `MOD`, `UF`;
   - arquitetura: `MA`, `BA`.
   Leia apenas os documentos e trechos indispensáveis à rastreabilidade. Markdown é a fonte vigente; PDFs históricos não orientam decisões.
6. Crie uma SPEC funcional e uma UX-spec em conjunto sempre que a entrega alterar a experiência de alguém no aplicativo. Os dois arquivos usam a mesma numeração e o mesmo nome curto.
   - A SPEC é soberana em comportamento, permissões, dados, validações, contratos, transições e critérios de aceite.
   - A UX-spec é soberana em apresentação, navegação, estados de interface, microcopy localizável, acessibilidade e adaptação iPhone/iPad.
   - Para trabalho exclusivamente interno de backend, marque a UX-spec como não aplicável e justifique tecnicamente na SPEC.
7. Não invente regras, permissões, limites, endpoints, códigos de erro, telas, textos ou decisões arquiteturais. Registre qualquer ausência, ambiguidade ou conflito em **Esclarecimentos**. Se uma resposta puder mudar produto, regra, permissão ou estado, indique os documentos em `docs/` que precisariam ser atualizados antes da aprovação.

## Primeira resposta: prévia, sem escrita

Na primeira execução, não altere arquivos, documentação ou código. Entregue somente uma prévia neste formato:

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

A prévia deve incluir:

- tema, projetos envolvidos e dependências;
- códigos e fontes consultadas;
- escopo, fora de escopo e anti-requisitos;
- regras de acesso e isolamento familiar;
- contrato de dados/API apenas quando as fontes o sustentarem;
- critérios BDD identificados como `CA-NN`;
- fases em que autorização, isolamento entre famílias, validação e tratamento de falhas entram já na Fase 1;
- jornada, superfícies, estados de interface, microcopy com chaves i18n e requisitos de acessibilidade para a UX-spec;
- dúvidas numeradas, objetivas e acionáveis;
- lista exata dos arquivos que serão criados ou modificados após aprovação.

Encerre pedindo aprovação explícita da prévia e as respostas aos esclarecimentos. Não crie arquivos enquanto houver dúvida pendente ou sem aprovação explícita.

## Depois da aprovação da prévia

Após aprovação explícita e resolução das dúvidas:

1. Crie os arquivos a partir dos templates, preservando todas as seções aplicáveis.
2. Atualize o índice de `specs/README.md` com links, status, projetos e resumo.
3. Mantenha o status como `rascunho` ou `em esclarecimento` até não haver pendências. Só marque como `aprovada` quando o usuário o fizer explicitamente.
4. Mostre os arquivos criados e as decisões registradas.
5. Não altere código nesta etapa.

## Antes de qualquer implementação

Implementação só pode começar com SPEC e UX-spec aprovadas. Antes de editar código, apresente uma nova prévia contendo:

- arquivos de código a criar ou modificar;
- comportamento, fase e critérios de aceite que cada alteração cobrirá;
- testes planejados;
- riscos, impacto em mobile/backend e dúvidas remanescentes.

Pare e espere aprovação explícita antes de editar código. Após autorizado, implemente somente os critérios da fase aprovada e cite SPEC, UX-spec e CAs nos testes e na descrição de PR.
