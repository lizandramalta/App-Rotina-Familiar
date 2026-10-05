# Spec NNN: [Nome curto da funcionalidade]

**Status:** rascunho | em esclarecimento | aprovada | em implementação (fase N) | implementada
**Autor:** | **Criada em:** AAAA-MM-DD | **Aprovada por:** | **Em:**
**Base funcional:** [versão vigente da documentação]
**UX-spec:** [link para a UX-spec desta funcionalidade] | não aplicável: [motivo]
**Projetos envolvidos:** mobile | backend | ambos

<!--
COMO PREENCHER
- A spec descreve O QUÊ e POR QUÊ. Não cite tecnologia (banco, framework, tela em SwiftUI).
- Não reescreva regras de docs/: cite os códigos (RN, RF, RNF, UC, TEL, UF).
- Uma spec = uma fatia pequena, testável de ponta a ponta (em geral, um ou dois UCs).
- Só mude o status para "aprovada" com o checklist da seção 12 completo.
- Fases (seção 11) dividem a entrega em etapas funcionais; não descrevem tecnologia.
- Esta spec define COMPORTAMENTO (o que o sistema faz e as regras). A UX-spec define a EXPERIÊNCIA
  (layout, textos de interface, estados visuais, interações). Se um assunto aparecer nas duas,
  esta spec vale para o comportamento e a ux-spec para a apresentação; divergência é erro a corrigir.
-->

## 1. Objetivo

Uma ou duas frases: o que esta entrega faz e para qual perfil.

## 2. Rastreabilidade

| Tipo | Códigos incluídos nesta spec |
|---|---|
| Casos de uso | UC.. |
| Regras de negócio | RN.. |
| Requisitos funcionais | RF.. |
| Requisitos não funcionais com teste específico | RNF.. |
| Telas / fluxos | TEL-.., UF-.. |
| Decisões técnicas aplicáveis | MA-.., BA-.. |

**Documentos consultados:** [links para os arquivos necessários desta entrega]

**Depende de:** specs que precisam estar implementadas antes desta.

## 3. Escopo

**Dentro:** o que será entregue.

**Fora (desta spec):** partes dos UCs acima que ficam para outra spec, e por quê.

## 4. Projetos e responsabilidades

| Projeto | Responsabilidade nesta entrega | Interface compartilhada |
|---|---|---|
| Mobile | | |
| Backend | | |

Remova a linha de projeto que não participa da entrega. Esta seção aponta fronteiras;
contratos técnicos continuam nas referências de arquitetura.

## 5. Perfis e permissões

| Perfil | Pode | Não pode |
|---|---|---|
| Administrador | | |
| Membro | | |
| Kids | | |

## 6. Estados e transições

Preencha apenas se a funcionalidade muda estados (de tarefa, missão, convite...).

| De | Evento | Para | Quem | Regra |
|---|---|---|---|---|

## 7. Critérios de aceitação

Um comportamento por linha, verificável por teste, citando a origem. Numere (CA-01, CA-02...) para que testes e PRs possam referenciá-los.

Formatos:
- QUANDO [evento], O SISTEMA DEVE [comportamento].
- SE [condição indesejada], ENTÃO O SISTEMA DEVE [reação].
- ENQUANTO [estado], O SISTEMA DEVE [comportamento].

- **CA-01** QUANDO ..., O SISTEMA DEVE ... *(RN.., UC.. passo ..)*
- **CA-02** SE ..., ENTÃO O SISTEMA DEVE ... *(..)*

Garanta que existam critérios para:
- [ ] Fluxo principal de cada UC incluído
- [ ] Cada alternativa e exceção desses UCs
- [ ] Recusa para cada perfil sem permissão (RNF07)
- [ ] Recusa para usuário de outra família (RNF06)
- [ ] Ações simultâneas, se houver mudança de estado (RNF11)
- [ ] Falha de gravação ou de rede (RNF12, RNF13)

## 8. Premissas

O que se está assumindo como verdade e não está escrito em docs/. Cada premissa vira uma pergunta na seção 9.

- P1.

## 9. Esclarecimentos

Dúvidas levantadas ao escrever a spec e a decisão tomada.

| # | Pergunta | Decisão | Quem decidiu / data | Altera docs/? |
|---|---|---|---|---|
| E1 | | | | |

Se "Altera docs/" for sim, a base funcional é atualizada antes de aprovar esta spec.

## 10. Fora de questão

Comportamentos que alguém poderia supor, mas que não existem. Evita que funcionalidades sejam inventadas na implementação.

-

## 11. Fases de implementação

Divide a entrega em etapas, cada uma utilizável e testável sozinha. A ordem segue dependências: o que vem antes não pode depender do que vem depois. Toda fase entrega um conjunto de critérios da seção 7, e todo critério pertence a exatamente uma fase.

| Fase | Entrega | Critérios atendidos | Pronta quando | Status |
|---|---|---|---|---|
| 1 | Núcleo mínimo: fluxo principal, já com permissões e isolamento por família | CA-.. | Testes dos CAs listados passam | a fazer |
| 2 | Alternativas e exceções dos UCs | CA-.. | | a fazer |
| 3 | Complementos (ex.: anexos, avisos, casos raros) | CA-.. | | a fazer |

Permissões e isolamento por família (RNF06, RNF07) nunca ficam para uma fase posterior: entram junto com a primeira funcionalidade que expõem.

Para cada fase, registre também:
- **Fora desta fase:** o que ainda não funciona ao fim dela e como isso aparece para o usuário (ex.: botão oculto, mensagem "em breve").
- **Pode ser publicada sozinha?** sim / não. Se não, diga com qual fase ela precisa sair junto.

Status possíveis: a fazer | em andamento | concluída.

## 12. Checklist de aprovação

- [ ] Todo código citado existe na base funcional vigente
- [ ] Todo critério de aceitação é testável e cita sua origem
- [ ] Nenhuma premissa sem confirmação
- [ ] Nenhum esclarecimento em aberto
- [ ] Todo critério de aceitação está em exatamente uma fase
- [ ] Cada fase entrega algo testável sem depender das fases seguintes
- [ ] UX-spec vinculada, revisada e coerente com os critérios de aceitação — ou marcada como não aplicável com justificativa
- [ ] Responsabilidades mobile/backend e contratos compartilhados estão claros
- [ ] Nenhuma menção a tecnologia
