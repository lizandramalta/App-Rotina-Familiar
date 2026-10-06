# App de Organização Familiar

Organização colaborativa das responsabilidades domésticas, com tarefas compartilhadas, participação infantil e conquistas coletivas.

**Escopo:** MVP  
**Versão da base do projeto:** 1.8\
**Data:** 2026-10-06

## Por que este projeto existe

Em muitas famílias, uma pessoa concentra o trabalho de lembrar, distribuir e acompanhar as tarefas da casa. Mesmo quando a execução é dividida, a gestão pode continuar centralizada.

O projeto busca ajudar a família a compartilhar essas responsabilidades, ampliar a participação e perceber concentrações na rotina. O resultado esperado é reduzir a sensação de sobrecarga e a necessidade de uma única pessoa cobrar os demais.

## Para quem

Famílias que compartilham a rotina doméstica e desejam organizar melhor suas responsabilidades, com participação de adultos e crianças.

## Como funciona

1. O Criador entra com Apple e cria a família ou acessa a que já está vinculada a ele.
2. Um Administrador cria os perfis e compartilha convites com link e senha para um único ingresso. Depois, a sessão válida permite continuar acessando o aplicativo.
3. Administradores e Membros criam tarefas únicas ou rotinas, definem o esforço e escolhem nenhum, um ou vários responsáveis.
4. Todos acompanham suas tarefas e seu progresso diário ou semanal. Kids sinalizam a realização com foto opcional; um Administrador confirma ou recusa, ou um adulto conclui manualmente.
5. A conclusão vale para todos os responsáveis finais. Adultos acompanham a distribuição da carga diária ou semanal, sem ranking.
6. A família realiza missões coletivas sem prazo. Ao concluir todas as tarefas vinculadas, registra participações e concede badges nos marcos atingidos e um Administrador pode sortear e aceitar uma recompensa coletiva.

## O que o MVP oferece

- Família com Administradores, Membros e Kids, convites e controle de acesso.
- Tarefas com peso de 1 a 3 e responsáveis opcionais ou compartilhados.
- Rotinas diárias ou a cada 7, 14, 21 ou 28 dias, com tarefas individuais independentes.
- Conclusão de tarefas de outros membros, mantendo os responsáveis ou assumindo a tarefa com aviso sobre o crédito.
- Checklist da criação da família até o último dia do mês corrente e progresso diário ou semanal para todos.
- Modo Kids com sinalização, foto opcional e avaliação pelo Administrador.
- Carga por dia ou semana para adultos; a semana vai de segunda-feira a domingo.
- Missões coletivas sem prazo, badges por marcos de participação e conquistas preservadas.
- Roleta com itens predefinidos e personalizados por Administradores, com um resgate aceito por missão.
- Foto opcional, apelido próprio e badges por participação no perfil de adultos e Kids.
- Relatório semanal em PDF com gráficos e indicadores da família.
- Reconhecimento semanal por pontos, com notificação e compartilhamento opcional pelo WhatsApp.
- Reabertura de tarefas pelo Administrador nas condições previstas.

## Quem pode fazer o quê

| Perfil | Papel principal |
|---|---|
| Administrador | Gerencia membros, missões e recompensas; valida sinalizações Kids e também gerencia e conclui tarefas. |
| Membro | Gerencia e conclui tarefas, acompanha carga diária ou semanal e missões e edita os dados permitidos de seu perfil. |
| Kids | Consulta tarefas e progresso, sinaliza com câmera opcional, edita foto/apelido próprios, consulta badges e recebe seu destaque semanal. |

O Criador da Família é um Administrador com identificação especial e proteção contra remoção, rebaixamento e saída. Podem existir outros Administradores, que ingressam por convite.

## Princípios do produto

**Colaboração e equilíbrio.** A experiência ajuda a compartilhar a gestão da rotina, com reconhecimento semanal do primeiro lugar em pontos e sem competição entre famílias.

**Participação compreensível.** A tarefa tem um único estado. Cada responsável recebe o peso integral quando ela é concluída. A carga indica participação creditada, não uma medição exata do tempo ou de toda a sobrecarga doméstica.

**Autonomia com permissões claras.** Adultos gerenciam tarefas; somente Administradores gerenciam membros, missões e recompensas. Kids têm uma experiência simplificada e não acessam a carga diária ou semanal.

**Conquistas preservadas.** Missões concluídas mantêm seus dados. Tarefas concluídas não podem ser excluídas diretamente. A reabertura exige Administrador, vínculo com missão em andamento e ausência de vínculo com qualquer missão concluída.

## Como avaliar o sucesso

O MVP deve ajudar os membros a entender suas responsabilidades, participar da organização da rotina e conversar sobre a distribuição das tarefas. A principal evidência esperada é a redução percebida da centralização e da necessidade de uma pessoa lembrar e cobrar os demais.

Missões e recompensas devem aumentar a participação sem gerar competição. O Modo Kids deve permitir que crianças participem de forma simples. Esses são objetivos de validação, não resultados já comprovados.

## Limites desta versão

Não estão incluídos calendário compartilhado, widgets, lista de compras, disponibilidade por membro, negociação de troca de tarefas, pedidos de ajuda, redistribuição automática, inteligência artificial ou permissões personalizadas.

O produto não prevê recorrência mensal, missões com prazo, conclusão parcial por responsável, rankings completos, streaks, controle de tempo de tela, mascote virtual ou recursos de localização. Tarefas com vários responsáveis e a opção de assumir ao concluir já estão no MVP.

As possibilidades de evolução estão no [documento de visão](docs/00-visao-do-produto.md), sem compromisso de implementação nesta versão.

## Conheça o projeto em detalhe

| Documento | O que você encontra |
|---|---|
| [Visão do produto](docs/00-visao-do-produto.md) | Problema, público, objetivos, jornada, escopo e critérios de sucesso. |
| [Regras de negócio](docs/01-regras-de-negocio.md) | As condições que regem a experiência e suas exceções. |
| [Requisitos funcionais e não funcionais](docs/02-requisitos.md) | Comportamentos esperados, qualidade, segurança e integridade. |
| [Casos de uso](docs/03-casos-de-uso.md) | Os 19 casos de uso, com atores, pré-condições, alternativas e resultados. |
| [Diagramas de caso de uso](docs/04-diagramas-de-caso-de-uso.md) | Visão geral e cinco diagramas UML por área, com fontes editáveis. |
| [Screen map](docs/design/screen-map.md) | Estrutura de navegação, telas, modais, estados e permissões para apoiar o design. |
| [User flows](docs/design/user-flows.md) | Caminhos por objetivo, decisões, cancelamentos e erros, ligados às telas e aos casos de uso. |
| [Modelo de dados (DER)](docs/05-modelo-de-dados.md) | Entidades, atributos, chaves e relacionamentos do banco de dados. |
| [Diagrama de classes](docs/06-diagrama-de-classes.md) | Modelo de classes 1.2: contratos, diagramas por domínio e rastreabilidade UC–RF–RN/RNF–tipos; base funcional 1.5. |
| [Arquitetura mobile](docs/architecture/mobile-architecture.md) | Arquitetura 1.2 em Swift e SwiftUI: View + ViewModel com Clean Architecture, dependências, navegação, sessão, consistência e integrações. |
| [Catálogo mobile](docs/architecture/mobile-feature-catalog.md) | Funcionalidades, nomes de arquivos em inglês e cobertura das 26 telas, 13 modais, 19 casos de uso e 16 fluxos. |
| [Decisões da arquitetura mobile](docs/architecture/mobile-decisions.md) | Escolhas técnicas consolidadas, pendências resolvidas e temas fora desta etapa. |
| [Arquitetura backend](docs/architecture/backend-architecture.md) | Backend 1.0: Node.js, Clean Architecture, monólito modular, Supabase/R2, transações, acesso e jobs. |
| [Contratos backend](docs/architecture/backend-contracts.md) | API `/v1`, permissões, erros, projeções e cobertura dos 19 UC e 27 RNF. |
| [Decisões backend](docs/architecture/backend-decisions.md) | BA-01–BA-20: escolhas confirmadas, propostas técnicas, alternativas e limites. |
| [Índice e controle documental](docs/DOCUMENTACAO.md) | Rastreabilidade e convenções para manter a documentação consistente. |
| [Specs de entrega](specs/README.md) | Recortes aprovados que orientam a implementação conjunta de mobile e backend. |

A versão 1.7 identifica a base de definição do MVP. Não representa, por si só, uma declaração de que o aplicativo foi implementado ou publicado.

## Estrutura para implementação

- `mobile/` será a raiz do aplicativo iOS/iPadOS.
- `backend/` será a raiz da API e dos jobs do servidor.
- `specs/` reúne as entregas aprovadas que conectam os dois projetos à base documental.
- `docs/` continua sendo a fonte de verdade para comportamento, UX, modelo e arquitetura.

Antes de desenvolver uma funcionalidade, a equipe deve partir de uma spec aprovada e
consultar somente as referências rastreáveis que ela indica. As instruções completas
para agentes estão em [AGENTS.md](AGENTS.md).

A arquitetura mobile 1.2, documentada em 2026-10-05, consolida as decisões para implementação futura. O código e os nomes dos arquivos de código serão em inglês; os textos da experiência serão localizados. As estruturas e os exemplos nas docs não representam arquivos Swift já implementados.

## Área Família

A tela Família apresenta diretamente carga e progresso por dia/semana, lista de membros, botão Gerar relatório PDF e, para Administradores, Adicionar membro. Selecionar uma pessoa abre seu detalhe com tarefas por dia/semana; edição de perfil e reenvio de convite ficam nesse detalhe, quando permitidos. A consulta da lista e das tarefas é adulta; a gestão continua exclusiva dos Administradores. O relatório permanece semanal.

## Continuidade e recuperação de acesso

A sessão dos convidados é mantida por refresh token sem expiração temporal, sujeito à revogação de acesso. Se a sessão for perdida, um Administrador gera novo link e senha de uso único para o mesmo perfil ativo, preservando histórico e vínculos. O Criador retorna pelo Sign in with Apple.

## Decisões de produto consolidadas em 2026-10-05

- **Kids:** tab bar com duas abas independentes, “Minhas tarefas” e “Missões e conquistas”. Meu perfil abre pelo avatar/cabeçalho, sem terceira aba. Adicionar foto à sinalização abre diretamente a câmera, com foto ainda opcional.
- **Perfil:** foto opcional e etiqueta/apelido para todos, inclusive Kids. O apelido é visível à família, mas só o titular acessa sua configuração e edição. O perfil mostra os badges recebidos pelos marcos de 5, 10, 25 e 50 missões com participação.
- **Períodos:** progresso pessoal e familiar e carga/sobrecarga alternam entre dia e semana. Kids continuam sem acesso à distribuição de carga familiar. Progresso e carga usam métricas distintas, detalhadas em RN61.
- **PDF semanal:** adultos geram relatório de segunda a domingo com gráficos de carga e progresso total da família, peso creditado e número de tarefas realizadas por membro. O relatório identifica período e geração; a semana atual é parcial.
- **Destaque semanal:** na segunda-feira, apurar o primeiro lugar em pontos da semana encerrada, notificar a pessoa e mostrar o resultado no app. Pontos correspondem aos pesos creditados; todos os empatados em primeiro são reconhecidos. Compartilhar via WhatsApp é opcional e convida a sugerir uma atividade em família.

Referências: RN61–65; RF61–66; UC18–19; TEL-051/052; UF-14/15. RF48, RF55, RN34 e os fluxos existentes também foram revisados.

## Arquitetura e decisões de 2026-10-05

O aplicativo terá iOS/iPadOS 26, Swift/SwiftUI e View + ViewModel com Clean Architecture. Um backend único atende o mobile, com banco Supabase e fotos privadas no Cloudflare R2. PDF e sorteio são locais; o servidor fornece o snapshot e registra o aceite. Código e arquivos de código serão em inglês.

O fuso é escolhido na criação (padrão `America/Sao_Paulo`) e alterado só por Administradores, imediatamente ou no próximo ciclo. O destaque é apurado à meia-noite de segunda e preservado após correções. Badges são cumulativos por participação em 5, 10, 25 e 50 missões; perfis sem participação não recebem a conquista.

Tarefas e início de rotina aceitam qualquer data passada ou futura, inclusive anterior à criação da família. Edições válidas de tarefas concluídas não protegidas ajustam indicadores e mantêm auditoria. Um perfil usa um aparelho; reenvio de convite emite novo link/senha e revoga os anteriores. Trocar de acesso pede confirmação e não remove o membro da família anterior.

Apenas desenvolvimento e produção estão previstos. Backend Node.js/Clean Architecture passa a estar definido na arquitetura backend, com TypeScript/Fastify como propostas técnicas. Retenção de fotos vinculadas, volumes de teste, hospedagem e distribuição continuam fora desta etapa. As decisões completas estão no registro da arquitetura.

A arquitetura backend 1.0 está em [backend-architecture.md](docs/architecture/backend-architecture.md), com contratos e rastreabilidade separados. Esta revisão mantém a base funcional 1.5 e acrescenta o desenho técnico do servidor.

## Histórico

| Versão | Data | Marco |
|---|---|---|
| 1.7 | 2026-10-06 | RF02, RF03 e RF40 passam a definir o nome administrativo de membro e os papéis permitidos na criação, para elaboração de SPEC-003. Tarefa ganha limite de título (1–60 caracteres), observação opcional (até 250 caracteres) e regra de resolução de sinalização Kids pendente ao editar/excluir; SPEC-007 em elaboração. |
| 1.6 | 2026-10-06 | RF01 passa a definir o nome obrigatório da família: 1–60 caracteres Unicode visíveis após trim, sem caracteres de controle; SPEC-002 aprovada. |
| 1.5 | 2026-10-05 | Pendências consolidadas: fuso, datas livres, edição de concluídas, participações/badges, convites e sessão única; RF67/68; arquitetura, modelo e design 1.1. |
| 1.4 | 2026-10-02 | Família concentra indicadores, lista, inclusão de membros e PDF; detalhe do membro reúne tarefas Dia/Semana, edição e reenvio quando permitidos. RN60–61, RF60–61/RF66 e UC02/11/13/18 revisados. |
| 1.3 | 2026-10-02 | Duas abas Kids, câmera direta, foto/apelido e badges, progresso/carga Dia/Semana, PDF semanal e reconhecimento com WhatsApp; RN61–65, RF61–66, RNF26–27 e UC18–19. Empates e visibilidade do apelido confirmados. |
| 1.2 | 2026-10-01 | Área Família na navegação adulta, progresso coletivo diário e consulta por carrossel: RN60, RF60 e UC11. Design em elaboração na versão 1.0. |
| 1.1 | 2026-10-01 | Recuperação do mesmo perfil por novo convite e renovação sem expiração temporal, com revogação preservada: RN47, RF41, RF46, RF54, RNF22, UC02 e UC09. |
| 1.0 | 2026-10-01 | Consolidação da visão, do escopo e dos comportamentos do MVP, com regras, requisitos e casos de uso rastreáveis. |

Complemento de backend de 2026-10-05: arquitetura backend 1.0, contratos e decisões BA-01–BA-20; mobile/modelos 1.2 alinhados, design 1.1 e base funcional 1.5 preservados.
