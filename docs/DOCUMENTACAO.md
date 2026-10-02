# Documentação do projeto — versão 1.0

**Projeto:** App de Organização Familiar — MVP  
**Versão:** 1.0  
**Data:** 2026-10-01  
**Situação:** base documental consolidada

[Projeto](../README.md) · [Visão do produto](00-visao-do-produto.md) · [Índice e versões](DOCUMENTACAO.md) · [Regras de negócio](01-regras-de-negocio.md) · [Requisitos](02-requisitos.md) · [Casos de uso](03-casos-de-uso.md) · [Diagramas UML](04-diagramas-de-caso-de-uso.md)

## Documentos

| Arquivo | Conteúdo |
|---|---|
| [Apresentação do projeto](../README.md) | Propósito, público, jornada e escopo do MVP. |
| [Visão do produto](00-visao-do-produto.md) | Contexto, objetivos, princípios, escopo e critérios de sucesso. |
| [Índice e versões](DOCUMENTACAO.md) | Organização documental, rastreabilidade e política de versões. |
| [Regras de negócio](01-regras-de-negocio.md) | 56 regras vigentes e suas relações com RF, RNF e UC. |
| [Requisitos](02-requisitos.md) | 59 requisitos funcionais e 25 não funcionais, com vínculos às regras e aos casos de uso. |
| [Especificação dos casos de uso](03-casos-de-uso.md) | 17 casos de uso completos, com atores, pré-condições, fluxos, alternativas e pós-condições. |

| [Diagramas de caso de uso](04-diagramas-de-caso-de-uso.md) | Visão geral e quatro recortes UML, com fontes PlantUML e imagens SVG. |

## Como usar

Mantenha o `README.md` na raiz e preserve a pasta `docs/`, incluindo `diagramas/casos-de-uso/`. Os links são relativos e continuam funcionando quando a pasta é movida. Cada regra, requisito e caso de uso tem uma seção identificada por seu código. Em ambientes que não naveguem por links locais, o código permite localizar a referência no arquivo correspondente.

Esta é uma base completa e consolidada. Não é uma lista de correções e não depende do PDF original ou do documento intermediário de revisão para descrever o comportamento vigente. Os documentos anteriores servem apenas como referência histórica.

## Rastreabilidade

- **Visão → RN/RF/UC:** as tabelas de regras centrais e de escopo conectam a proposta do produto aos comportamentos detalhados. Todos os documentos têm navegação para a visão e para a apresentação do projeto.
- **RN → RF/RNF → UC:** cada regra aponta para os requisitos relacionados e os fluxos associados.
- **RF → RN e UC:** cada requisito funcional aponta para suas regras e os casos de uso que o realizam.
- **RNF → RN e UC:** cada requisito não funcional aponta para as regras específicas, quando houver, e para os fluxos em que se aplica.
- **UC → RF, RN e RNF:** cada caso de uso reúne seus requisitos e regras para facilitar implementação e revisão.
- RF48 é um requisito autônomo de edição do próprio perfil, sem RN específica. Requisitos transversais de qualidade também podem não derivar de uma RN; isso está explicitado em suas seções.

As relações RN–UC são derivadas de RN–RF–UC. As relações de RNF representam aplicabilidade e não criam novos passos no fluxo. A ausência de RNF específico em uma regra não dispensa requisitos transversais de segurança, acessibilidade e confiabilidade.

## Decisões consolidadas na versão 1.0

- Criador com família existente é redirecionado para ela; membro removido perde o acesso, inclusive por sessões existentes.
- Ingresso exige link e senha gerada pelo sistema, enviados juntos. A senha é usada somente para efetivar o vínculo, e o conjunto admite um ingresso bem-sucedido.
- Kids podem sinalizar a realização com foto opcional. A sinalização não produz conclusão parcial. Confirmação do Administrador ou conclusão manual por adulto conclui a tarefa para todos os responsáveis.
- Adultos podem concluir tarefa de outras pessoas mantendo os responsáveis ou assumindo-a, com aviso sobre o crédito. Assumir substitui todos os responsáveis pelo usuário que conclui.
- Cada responsável recebe o peso integral da tarefa compartilhada. A carga total soma as cargas individuais; o progresso de uma missão conta cada tarefa apenas uma vez.
- Todos os perfis visualizam o próprio progresso diário. Somente Administradores e Membros acessam a carga semanal.
- O carrossel vai da criação da família até o último dia do mês corrente, incluindo dias futuros dentro desse mês.
- Missões não têm prazo nem expiram. A missão permanece em andamento enquanto houver tarefas não concluídas.
- Administradores podem adicionar itens personalizados à roleta. A recompensa é vinculada à missão somente após sorteio e aceitação, com resgate único.
- Tarefas concluídas não podem ser excluídas diretamente. Somente Administradores podem reabri-las quando vinculadas a missão em andamento, desde que não pertençam a nenhuma missão concluída. Não há reabertura de tarefa concluída sem missão nesta versão.
- Reabrir retira a contribuição da conclusão anterior da carga e do progresso. A exclusão posterior não desconta o peso novamente.
- Missões concluídas preservam seus dados e vínculos. O resgate ainda disponível pode acrescentar a recompensa, sem modificar a conquista. A exclusão de tarefa não pode deixar uma missão sem tarefas.

## Convenções

- RN = regra de negócio; RF = requisito funcional; RNF = requisito não funcional; UC = caso de uso.
- “Adulto”, nos fluxos, designa os perfis Administrador e Membro, sem criar um novo perfil.
- “Responsáveis finais” são os responsáveis registrados na conclusão, após eventual substituição. O usuário que executa a ação pode ser outra pessoa.
- “Pendente”, “Aguardando confirmação” e “Concluída” são estados de tarefa. Missões ficam em andamento ou concluídas, sem estado de expiração temporal.
- A numeração foi preservada. RN15, RN29 e RN32 não estavam definidos e não são reutilizados nesta versão.

## Política de versionamento

1. A base funcional permanece na versão **1.0**. O documento de diagramas e seus arquivos são um complemento visual dessa base, sem mudança de comportamento.
2. Em revisão futura, preserve os identificadores existentes; novos itens recebem novos códigos. Não reutilize códigos removidos para outro significado.
3. Publique o conjunto completo em uma nova pasta de versão, preservando esta base para comparação. Atualize versão, data e histórico de todos os arquivos do conjunto.
4. No histórico, registre os códigos afetados, a decisão e o motivo. Alterações de comportamento e suas referências devem ser atualizadas juntas.
5. Use **1.1, 1.2...** para revisões incrementais e **2.0** para uma nova base com mudanças substanciais de escopo ou comportamento.

## Histórico de versões

| Versão | Data | Alteração |
|---|---|---|
| 1.0 | 2026-10-01 | Primeira versão consolidada, incluindo a visão alinhada ao MVP, a apresentação global do projeto e todas as decisões registradas até esta publicação. |

Complemento visual de 2026-10-01: adicionados cinco diagramas de UC01–UC17 e referências de navegação; mantida a base funcional 1.0.
