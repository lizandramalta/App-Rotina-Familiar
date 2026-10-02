# App de Organização Familiar

Organização colaborativa das responsabilidades domésticas, com tarefas compartilhadas, participação infantil e conquistas coletivas.

**Escopo:** MVP  
**Versão da base do projeto:** 1.0  
**Data:** 2026-10-01

## Por que este projeto existe

Em muitas famílias, uma pessoa concentra o trabalho de lembrar, distribuir e acompanhar as tarefas da casa. Mesmo quando a execução é dividida, a gestão pode continuar centralizada.

O projeto busca ajudar a família a compartilhar essas responsabilidades, ampliar a participação e perceber concentrações na rotina. O resultado esperado é reduzir a sensação de sobrecarga e a necessidade de uma única pessoa cobrar os demais.

## Para quem

Famílias que compartilham a rotina doméstica e desejam organizar melhor suas responsabilidades, com participação de adultos e crianças.

## Como funciona

1. O Criador entra com Apple e cria a família ou acessa a que já está vinculada a ele.
2. Um Administrador cria os perfis e compartilha convites com link e senha para um único ingresso. Depois, a sessão válida permite continuar acessando o aplicativo.
3. Administradores e Membros criam tarefas únicas ou rotinas, definem o esforço e escolhem nenhum, um ou vários responsáveis.
4. Todos acompanham suas tarefas e seu progresso diário. Kids sinalizam a realização com foto opcional; um Administrador confirma ou recusa, ou um adulto conclui manualmente.
5. A conclusão vale para todos os responsáveis finais. Adultos acompanham a distribuição da carga semanal, sem ranking.
6. A família realiza missões coletivas sem prazo. Ao concluir todas as tarefas vinculadas, recebe o selo opcional e um Administrador pode sortear e aceitar uma recompensa coletiva.

## O que o MVP oferece

- Família com Administradores, Membros e Kids, convites e controle de acesso.
- Tarefas com peso de 1 a 3 e responsáveis opcionais ou compartilhados.
- Rotinas diárias ou a cada 7, 14, 21 ou 28 dias, com tarefas individuais independentes.
- Conclusão de tarefas de outros membros, mantendo os responsáveis ou assumindo a tarefa com aviso sobre o crédito.
- Checklist da criação da família até o último dia do mês corrente e progresso diário para todos.
- Modo Kids com sinalização, foto opcional e avaliação pelo Administrador.
- Carga semanal para adultos, calculada de segunda-feira a domingo.
- Missões coletivas sem prazo, selos opcionais e conquistas preservadas.
- Roleta com itens predefinidos e personalizados por Administradores, com um resgate aceito por missão.
- Edição dos dados permitidos do próprio perfil e reabertura de tarefas pelo Administrador nas condições previstas.

## Quem pode fazer o quê

| Perfil | Papel principal |
|---|---|
| Administrador | Gerencia membros, missões e recompensas; valida sinalizações Kids e também gerencia e conclui tarefas. |
| Membro | Gerencia e conclui tarefas, acompanha carga semanal e missões e edita os dados permitidos de seu perfil. |
| Kids | Consulta suas tarefas e progresso, sinaliza realização e acompanha conquistas coletivas. |

O Criador da Família é um Administrador com identificação especial e proteção contra remoção, rebaixamento e saída. Podem existir outros Administradores, que ingressam por convite.

## Princípios do produto

**Colaboração e equilíbrio.** A experiência ajuda a compartilhar a gestão da rotina, sem ranking individual ou competição entre famílias.

**Participação compreensível.** A tarefa tem um único estado. Cada responsável recebe o peso integral quando ela é concluída. A carga indica participação creditada, não uma medição exata do tempo ou de toda a sobrecarga doméstica.

**Autonomia com permissões claras.** Adultos gerenciam tarefas; somente Administradores gerenciam membros, missões e recompensas. Kids têm uma experiência simplificada e não acessam a carga semanal.

**Conquistas preservadas.** Missões concluídas mantêm seus dados. Tarefas concluídas não podem ser excluídas diretamente. A reabertura exige Administrador, vínculo com missão em andamento e ausência de vínculo com qualquer missão concluída.

## Como avaliar o sucesso

O MVP deve ajudar os membros a entender suas responsabilidades, participar da organização da rotina e conversar sobre a distribuição das tarefas. A principal evidência esperada é a redução percebida da centralização e da necessidade de uma pessoa lembrar e cobrar os demais.

Missões e recompensas devem aumentar a participação sem gerar competição. O Modo Kids deve permitir que crianças participem de forma simples. Esses são objetivos de validação, não resultados já comprovados.

## Limites desta versão

Não estão incluídos calendário compartilhado, widgets, lista de compras, disponibilidade por membro, negociação de troca de tarefas, pedidos de ajuda, redistribuição automática, inteligência artificial ou permissões personalizadas.

O produto não prevê recorrência mensal, missões com prazo, conclusão parcial por responsável, rankings, streaks, controle de tempo de tela, mascote virtual ou recursos de localização. Tarefas com vários responsáveis e a opção de assumir ao concluir já estão no MVP.

As possibilidades de evolução estão no [documento de visão](00-visao-do-produto.md), sem compromisso de implementação nesta versão.

## Conheça o projeto em detalhe

| Documento | O que você encontra |
|---|---|
| [Visão do produto](00-visao-do-produto.md) | Problema, público, objetivos, jornada, escopo e critérios de sucesso. |
| [Regras de negócio](01-regras-de-negocio.md) | As condições que regem a experiência e suas exceções. |
| [Requisitos funcionais e não funcionais](02-requisitos.md) | Comportamentos esperados, qualidade, segurança e integridade. |
| [Casos de uso](03-casos-de-uso.md) | Os 17 fluxos, com atores, pré-condições, alternativas e resultados. |
| [Índice e controle documental](DOCUMENTACAO.md) | Rastreabilidade e convenções para manter a documentação consistente. |

A versão 1.0 identifica a base de definição do MVP. Não representa, por si só, uma declaração de que o aplicativo foi implementado ou publicado.

## Histórico

| Versão | Data | Marco |
|---|---|---|
| 1.0 | 2026-10-01 | Consolidação da visão, do escopo e dos comportamentos do MVP, com regras, requisitos e casos de uso rastreáveis. |
