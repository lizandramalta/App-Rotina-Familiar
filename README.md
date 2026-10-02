# App de Organização Familiar

Organização colaborativa das responsabilidades domésticas, com tarefas compartilhadas, participação infantil e conquistas coletivas.

**Escopo:** MVP  
**Versão da base do projeto:** 1.3  
**Data:** 2026-10-02

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
6. A família realiza missões coletivas sem prazo. Ao concluir todas as tarefas vinculadas, recebe o selo opcional e um Administrador pode sortear e aceitar uma recompensa coletiva.

## O que o MVP oferece

- Família com Administradores, Membros e Kids, convites e controle de acesso.
- Tarefas com peso de 1 a 3 e responsáveis opcionais ou compartilhados.
- Rotinas diárias ou a cada 7, 14, 21 ou 28 dias, com tarefas individuais independentes.
- Conclusão de tarefas de outros membros, mantendo os responsáveis ou assumindo a tarefa com aviso sobre o crédito.
- Checklist da criação da família até o último dia do mês corrente e progresso diário ou semanal para todos.
- Modo Kids com sinalização, foto opcional e avaliação pelo Administrador.
- Carga por dia ou semana para adultos; a semana vai de segunda-feira a domingo.
- Missões coletivas sem prazo, selos opcionais e conquistas preservadas.
- Roleta com itens predefinidos e personalizados por Administradores, com um resgate aceito por missão.
- Foto opcional, apelido próprio e badges coletivos no perfil de adultos e Kids.
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
| [Índice e controle documental](docs/DOCUMENTACAO.md) | Rastreabilidade e convenções para manter a documentação consistente. |

A versão 1.3 identifica a base de definição do MVP. Não representa, por si só, uma declaração de que o aplicativo foi implementado ou publicado.

## Área Família

Família é uma área da navegação principal adulta. Administradores e Membros acompanham o progresso coletivo diário ou semanal, consultam tarefas da família pelo seletor Dia/Semana e acessam a carga diária ou semanal. O progresso conta tarefas concluídas sobre o total de tarefas previstas para o período, uma vez por tarefa, inclusive compartilhadas ou sem responsável. Somente Administradores gerenciam membros e confirmam sinalizações Kids. Sem tarefas no período, o aplicativo informa essa condição.

## Continuidade e recuperação de acesso

A sessão dos convidados é mantida por refresh token sem expiração temporal, sujeito à revogação de acesso. Se a sessão for perdida, um Administrador gera novo link e senha de uso único para o mesmo perfil ativo, preservando histórico e vínculos. O Criador retorna pelo Sign in with Apple.

## Decisões de 2026-10-02

- **Kids:** tab bar com duas abas independentes, “Minhas tarefas” e “Missões e conquistas”. Meu perfil abre pelo avatar/cabeçalho, sem terceira aba. Adicionar foto à sinalização abre diretamente a câmera, com foto ainda opcional.
- **Perfil:** foto opcional e etiqueta/apelido para todos, inclusive Kids. O apelido é visível à família, mas só o titular acessa sua configuração e edição. O perfil mostra os badges recebidos coletivamente ao concluir missões com selo.
- **Períodos:** progresso pessoal e familiar e carga/sobrecarga alternam entre dia e semana. Kids continuam sem acesso à distribuição de carga familiar. Progresso e carga usam métricas distintas, detalhadas em RN61.
- **PDF semanal:** adultos geram relatório de segunda a domingo com gráficos de carga e progresso total da família, peso creditado e número de tarefas realizadas por membro. O relatório identifica período e geração; a semana atual é parcial.
- **Destaque semanal:** na segunda-feira, apurar o primeiro lugar em pontos da semana encerrada, notificar a pessoa e mostrar o resultado no app. Pontos correspondem aos pesos creditados; todos os empatados em primeiro são reconhecidos. Compartilhar via WhatsApp é opcional e convida a sugerir uma atividade em família.

Referências: RN61–65; RF61–66; UC18–19; TEL-051/052; UF-14/15. RF48, RF55, RN34 e os fluxos existentes também foram revisados.

## Histórico

| Versão | Data | Marco |
|---|---|---|
| 1.3 | 2026-10-02 | Duas abas Kids, câmera direta, foto/apelido e badges, progresso/carga Dia/Semana, PDF semanal e reconhecimento com WhatsApp; RN61–65, RF61–66, RNF26–27 e UC18–19. Empates e visibilidade do apelido confirmados. |
| 1.2 | 2026-10-01 | Área Família na navegação adulta, progresso coletivo diário e consulta por carrossel: RN60, RF60 e UC11. Design em elaboração na versão 1.0. |
| 1.1 | 2026-10-01 | Recuperação do mesmo perfil por novo convite e renovação sem expiração temporal, com revogação preservada: RN47, RF41, RF46, RF54, RNF22, UC02 e UC09. |
| 1.0 | 2026-10-01 | Consolidação da visão, do escopo e dos comportamentos do MVP, com regras, requisitos e casos de uso rastreáveis. |
