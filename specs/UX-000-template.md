# UX Spec NNN: [Nome curto da funcionalidade]

**Status:** rascunho | em esclarecimento | aprovada | em implementação | implementada
**Autor:** | **Criada em:** AAAA-MM-DD | **Aprovada por:** | **Em:**
**Spec funcional relacionada:** [SPEC-NNN-nome-curto.md]
**Base funcional:** [versão vigente da documentação]
**Referências de UX:** TEL-.., MOD-.., UF-..

<!--
COMO PREENCHER
- A UX-spec descreve COMO a pessoa percebe e opera o comportamento já definido.
- Não invente permissões, estados de domínio, validações ou regras: cite a spec funcional
  e os códigos RN/RF/UC correspondentes.
- Não descreva implementação (SwiftUI, componentes, API, banco ou classes).
- Uma UX-spec normalmente acompanha uma SPEC com o mesmo número e nome curto.
- A spec funcional prevalece em comportamento; esta UX-spec prevalece em apresentação.
  Qualquer divergência é uma pendência a resolver, não uma decisão implícita.
-->

## 1. Objetivo da experiência

Descreva em uma ou duas frases o que a pessoa precisa conseguir entender ou fazer e em
qual contexto.

## 2. Rastreabilidade

| Tipo | Referências |
|---|---|
| Spec funcional | SPEC-.. |
| Casos de uso / regras / requisitos | UC.., RN.., RF.., RNF.. |
| Telas, modais e fluxos existentes | TEL-.., MOD-.., UF-.. |
| Perfis | Administrador, Membro, Kids |

**Documentos consultados:** [links para screen map, user flows e outras referências]

## 3. Escopo da experiência

**Dentro:** superfícies, jornadas e estados que esta UX-spec detalha.

**Fora:** o que é resolvido por outra UX-spec, por uma spec funcional ou por um fluxo
já existente.

## 4. Entrada, navegação e retorno

| Entrada / origem | Ação ou condição | Destino | Volta / cancelar |
|---|---|---|---|
| TEL-.. | | TEL-.. ou MOD-.. | |

Explique somente navegação e preservação de contexto relevantes: data, período,
filtros, rascunho ou tela de origem.

## 5. Superfícies e conteúdo

Para cada tela, modal ou estado novo/alterado, descreva o que a pessoa vê e as ações
disponíveis. Cite os identificadores estáveis existentes; se for necessário criar um,
registre a decisão na seção 10 antes de adotá-lo.

### TEL-.. — [Nome]

- **Objetivo da superfície:**
- **Informação principal e hierarquia:**
- **Ações disponíveis por perfil:**
- **Ações indisponíveis ou ocultas:**
- **Resultado visível após uma ação:**

## 6. Estados de interface e feedback

Inclua somente estados aplicáveis. Falha, vazio e carregamento não são telas novas;
pertencem à superfície que os apresenta.

| Superfície | Condição | O que a pessoa vê | Ação possível | Referência funcional |
|---|---|---|---|---|
| TEL-.. | Carregando | | | |
| TEL-.. | Sem dados | | | |
| TEL-.. | Falha de consulta/gravação | | | |
| TEL-.. | Processando / resultado confirmado | | | |
| TEL-.. | Permissão ou estado mudou | | | |

## 7. Interações e microcopy

| Elemento ou ação | Rótulo / texto proposto | Confirmação, ajuda ou erro | Referência |
|---|---|---|---|
| | | | CA-.., RN.. |

Textos são propostos para recursos localizáveis. Mantenha linguagem simples; não
prometa sucesso antes de a operação estar confirmada e não exponha dados de outra
família ou informações sensíveis.

## 8. Acessibilidade e adaptação

- **Leitura e linguagem:**
- **Tecnologias assistivas / rótulos:**
- **Cor, contraste e outros sinais:**
- **Tamanho de texto e layout adaptativo:**
- **Caminho equivalente sem câmera, mídia ou compartilhamento externo, se aplicável:**

## 9. Referências visuais

Links para wireframes, protótipos, imagens, design system ou exemplos. Eles ilustram a
experiência; esta UX-spec preserva a descrição textual que permite implementá-la e
revisá-la sem depender do link.

## 10. Decisões e esclarecimentos de UX

| # | Questão | Decisão | Quem decidiu / data | Altera spec funcional ou docs/? |
|---|---|---|---|---|
| UX-01 | | | | |

Se a resposta alterar comportamento, permissões ou estado de domínio, atualize a spec
funcional e, quando necessário, a base em `docs/` antes da aprovação.

## 11. Checklist de aprovação

- [ ] Está vinculada a uma spec funcional e à versão vigente da base
- [ ] Cada superfície usa TEL/MOD existente ou tem decisão registrada
- [ ] Entradas, saídas, cancelamento e preservação de contexto estão claros
- [ ] Estados de carregamento, vazio, falha e processamento aplicáveis foram descritos
- [ ] Textos não prometem uma gravação antes de sua confirmação
- [ ] Perfis sem permissão não recebem caminho visual para concluir a ação
- [ ] Acessibilidade e layout adaptativo foram considerados
- [ ] Nenhuma regra de negócio ou tecnologia foi inventada nesta UX-spec
