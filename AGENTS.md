# Guia para desenvolvimento assistido por IA

Este repositório contém a definição do produto e, futuramente, dois projetos de
implementação independentes:

- `mobile/`: aplicativo iOS/iPadOS.
- `backend/`: API, jobs e infraestrutura do servidor.
- `specs/`: recortes aprovados que orientam entregas verticais entre os dois projetos.
- `docs/`: base documental vigente do produto, UX, modelo e arquitetura.

## Antes de alterar código

Quando o pedido for implementar ou preparar tecnicamente um card já planejado ou uma
SPEC aprovada, leia e aplique `skills/desenvolver-card/SKILL.md` antes de
propor ou alterar código.

Quando o pedido for criar ou atualizar o protótipo de média fidelidade no Figma para
um card Mobile já planejado, leia e aplique `skills/desenvolver-card-ux/SKILL.md`
antes de propor ou alterar o arquivo Figma.

Quando o pedido indicar `SPEC-NNN` ou solicitar a criação de uma especificação, leia e
aplique `skills/criar-spec/SKILL.md` antes de propor ou alterar arquivos de spec.

Quando o pedido for converter uma SPEC aprovada em cards ou replanejar essa entrega no
Jira, leia e aplique `skills/spec-para-jira/SKILL.md` antes de alterar o Jira.

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

## Decisões tomadas em chat

Quando uma dúvida for resolvida ou uma decisão for tomada durante a conversa, sinalize
imediatamente na resposta de chat:

1. a decisão e seu impacto em comportamento, permissão, dado, contrato, estado ou
   escopo;
2. os documentos funcionais que precisam ser atualizados, citando arquivo e códigos
   (`RN`, `RF`, `RNF` ou `UC`) quando existirem;
3. os artefatos posteriores afetados, como SPEC/UX-spec, fluxos, Figma, contratos,
   Jira, código ou testes.

Essa sinalização é uma comunicação de chat: não a replique como anotação, legenda ou
texto no Figma. Ela não substitui a atualização formal necessária da documentação
funcional nem os registros exigidos pela SPEC; uma decisão que altere comportamento,
permissão ou estado só fica consolidada depois que as fontes aplicáveis forem
atualizadas.

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
