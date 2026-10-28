# Documentação do projeto — versão 1.40

**Projeto:** App de Organização Familiar — MVP  
**Versão:** 1.40\
**Data:** 2026-10-28\
**Situação:** base documental consolidada

[Projeto](../README.md) · [Visão do produto](00-visao-do-produto.md) · [Índice e versões](DOCUMENTACAO.md) · [Regras de negócio](01-regras-de-negocio.md) · [Requisitos](02-requisitos.md) · [Casos de uso](03-casos-de-uso.md) · [Diagramas UML](04-diagramas-de-caso-de-uso.md) · [Screen map](design/screen-map.md) · [Modelo de dados](05-modelo-de-dados.md) · [Diagrama de classes](06-diagrama-de-classes.md)

## Documentos

| Arquivo | Conteúdo |
| --- | --- |
| [Apresentação do projeto](../README.md) | Propósito, público, jornada e escopo do MVP. |
| [Visão do produto](00-visao-do-produto.md) | Contexto, objetivos, princípios, escopo e critérios de sucesso. |
| [Índice e versões](DOCUMENTACAO.md) | Organização documental, rastreabilidade e política de versões. |
| [Regras de negócio](01-regras-de-negocio.md) | Regras vigentes e suas relações com RF, RNF e UC; versão 1.26. |
| [Requisitos](02-requisitos.md) | 71 requisitos funcionais e 27 não funcionais, com vínculos às regras e aos casos de uso; versão 1.25. |
| [Especificação dos casos de uso](03-casos-de-uso.md) | 19 casos de uso completos, com atores, pré-condições, fluxos, alternativas e pós-condições; versão 1.25. |
| [Diagramas de caso de uso](04-diagramas-de-caso-de-uso.md) | Visão geral e cinco recortes UML, com fontes PlantUML e imagens SVG. |
| [Screen map](design/screen-map.md) | Mapa 1.23: TEL-032 compacta em Dia/Semana domingo–sábado; nome Kids editável também no detalhe; base RN 1.26 / RF 1.25 / UC 1.25. |
| [User flows](design/user-flows.md) | Fluxos 1.24: TEL-032 em Dia/Semana, gestão e nome Kids autorizado; base RN 1.26 / RF 1.25 / UC 1.25 e screen map 1.23. |
| [Modelo de dados (DER)](05-modelo-de-dados.md) | Modelo 1.10: parabéns persistido e fila de push por dispositivo; base RN 1.23 / RF 1.22 / UC 1.22. |
| [Diagrama de classes](06-diagrama-de-classes.md) | Modelo 1.9: rascunho de membros, resultado de criação, foto antecipada e item pessoal com estado efetivo/exibido; base RN 1.18 / RF 1.17 / UC 1.16. |
| [Arquitetura mobile](architecture/mobile-architecture.md) | Arquitetura 1.6: Swift + SwiftUI, View + ViewModel, integração do onboarding e projeção pessoal de tarefas. |
| [Catálogo mobile](architecture/mobile-feature-catalog.md) | Catálogo 1.13: TEL-032 Dia/Semana com gestão e nome Kids autorizado. |
| [Decisões da arquitetura mobile](architecture/mobile-decisions.md) | Versão 1.8: MA-01–MA-21 e P-01–P-09, incluindo TEL-032 Dia/Semana, totais de TEL-011, incentivos e mensagens internas. |
| [Convenções de código mobile](architecture/mobile-code-conventions.md) | Convenções 1.1 de Swift/SwiftUI, SF Symbols, camadas, concorrência, segurança, testes e revisão. |
| [Arquitetura backend](architecture/backend-architecture.md) | Backend 1.4: Node.js, Clean Architecture, monólito modular, Supabase/R2 e criação conjunta com foto antecipada. |
| [Contratos backend](architecture/backend-contracts.md) | Contratos 1.27 da API `/v1`: `completedAt` permanece disponível para acessibilidade em TEL-032; sem mudança de API. |
| [Decisões backend](architecture/backend-decisions.md) | BA-01–BA-38: escolhas confirmadas e propostas técnicas, incluindo outbox de parabéns e APNs. |
| [Convenções de código backend](architecture/backend-code-conventions.md) | Convenções de TypeScript/Fastify, camadas, contratos, SQL, segurança, testes e revisão. |
| [Specs de entrega](../specs/README.md) | Recortes aprovados de implementação compartilhados entre mobile e backend. |
| [Primeiro TestFlight](releases/testflight-1.md) | Recorte da distribuição Mutua, verificação e pendências operacionais. |

## Como usar

Mantenha o `README.md` na raiz e preserve a pasta `docs/`, incluindo `diagramas/casos-de-uso/` e `design/`. Os links são relativos e continuam funcionando quando a pasta é movida. Cada regra, requisito e caso de uso tem uma seção identificada por seu código. Em ambientes que não naveguem por links locais, o código permite localizar a referência no arquivo correspondente.

Esta é uma base completa e consolidada. Não é uma lista de correções e não depende do PDF original ou do documento intermediário de revisão para descrever o comportamento vigente. Os documentos anteriores servem apenas como referência histórica.

Os PDFs existentes em `output/pdf/` são exportações de versões anteriores. Nesta revisão, a fonte vigente é a documentação Markdown e seus diagramas atualizados.

Para implementar, comece pela spec aprovada em `../specs/`. Ela delimita a entrega e
aponta os códigos e documentos a consultar. Não use a documentação inteira como
contexto fixo: leia somente a fatia indicada pela rastreabilidade. As regras de uso por
agentes e a ordem das fontes de verdade estão em [`AGENTS.md`](../AGENTS.md).

## Organização dos arquivos

- `docs/`: visão, regras, requisitos, casos de uso, modelo de dados, diagrama de classes e índice documental.
- `docs/diagramas/casos-de-uso/`: fontes PlantUML e imagens dos diagramas de casos de uso.
- `docs/design/`: screen map e user flows, com referências à base funcional.
- `docs/architecture/`: arquiteturas mobile/backend, convenções de código, catálogos de funcionalidades/contratos e registros de decisões; fundação técnica e direcionamento para implementações incrementais.
- `../specs/`: specs aprovadas e o template para cada entrega vertical entre mobile e backend.
- `../mobile/` e `../backend/`: raízes reservadas para os projetos de implementação.

## Rastreabilidade

- **UC/RNF ↔ backend ↔ mobile:** os [contratos backend](architecture/backend-contracts.md#7-rastreabilidade-uc-para-backend) cobrem todos os objetivos e delimitam responsabilidades remotas/locais. Cada UC tem retorno para sua linha no catálogo backend.

- **UC/RNF ↔ arquitetura ↔ TEL/MOD/UF:** o [catálogo mobile](architecture/mobile-feature-catalog.md) relaciona os objetivos funcionais a funcionalidades, Views, ViewModels, casos de uso e portas. A [arquitetura](architecture/mobile-architecture.md) define a separação entre mobile e backend; o [registro de decisões](architecture/mobile-decisions.md) consolida as escolhas e os temas fora desta etapa.

- **UC ↔ tipos → DER:** o [diagrama de classes](06-diagrama-de-classes.md#rastreabilidade-por-caso-de-uso) relaciona os 19 casos de uso aos tipos do modelo, RF e RN, com RNF e correspondência ao modelo de dados. Cada UC possui link de retorno. Esses vínculos documentam responsabilidades, não implementação concluída.

- **Visão → RN/RF/UC:** as tabelas de regras centrais e de escopo conectam a proposta do produto aos comportamentos detalhados. Todos os documentos têm navegação para a visão e para a apresentação do projeto.
- **RN → RF/RNF → UC:** cada regra aponta para os requisitos relacionados e os fluxos associados.
- **RF → RN e UC:** cada requisito funcional aponta para suas regras e os casos de uso que o realizam.
- **RNF → RN e UC:** cada requisito não funcional aponta para as regras específicas, quando houver, e para os fluxos em que se aplica.
- **UC → RF, RN e RNF:** cada caso de uso reúne seus requisitos e regras para facilitar implementação e revisão.
- RF48 passa a seguir RN63, incluindo foto opcional e configuração de apelido exclusiva do titular para todos os perfis. Requisitos transversais de qualidade também podem não derivar de uma RN; isso está explicitado em suas seções.

As relações RN–UC são derivadas de RN–RF–UC. As relações de RNF representam aplicabilidade e não criam novos passos no fluxo. A ausência de RNF específico em uma regra não dispensa requisitos transversais de segurança, acessibilidade e confiabilidade.

## Decisões vigentes na versão 1.5

- A sessão usa refresh token sem expiração temporal, sujeito à revogação. Perda da sessão exige novo convite de um Administrador para recuperar o mesmo perfil ativo.
- Criador com família existente é redirecionado para ela; membro removido perde o acesso, inclusive por sessões existentes.
- Ingresso exige link e senha gerada pelo sistema, enviados juntos. A senha é usada somente para efetivar o vínculo, e o conjunto admite um ingresso bem-sucedido.
- Kids podem sinalizar a realização com foto opcional. A sinalização não produz conclusão parcial. Confirmação do Administrador ou conclusão manual por adulto conclui a tarefa para todos os responsáveis.
- Adultos podem concluir tarefa de outras pessoas mantendo os responsáveis ou assumindo-a, com aviso sobre o crédito. Assumir substitui todos os responsáveis pelo usuário que conclui.
- Cada responsável recebe o peso integral da tarefa compartilhada. A carga total soma as cargas individuais; o progresso de uma missão conta cada tarefa apenas uma vez.
- Todos os perfis visualizam o próprio progresso diário. Somente Administradores e Membros acessam consultas familiares por Início/Fim livres; a carga visual na Família ficou para entrega posterior.
- O carrossel vai da criação da família até o último dia do mês corrente, incluindo dias futuros dentro desse mês.
- Missões não têm prazo nem expiram. A missão permanece em andamento enquanto houver tarefas não concluídas.
- Administradores podem adicionar itens personalizados à roleta. A recompensa é vinculada à missão somente após sorteio e aceitação, com resgate único.
- Tarefas concluídas não podem ser excluídas diretamente. Administradores e Membros podem reabrir tarefa acessível; Kids podem reabrir tarefa própria. Quando houver missão concluída e/ou recompensa aceita, confirmar a reabertura e reverter os dados derivados.
- Reabrir retira a contribuição da conclusão anterior da carga e do progresso. A exclusão posterior não desconta o peso novamente.
- Missões concluídas preservam dados e vínculos contra edição/exclusão. A exceção é a reabertura confirmada de tarefa vinculada, que retorna a missão para Em andamento e remove recompensa, participações e badges derivados. A exclusão de tarefa não pode deixar uma missão sem tarefas.

A tela Família apresenta progresso do intervalo livre e por membro, lista de membros e entrada para Tarefas da família. O detalhe mostra hoje e preserva o intervalo da Família no retorno. Gerar relatório PDF fica em Tarefas da família; Administradores acessam Configurações (TEL-057) para inclusão/gestão e Confirmações Kids. A consulta é adulta; a gestão continua exclusiva dos Administradores. Crédito histórico removido aparece sem dado pessoal no relatório semanal. Referências: RN23/RN30–31/RN60–62, RF60–61/RF66, UC02/03/11/18.

## Decisões de produto consolidadas em 2026-10-05

- **Kids:** tab bar com duas abas independentes, “Minhas tarefas” e “Missões e conquistas”. Meu perfil abre pelo avatar/cabeçalho, sem terceira aba. Adicionar foto à sinalização abre diretamente a câmera, com foto ainda opcional.
- **Perfil:** foto opcional e etiqueta/apelido para todos, inclusive Kids. O apelido é visível à família, mas só o titular acessa sua configuração e edição. O perfil mostra os badges recebidos pelos marcos de 5, 10, 25 e 50 missões com participação.
- **Períodos:** progresso pessoal é diário. A Família, Tarefas da família e o detalhe do membro usam Início/Fim livres para adultos; Kids continuam sem acesso à distribuição de carga familiar. Progresso e carga usam métricas distintas, detalhadas em RN61.
- **PDF semanal:** adultos geram relatório de segunda a domingo com gráficos de carga e progresso total da família, peso creditado e número de tarefas realizadas por membro. O relatório identifica período e geração; a semana atual é parcial.
- **Destaque semanal:** na segunda-feira, apurar o primeiro lugar em pontos da semana encerrada, notificar a pessoa e mostrar o resultado no app. Pontos correspondem aos pesos creditados; todos os empatados em primeiro são reconhecidos. Compartilhar via WhatsApp é opcional e convida a sugerir uma atividade em família.

Referências: RN61–65; RF61–66; UC18–19; TEL-051/052; UF-14/15. RF48, RF55, RN34 e os fluxos existentes também foram revisados.

## Consolidação de 2026-10-05

As pendências P-01–P-09 estão resolvidas no [registro de decisões](architecture/mobile-decisions.md). A arquitetura mobile e a base funcional incorporam:

- iOS/iPadOS 26, Swift/SwiftUI, View + ViewModel e Clean Architecture; código e arquivos de código em inglês.
- Backend único, banco Supabase e fotos privadas no Cloudflare R2, com URL estável no banco. Mobile acessa o backend.
- Última edição válida persistida prevalece; falhas exigem consulta ao estado. Conclusões, convites e resgates mantêm garantias transacionais.
- Fuso escolhido na criação, padrão `America/Sao_Paulo`, alterável só por Admin, imediatamente ou no próximo ciclo. Destaque à meia-noite de segunda; resultado finalizado preservado.
- Datas de cadastro/edição livres, inclusive antes da família e em qualquer mês futuro; carrossel de consulta mantém seu intervalo próprio. Concluídas não protegidas admitem edição com ajuste de indicadores e auditoria.
- Badges cumulativos por participação em 5/10/25/50 missões, sem retroatividade a quem entrou depois. Destaque inclui perfis ativos Kids e exige pontos positivos.
- Convites sem expiração temporal, de uso único; reemissão gera novo link/senha e revoga credenciais/sessão anteriores. Um aparelho por perfil; confirmação de troca sem remoção automática da família anterior.
- Câmera/galeria no perfil para todos; câmera direta na sinalização Kids. PDF e sorteio no aplicativo, snapshot e aceite no servidor.
- Apenas desenvolvimento e produção; sem rotina própria de backup. Backend Node.js/Clean Architecture está definido; TypeScript/Fastify são propostas técnicas. Retenção das fotos vinculadas, volumes de teste, hospedagem e distribuição continuam fora desta etapa.

Novas superfícies: TEL-053 (Configurações da família), TEL-054 (Detalhe do badge), MOD-012 (aplicação do fuso), MOD-013 (troca de acesso) e UF-16 (configurar fuso). Novos requisitos: RF67 e RF68; os 19 UC foram preservados.

## Revisão da navegação da Família

A tela Família apresenta progresso por Início/Fim livres, membros e entrada para tarefas. Selecionar uma pessoa abre o detalhe com progresso e tarefas de hoje; o intervalo da Família é restaurado ao voltar. Edição, remoção e convite ficam no menu do detalhe quando permitidos. Administradores incluem membros em Configurações da família (TEL-057) e abrem Confirmações Kids. Gerar relatório PDF fica em Tarefas da família (TEL-011) e solicita semana em TEL-051 quando o intervalo tocar mais de uma.

TEL-014 e TEL-031 permanecem reservadas e fora da navegação; a carga visual fica para entrega posterior, e a lista administrativa está em TEL-057. TEL-032 é consultável por Administradores e Membros, com ações de gestão restritas. Os períodos familiares aceitam qualquer intervalo válido entre Início e Fim, sem modo mensal.

## Convenções

- RN = regra de negócio; RF = requisito funcional; RNF = requisito não funcional; UC = caso de uso.
- “Adulto”, nos fluxos, designa os perfis Administrador e Membro, sem criar um novo perfil.
- “Responsáveis finais” são os responsáveis creditados na conclusão válida, após eventual substituição ou correção autorizada. O evento original permanece na auditoria; o usuário que executa a ação pode ser outra pessoa.
- “Pendente”, “Aguardando confirmação” e “Concluída” são estados de tarefa. Missões ficam em andamento ou concluídas, sem estado de expiração temporal.
- A numeração foi preservada. RN15, RN29 e RN32 não estavam definidos e não são reutilizados nesta versão.
- Código futuro, nomes de arquivos de código, tipos, membros, testes e recursos usam inglês. A documentação explicativa permanece em português e os textos de UI ficam em recursos localizáveis.

## Política de versionamento

1. A base funcional vigente está na versão **1.26** (regras 1.26, requisitos 1.25 e casos de uso 1.25). O índice documental está na versão **1.38** por consolidar também registros técnicos e de apresentação. Screen map e user flows têm versionamento independente; as arquiteturas mobile e backend também. Documentos alinhados a uma versão funcional anterior devem ser atualizados quando o comportamento que descrevem for afetado.
2. Preserve os identificadores RN, RF, RNF, UC, TEL, MOD e UF. Novos itens recebem novos códigos; códigos retirados não são reutilizados.
3. A edição vigente fica na raiz e em `docs/`. O Git mantém o histórico e permite comparar ou recuperar versões anteriores por commits e, quando adotadas, tags. Não mantenha cópias da documentação em pastas de versões.
4. Alterações funcionais e suas referências devem evoluir juntas, com versão, data e histórico dos códigos e comportamentos afetados. Use 1.1, 1.2... para revisões incrementais e 2.0 para mudanças substanciais da base funcional.
5. Preserve os IDs para design e user flows e registre as alterações no Git. Revisões do screen map e dos user flows são versionadas em conjunto. Se alterarem comportamento, atualize e versione a base funcional correspondente; a versão de design é independente.
6. As arquiteturas em `docs/architecture/` têm versionamento independente da base funcional. A Sprint 0 implementa somente a fundação técnica de mobile, backend, migrations e CI; árvores e exemplos de funcionalidades continuam sendo direcionamento para entregas futuras. Decisões técnicas não alteram requisitos implicitamente; mudanças funcionais exigem revisão da base e das referências afetadas.

A fundação backend adota Node.js, TypeScript, Fastify e `pg`. Parte da API de produto já foi implementada; os contratos alvo desta revisão ainda exigem código e migração antes de aparecerem na OpenAPI executável.

## Histórico de versões

| Versão | Data | Alteração |
| --- | --- | --- |
| 1.40 | 2026-10-28 | TestFlight Mutua recorta apenas a interface mobile; API de produção e contrato `/v1` seguem compartilhados com `develop`, sem canal ou bloqueio de rotas para a release. |
| 1.39 | 2026-10-28 | Plano de distribuição Mutua no TestFlight: recorte inicial sem Kids, missões, recompensas coletivas, badges ou PDF; base funcional do produto completo preservada. |
| 1.38 | 2026-10-28 | TEL-032 retorna à variante compacta Dia/Semana domingo–sábado; Parabenizar fica na Família, edição de nome Kids é possível no detalhe para Admin, e folhas de filtros TEL-050/TEL-011 são distintas. RN/RF/UC, SPEC/UX-003/009, mapa 1.23, fluxos 1.24 e catálogo 1.13 alinhados. |
| 1.37 | 2026-10-28 | UX-009 e convenções mobile 1.1 padronizam SF Symbols para ícones de interface; removem SVGs de ícones da Família e da entrada por convite. |
| 1.36 | 2026-10-28 | RN07/RN63, RF03/RF60, UC02/UC10, SPEC/UX-003, mapa 1.22, fluxos 1.23 e contrato 1.26: adulto edita próprio nome, Admin corrige nome Kids em TEL-057; TEL-032 mantém papel, convite e remoção. |
| 1.35 | 2026-10-28 | TEL-032 aprovada na variante diária com horário da conclusão: RN60–61, RF60/RF66, UC11, SPEC/UX-009, contrato 1.25, mapa 1.21 e fluxos 1.22 alinhados. |
| 1.34 | 2026-10-28 | TEL-011 alinhada ao protótipo aprovado, com filtros, grupos e PDF; mapa 1.20 e fluxos 1.21. |
| 1.33 | 2026-10-28 | TEL-050 distingue o próprio usuário no destaque de maior quantidade com cartão compacto; SPEC/UX-009 e screen map 1.19 atualizados sem mudar regras funcionais. |
| 1.32 | 2026-10-27 | RN60/RF60/UC11 e SPEC/UX-009 incluem incentivos, parabéns repetível, mensagem interna e push; screen map 1.18, fluxos 1.20 e contratos backend 1.24. |
| 1.31 | 2026-10-27 | RN23/RN60–62, RF60–61/RF66 e UC11/18 alinhados à seção Família aprovada do Figma: Início/Fim livres, TEL-032 herda intervalo, estado Kids projetado para Membro, PDF em TEL-011 com seleção de semana e carga visual adiada. Screen map 1.17, fluxos 1.19, SPEC/UX-009/018/019 e contratos 1.23. |
| 1.30 | 2026-10-27 | RN17/RF13/UC08, SPEC-008 E-14 e contratos backend 1.22: a edição “selecionada e futuras” preserva a data prevista já gravada, inclusive após edição individual; substitui apenas os campos permitidos. Para SCRUM-45. |
| 1.29 | 2026-10-27 | RN17/RF13/UC08: editar ou excluir ocorrência de rotina sempre pergunta o alcance; “esta e as futuras” altera somente título, peso, responsáveis e observação, sem mudar repetição ou data prevista, e substitui edições individuais anteriores das futuras. RN66/UC07: a escolha entre Pendente e Aguardando confirmação vale para a edição individual; a edição de rotina não altera estados. Contratos backend 1.21, SPEC-008 (E-05 a E-13), UX-008 e UX-007 (anatomia da TEL-013/MOD-001) alinhados. |
| 1.28 | 2026-10-26 | TEL-010 adulta alinhada ao protótipo de média fidelidade; UX-009, screen map 1.16 e user flows 1.18 registram rótulos, carrossel visual, cartões e acessibilidade sem alterar a base funcional. |
| 1.27 | 2026-10-26 | TEL-010/TEL-040 atualizam estado e progresso ao toque; UF-06/UF-08 e UX-009/010/011 registram última intenção, comandos sequenciais e reconciliação de falhas. |
| 1.26 | 2026-10-26 | UC12/UC17, TEL-010/TEL-040 e UF-06/UF-08 registram o círculo da lista pessoal como ação de concluir/reabrir; UX-009, SPEC/UX-010/011 e testes mobile alinhados. |
| 1.25 | 2026-10-21 | Contratos backend 1.19 registram o endereço Cloudflare de Universal Links, AASA e fallback do convite, sem alteração funcional. |
| 1.24 | 2026-10-21 | Contratos backend 1.18 e OpenAPI refletem perfil próprio (`nickname`/foto) e consulta de badges implementados na SPEC-006 Fase 1 (SCRUM-51). SPEC-006 CA-06/§5.3 corrigidos de `400` para `422` em `NICKNAME_INVALID_LENGTH` (E-03), por consistência com o restante do contrato. |
| 1.23 | 2026-10-19 | Contratos backend 1.17 e OpenAPI refletem `displayStatus` pessoal implementado na SPEC-009 Fase 1 (SCRUM-107). |
| 1.22 | 2026-10-19 | Revisão dos pares SPEC/UX-002, 003, 004 e 009 concluída e aprovada; dependências e índice de entregas atualizados. README alinhado à criação conjunta dos membros com a família. |
| 1.21 | 2026-10-19 | DER e diagrama de classes 1.9 alinhados à foto anterior à família, criação conjunta de membros, retorno sem recriação e estado pessoal apenas projetado. |
| 1.20 | 2026-10-19 | Contratos backend 1.16, decisões BA-35–BA-37/MA-18–MA-19, arquiteturas e catálogo mobile alinhados a onboarding, convites e projeção pessoal; SPEC-002/009 reconciliadas tecnicamente. |
| 1.19 | 2026-10-19 | RN38/RF59/UC07: exclusão que deixa a missão apenas com tarefas concluídas a conclui na mesma transação (SPEC-014/SPEC-007). Regras 1.18, requisitos 1.17 e casos de uso 1.16 também alinhados a onboarding, convites e estado pessoal; screen map 1.14 e user flows 1.15 atualizados. SPEC/UX-002, 003, 004 e 009 em revisão nessa etapa. |
| 1.18 | 2026-10-10 | Consolidação da documentação das SPECs 015–020 com a implementação de acesso, família, convites, tarefas e sessão do `develop`; índices e versões técnicas reconciliados. |
| 1.17 | 2026-10-10 | RN62/UC18 definem `referenceDate` para o PDF e identificam crédito histórico como “Membro removido”; contrato do snapshot detalhado. Para SPEC-019. |
| 1.16 | 2026-10-10 | Carga histórica de perfil removido é preservada como “Membro removido”; TEL-050/UF-09 e contrato de `GET /family/load` detalhados para SPEC-018. |
| 1.15 | 2026-10-10 | RN42/RF34/UC06 definem catálogo inicial, título personalizado único por família e descrição opcional; modelo, classes, design e contratos atualizados. Para SPEC-015. |
| 1.14 | 2026-10-07 | Onboarding inicial revisado: perfil do Criador antes da família, membros opcionais e convite explícito antes da área principal. RN01/RN07/RN09/RN44/RN63; RF01/RF02/RF38/RF41/RF48; UC01/UC02/UC04; visão, screen map e user flows 1.8. |
| 1.13 | 2026-10-07 | RN63/RF48 passam a definir o limite do apelido: até 20 caracteres não-espaço após trim, sem caracteres de controle; vazio/nulo remove a configuração. Para SPEC-006. |
| 1.12 | 2026-10-07 | RN68/RF71 definem observação opcional (até 250 caracteres) na missão; UC05 passa a cobrir o atalho de criação de tarefa durante a vinculação e a consulta explícita por todos os perfis, inclusive Kids; modelo de dados e diagrama de classes atualizados. Para SPEC-014. |
| 1.11 | 2026-10-07 | Conclusão direta mantém responsáveis ou atribui adulto sem responsável; reabertura pode reabrir missão concluída e recalcula recompensa, participações e badges. |
| 1.10 | 2026-10-06 | Tarefas com responsável Kids só recebem conclusão manual de Administrador; evidência pendente é auditável só por Admin e concorrência reconcilia sem erro na UI. Para SPEC-010. |
| 1.9 | 2026-10-06 | Consulta pessoal diária para todos os perfis; consultas familiares adultas de tarefas e progresso por Dia/Semana; contrato de filtros familiares e carga adiada para SPEC-018. Para SPEC-009. |
| 1.8 | 2026-10-06 | Rotinas passam a transportar observação opcional (até 250 caracteres); edição no alcance “selecionada e futuras” inclui a ocorrência de origem; são definidos códigos estáveis para validação de início, frequência e ocorrência de origem. Para SPEC-008. |
| 1.7 | 2026-10-06 | RF02, RF03 e RF40 passam a definir o nome administrativo de membro e os papéis permitidos na criação, para elaboração de SPEC-003. Tarefa (UC07) ganha limite de título (1–60 caracteres), observação opcional (até 250 caracteres) e regra de resolução de sinalização Kids pendente ao editar/excluir (RN66/67, RF69/70); screen map 1.2, user flows 1.2, catálogo mobile 1.3, contratos backend 1.2, DER 1.3. Para SPEC-007. |
| 1.6 | 2026-10-06 | RF01 passa a definir o nome obrigatório da família (1–60 caracteres Unicode visíveis após trim, sem caracteres de controle), para aprovação de SPEC-002. |
| 1.5 | 2026-10-05 | Pendências consolidadas: fuso, datas livres, edição de concluídas, participações/badges, convites e sessão única; RF67/68; arquitetura, modelo e design 1.1. |
| 1.4    | 2026-10-02 | Família concentra indicadores, lista, inclusão de membros e PDF; detalhe do membro reúne tarefas Dia/Semana, edição e reenvio quando permitidos. RN60–61, RF60–61/RF66 e UC02/11/13/18 revisados.                 |
| 1.3    | 2026-10-02 | Duas abas Kids, câmera direta, foto/apelido e badges, progresso/carga Dia/Semana, PDF semanal e reconhecimento com WhatsApp; RN61–65, RF61–66, RNF26–27 e UC18–19. Empates e visibilidade do apelido confirmados. |
| 1.2    | 2026-10-01 | Área Família na navegação adulta, progresso coletivo diário e consulta por carrossel: RN60, RF60 e UC11. Design em elaboração na versão 1.0.                                                                      |
| 1.1    | 2026-10-01 | Recuperação do mesmo perfil por novo convite e renovação sem expiração temporal, com revogação preservada: RN47, RF41, RF46, RF54, RNF22, UC02 e UC09.                                                            |
| 1.0 | 2026-10-01 | Primeira versão consolidada, incluindo a visão alinhada ao MVP, a apresentação global do projeto e todas as decisões registradas até esta publicação. |

Complemento visual de 2026-10-01: adicionados cinco diagramas de UC01–UC17 e referências de navegação; mantida a base funcional 1.0.

Complemento de design de 2026-10-01: adicionados user flows 1.0 para revisão, referenciando a base funcional estável 1.2 e o screen map estável 1.0, sem alteração de comportamento.

Complemento de modelagem de 2026-10-05: primeira versão (1.0) do diagrama de classes, alinhada à base funcional 1.4, com contratos, diagramas por domínio, rastreabilidade bidirecional e correspondência ao DER. Mantidas as premissas e definições pendentes da base funcional.

Complemento de arquitetura de 2026-10-05: proposta mobile 1.0 em Swift/SwiftUI com View + ViewModel e Clean Architecture, catálogo completo de apresentação e casos de uso, decisões e pendências. Base funcional preservada em 1.4; nenhuma implementação adicionada.

Complemento de backend de 2026-10-05: arquitetura backend 1.0, contratos e decisões BA-01–BA-20; mobile/modelos 1.2 alinhados, design 1.1 e base funcional 1.5 preservados.
