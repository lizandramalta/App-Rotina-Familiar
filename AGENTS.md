# Guia para desenvolvimento assistido por IA

Este repositório contém a definição do produto e, futuramente, dois projetos de
implementação independentes:

- `mobile/`: aplicativo iOS/iPadOS.
- `backend/`: API, jobs e infraestrutura do servidor.
- `specs/`: recortes aprovados que orientam entregas verticais entre os dois projetos.
- `docs/`: base documental vigente do produto, UX, modelo e arquitetura.

## Antes de alterar código

1. Leia `README.md`, `docs/DOCUMENTACAO.md` e `specs/README.md`.
2. Identifique a spec aprovada que cobre a tarefa. Caso ela ainda não exista, use
   `specs/SPEC-000-template.md` para criá-la antes de implementar comportamento novo.
3. Se a entrega altera a experiência do aplicativo, localize também a UX-spec vinculada.
   Caso ainda não exista, crie-a com `specs/UX-000-template.md` antes da aprovação.
4. Leia somente os documentos citados na seção **Rastreabilidade** da spec, além dos
   documentos técnicos aplicáveis ao projeto em que vai trabalhar.
5. Busque pelo código citado (`RN`, `RF`, `RNF`, `UC`, `TEL`, `MOD`, `UF`, `MA` ou
   `BA`) antes de inferir uma regra ou uma permissão.

Não carregue nem resuma toda a pasta `docs/` como contexto padrão. A documentação é
uma base de consulta: use a rastreabilidade da spec para ler a menor fatia necessária.

## Fontes de verdade e conflitos

- O comportamento do produto vem de `docs/01-regras-de-negocio.md`,
  `docs/02-requisitos.md` e `docs/03-casos-de-uso.md`.
- A spec aprovada define o recorte de entrega e seus critérios de aceitação; ela não
  pode contradizer a base funcional. Se precisar contradizê-la, atualize a base e a
  rastreabilidade antes de aprovar a spec.
- `docs/design/` e uma UX-spec definem apresentação, textos, navegação e estados
  visuais; não alteram permissões, estados de domínio ou regras de negócio.
- `docs/architecture/` define decisões e contratos técnicos. `MA` significa decisão
  de arquitetura mobile e `BA`, decisão de arquitetura backend.
- PDFs em `output/pdf/` são históricos. Markdown e diagramas referenciados em
  `docs/DOCUMENTACAO.md` são a fonte vigente.

Quando uma informação não existir, estiver ambígua ou entrar em conflito, não invente
comportamento. Registre-a em **Esclarecimentos** na spec e peça uma decisão antes de
implementar.

## Fluxo obrigatório para criar e aprovar specs

Quando o pedido indicar um ID `SPEC-NNN`, localize-o no mapa de `specs/README.md`,
valide suas dependências e prepare a SPEC funcional e, se houver impacto na
experiência, a UX-spec correspondente com a mesma numeração e nome curto. Antes de
preencher a rastreabilidade, pesquise os códigos aplicáveis (`RN`, `RF`, `RNF`, `UC`,
`TEL`, `MOD`, `UF`, `MA` e `BA`) e leia somente os trechos necessários.

Na primeira resposta, não crie nem altere arquivos. Apresente uma prévia para
aprovação contendo: entrega identificada, dependências, rastreabilidade proposta,
escopo e anti-requisitos, regras de acesso e isolamento familiar, contratos de dados
ou API que sejam sustentados pelas fontes, critérios BDD e fases, proposta da UX-spec
(jornada, superfícies, estados, microcopy localizável e acessibilidade),
esclarecimentos pendentes e a lista exata de arquivos que serão modificados.

Peça aprovação explícita da prévia e respostas para os esclarecimentos. Somente depois
da aprovação, crie os arquivos a partir dos templates e atualize o índice em
`specs/README.md`. Mantenha o status como `rascunho` ou `em esclarecimento` enquanto
houver pendências; apenas o usuário pode autorizar o status `aprovada`.

Com SPEC e UX-spec aprovadas, antes de alterar código, apresente uma segunda prévia
técnica: arquivos a criar ou modificar, fase e critérios de aceite cobertos, testes
planejados, riscos e impacto em mobile/backend. Aguarde nova aprovação explícita antes
de editar código.

## Implementação e verificação

- Implemente somente critérios de aceitação atribuídos à fase em andamento.
- Mantenha autorização, isolamento entre famílias, validação e tratamento de falhas
  na primeira fase que expõe uma capacidade; não os adie como acabamento.
- Nomes de código, arquivos, APIs, bancos e testes são em inglês. A documentação
  explicativa permanece em português e textos de interface devem ser localizáveis.
- Cite a spec e os critérios de aceitação cobertos nos testes e nas descrições de PR.
- Mudanças de comportamento exigem atualizar a documentação afetada, sua versão e
  referências; mudanças somente técnicas devem atualizar a decisão arquitetural
  correspondente quando necessário.
