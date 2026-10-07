---
name: desenvolver-card-ux
description: Cria no Figma os protótipos de média fidelidade de um card de Jira Mobile já planejado, com telas, modais, variantes e estados rastreáveis. Use quando o pedido for desenhar ou prototipar a experiência de um card para iPhone e iPad; não use para criar SPECs, implementar SwiftUI ou produzir alta fidelidade.
---

# Desenvolver card UX

Use esta skill para transformar um card Mobile já planejado em protótipos de média fidelidade editáveis no arquivo Figma do produto. A entrega torna o comportamento do card verificável para a implementação, mas não cria regras de produto nem substitui a UX-spec.

## Entrada e limites

- Receba uma chave/link do card, a SPEC e a UX-spec vinculadas, ou uma indicação inequívoca do recorte já planejado. O card deve informar a fase e os critérios de aceite de UX que serão cobertos.
- Trabalhe somente nas telas e modais do card. Não redesenhe fluxos adjacentes, não avance critérios de outra fase e não altere Jira, documentação ou status do card, a menos que o usuário peça expressamente.
- É obrigatório haver um arquivo Figma de destino acessível. Se o card, a SPEC/UX-spec ou o arquivo Figma não puderem ser identificados, peça o dado ausente antes de modificar o Figma.
- Esta skill é para média fidelidade: hierarquia, conteúdo, navegação, componentes, feedback e estados devem estar claros; acabamento visual e alta fidelidade ficam para o card próprio posterior.

## Base documental e prontidão

Antes de desenhar:

1. Leia `AGENTS.md`, `README.md`, `docs/DOCUMENTACAO.md` e `specs/README.md`.
2. Localize a SPEC e a UX-spec correspondentes. Confirme que ambas estão aprovadas e identifique o card, fase e critérios de aceite no seu escopo.
3. Leia somente os documentos e trechos citados em **Rastreabilidade** da SPEC, além de `docs/design/screen-map.md`, `docs/design/user-flows.md` e a arquitetura mobile quando forem aplicáveis ao recorte. Busque cada código `RN`, `RF`, `RNF`, `UC`, `TEL`, `MOD`, `UF` ou `MA` antes de afirmar uma regra, estado ou permissão.
4. Extraia uma matriz de cobertura: superfície (`TEL`/`MOD`), perfil autorizado, objetivo, gatilhos, entradas, saídas, estados documentados e critério(s) de aceite. Ela orienta o protótipo e deve ser resumida na entrega.

Não use o design para resolver lacunas funcionais. Quando idade, nível de leitura, permissão, regra, transição, estado ou consequência não estiver definido, sinalize a **Lacuna** no chat, explique o impacto e indique os documentos funcionais e artefatos que precisam mudar após a decisão. Não coloque essa comunicação no Figma nem presuma idade, composição familiar, gênero ou papéis tradicionais.

## Critério de UX para o recorte

Atue como designer de UI/UX sênior de produtos Apple, comportamento e gamificação saudável. Faça recomendações diretas, viáveis para uma implementação individual em Swift 6/SwiftUI para iOS/iPadOS 26 ou superior.

- Priorize Human Interface Guidelines, padrões nativos e componentes que tenham correspondência clara em SwiftUI. Não desenhe controles ou interações que exijam comportamento customizado sem necessidade documentada.
- Preserve colaboração e equilíbrio: não introduza rankings completos, streaks, FOMO, loot boxes, culpa ou punição por atraso. O reconhecimento semanal existente só pode ser alterado quando a documentação funcional também mudar.
- Faça a ação adulta frequente rápida e a interação Kids clara e encorajadora. O Modo Kids mantém suas duas abas documentadas; o perfil não vira uma terceira aba.
- Respeite rigorosamente permissões, isolamento da família, fotos privadas e compartilhamento somente mediante ação explícita. Não represente como funcionalidade aprovada algo que seja apenas recomendação de LGPD, COPPA/GDPR-K, Tempo de Uso ou controle parental.
- Inclua nos frames os elementos necessários para Dynamic Type, VoiceOver, alto contraste, Reduzir Movimento, alvos de toque adequados e comunicação que não dependa só de cor. Se alguma medida ainda não estiver na documentação, trate-a como melhoria a formalizar, não como comportamento aprovado.

## Organização obrigatória no Figma

Use o conector, plugin ou MCP de Figma disponível no ambiente. Antes da primeira alteração, leia as instruções do recurso de Figma; quando houver as skills `figma-use` e `figma-generate-design`, aplique ambas antes de chamar `use_figma`. Inspecione primeiro o arquivo para reutilizar componentes, estilos, variáveis e padrões existentes. Todo resultado precisa ser composto de camadas editáveis (texto, componentes, ícones e frames), nunca uma captura achatada da interface. Se o ambiente não oferecer uma integração Figma capaz de editar o arquivo, não simule a atualização com captura ou artefato achatado: informe a limitação.

1. Localize a página com o nome exato **`PROTOTIPOS MEDIA`**; se não existir, crie-a no arquivo de destino. Não crie outra página para o mesmo propósito.
2. Crie ou atualize uma única **Section** por superfície do card, nomeada `TEL-XXX — nome` ou `MOD-XXX — nome`. Uma Section reúne tudo que pertence àquela tela ou modal; não crie uma Section por estado ou por dispositivo.
3. Dentro de cada Section, inclua frames nomeados de forma verificável: `iPhone · Perfil · Estado` e, quando aplicável, `iPad · Perfil · Estado`. Exemplo: `iPhone · Kids · Aguardando confirmação`. Use o perfil real (`Administrador`, `Membro`, `Kids`) e o estado real, nunca rótulos genéricos se a documentação for específica.
4. Mantenha no canto superior da Section uma legenda curta com o identificador, a SPEC/UX-spec, critérios de aceite cobertos e referências relevantes, além da tag visível `Status do protótipo: Aguardando aprovação` ou `Status do protótipo: Aprovado`. Essa tag é de revisão do protótipo e não substitui estados da interface, do domínio ou do card.
5. Toda Section nova ou alterada deve receber `Status do protótipo: Aguardando aprovação`, mesmo que estivesse aprovada antes. Altere a tag para `Status do protótipo: Aprovado` somente após aprovação explícita do usuário para aquela Section; aprovação do escopo, de uma prévia ou de outra Section não basta.
6. Não represente no Figma pendências, dúvidas ou decisões tomadas no chat como legendas, anotações ou variantes. Se a superfície já existir, atualize o conjunto de variantes dentro da mesma Section e preserve variantes válidas fora do recorte. Não duplique telas apenas para representar a mesma variante.

## Variantes e estados mínimos

Modele somente estados que sejam aplicáveis ao card e estejam definidos na fonte rastreável. Para cada superfície, cubra conforme aplicável:

- perfis e permissões que realmente veem ou acionam a superfície;
- iPhone e iPad, com adaptação de composição, largura, navegação e densidade — não apenas ampliação da tela de iPhone;
- conteúdo carregado ou sucesso, inclusive o retorno após uma ação confirmada;
- carregamento/preparação e indisponibilidade transitória, sem prometer percentuais falsos;
- vazio, quando o produto permitir ausência de dados;
- validação de formulário e ação indisponível, com mensagem recuperável e foco compreensível;
- falha recuperável, resposta incerta/conflito ou permissão negada, quando a SPEC, UX-spec ou contrato os definirem;
- confirmação, cancelamento e consequente estado persistido, quando houver ação destrutiva, irreversível ou alteração relevante;
- estado específico de domínio, como pendente de confirmação, concluída, transição ou alteração programada, quando citado na documentação.

Não inclua todos esses estados por fórmula. Estados inexistentes, redundantes ou sem base documental devem ficar fora e, se a ausência impedir a compreensão da experiência, virar Lacuna.

## Construção e verificação

- Antes da primeira mutação, confirme em uma prévia curta as superfícies, variantes, estados, perfis, dispositivos, critérios cobertos e eventuais lacunas. Aguarde aprovação explícita se a solução envolver decisão nova de produto, fluxo, permissão ou comportamento; com escopo já definido, prossiga para construir o protótipo. Essa autorização para construir não aprova o conteúdo da Section: ela continua `Aguardando aprovação` até a aprovação explícita posterior.
- Use microcopy em português do Brasil, clara, concreta e compatível com o espaço e o nível de leitura; os textos são demonstrativos e deverão ser localizáveis no app.
- Descreva e represente microinterações apenas quando puderem ser implementadas com SwiftUI e forem necessárias para entender transição, feedback, foco, erro ou êxito. Respeite Reduzir Movimento.
- Após editar, faça inspeção estrutural e visual pelo plugin. Verifique que cada frame é editável, tem nome, está na Section correta, contém a variante esperada e não sofre corte, sobreposição ou baixa legibilidade em iPhone e iPad.

## Entrega

Ao terminar, informe na resposta de chat, em português do Brasil:

1. o arquivo e a página `PROTOTIPOS MEDIA` atualizados;
2. as Sections, variantes de perfil/dispositivo e estados criados ou atualizados, com o status de aprovação de cada Section;
3. card, SPEC/UX-spec, referências e critérios de aceite cobertos;
4. uma seção **Alinhamento documental** para cada decisão relevante: **Alinhado**, **Conflito** ou **Lacuna**, com os códigos de referência;
5. lacunas, riscos de acessibilidade ou decisões pendentes que bloqueiem a consolidação, indicando os documentos funcionais e artefatos de design que precisariam ser atualizados.

Não declare uma Section aprovada nem o card pronto para implementação se faltar protótipo de média fidelidade de uma superfície Mobile exigida pela fase, se houver uma lacuna decisória que altere o comportamento, se a validação no Figma não tiver sido possível ou se a aprovação explícita das Sections necessárias ainda não tiver sido dada.
