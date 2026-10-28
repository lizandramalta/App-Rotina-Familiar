# App de Organização Familiar

Organização colaborativa das responsabilidades domésticas, com tarefas compartilhadas, participação infantil e conquistas coletivas.

**Escopo:** MVP  
**Versão da base do projeto:** 1.22\
**Data:** 2026-10-28

## Primeira versão no TestFlight

A primeira distribuição se chama **Mutua** e usa a branch `release-testflight`.
Ela concentra acesso, família, membros adultos, tarefas, rotinas e perfil;
Kids, missões, recompensas coletivas, badges e relatório PDF ficam para
versões posteriores no app. A API de produção permanece compartilhada e com
o contrato completo. O [plano de release](docs/releases/testflight-1.md)
registra o recorte e as pendências de publicação. As seções abaixo continuam
a descrever o produto completo planejado.

## Por que este projeto existe

Em muitas famílias, uma pessoa concentra o trabalho de lembrar, distribuir e acompanhar as tarefas da casa. Mesmo quando a execução é dividida, a gestão pode continuar centralizada.

O projeto busca ajudar a família a compartilhar essas responsabilidades, ampliar a participação e perceber concentrações na rotina. O resultado esperado é reduzir a sensação de sobrecarga e a necessidade de uma única pessoa cobrar os demais.

## Para quem

Famílias que compartilham a rotina doméstica e desejam organizar melhor suas responsabilidades, com participação de adultos e crianças.

## Como funciona

1. O Criador entra com Apple e acessa a família já vinculada ou configura seu perfil — nome obrigatório, foto e etiqueta opcionais — antes de criar uma nova família.
2. Na criação da família, o Criador pode preparar zero ou mais membros, que são criados junto com ela. Depois, pode gerar explicitamente um convite com link e senha para cada perfil ou adiar os convites. A sessão válida permite continuar acessando o aplicativo.
3. Administradores e Membros criam tarefas únicas ou rotinas, definem o esforço e escolhem nenhum, um ou vários responsáveis.
4. Todos acompanham suas tarefas e seu progresso diário. Adultos também consultam tarefas e progresso familiares por dia ou semana. Kids sinalizam a realização com foto opcional; um Administrador confirma ou recusa, ou um adulto conclui manualmente.
5. A conclusão vale para todos os responsáveis finais. Adultos acompanham a distribuição da carga diária ou semanal, sem ranking.
6. A família realiza missões coletivas sem prazo. Ao concluir todas as tarefas vinculadas, registra participações e concede badges nos marcos atingidos e um Administrador pode sortear e aceitar uma recompensa coletiva.

## O que o MVP oferece

- Família com Administradores, Membros e Kids, convites e controle de acesso.
- Tarefas com peso de 1 a 3 e responsáveis opcionais ou compartilhados.
- Rotinas diárias ou a cada 7, 14, 21 ou 28 dias, com tarefas individuais independentes.
- Conclusão de tarefas de outros membros, mantendo os responsáveis ou assumindo a tarefa com aviso sobre o crédito.
- Checklist da criação da família até o último dia do mês corrente e progresso pessoal diário; consultas familiares adultas por dia ou semana.
- Modo Kids com sinalização, foto opcional e avaliação pelo Administrador.
- Carga por dia ou semana para adultos; a semana vai de segunda-feira a domingo.
- Missões coletivas sem prazo, badges por marcos de participação e reabertura que recalcula dados derivados quando necessária.
- Roleta com itens predefinidos e personalizados por Administradores, com um resgate aceito por missão.
- Foto opcional, apelido próprio e badges por participação no perfil de adultos e Kids.
- Relatório semanal em PDF com gráficos e indicadores da família.
- Reconhecimento semanal por pontos, com notificação e compartilhamento opcional pelo WhatsApp.
- Reabertura de tarefas pelo Administrador nas condições previstas.

## Quem pode fazer o quê

| Perfil | Papel principal |
|---|---|
| Administrador | Gerencia membros, missões e recompensas; valida sinalizações Kids e também gerencia e conclui tarefas. |
| Membro | Gerencia e conclui tarefas que não tenham responsável Kids, acompanha carga diária ou semanal e missões e edita os dados permitidos de seu perfil. |
| Kids | Consulta tarefas e progresso, sinaliza com câmera opcional, edita foto/apelido próprios, consulta badges e recebe seu destaque semanal. |

O Criador da Família é um Administrador com identificação especial e proteção contra remoção, rebaixamento e saída. Podem existir outros Administradores, que ingressam por convite.

## Princípios do produto

**Colaboração e equilíbrio.** A experiência ajuda a compartilhar a gestão da rotina, com reconhecimento semanal do primeiro lugar em pontos e sem competição entre famílias.

**Participação compreensível.** A tarefa tem um único estado. Cada responsável recebe o peso integral quando ela é concluída. A carga indica participação creditada, não uma medição exata do tempo ou de toda a sobrecarga doméstica.

**Autonomia com permissões claras.** Adultos gerenciam tarefas; somente Administradores gerenciam membros, missões e recompensas. Kids têm uma experiência simplificada e não acessam a carga diária ou semanal.

**Missões reversíveis com confirmação.** Tarefas concluídas não podem ser excluídas diretamente. Qualquer perfil pode reabrir uma tarefa no seu alcance; quando isso afetar missão concluída e/ou recompensa aceita, confirma a reabertura e remove recompensa, participações e badges derivados.

## Como avaliar o sucesso

O MVP deve ajudar os membros a entender suas responsabilidades, participar da organização da rotina e conversar sobre a distribuição das tarefas. A principal evidência esperada é a redução percebida da centralização e da necessidade de uma pessoa lembrar e cobrar os demais.

Missões e recompensas devem aumentar a participação sem gerar competição. O Modo Kids deve permitir que crianças participem de forma simples. Esses são objetivos de validação, não resultados já comprovados.

## Limites desta versão

Não estão incluídos calendário compartilhado, widgets, lista de compras, disponibilidade por membro, negociação de troca de tarefas, pedidos de ajuda, redistribuição automática, inteligência artificial ou permissões personalizadas.

O produto não prevê recorrência mensal, missões com prazo, conclusão parcial por responsável, rankings completos, streaks, controle de tempo de tela, mascote virtual ou recursos de localização. Tarefas com vários responsáveis são concluídas mantendo responsáveis existentes; sem responsável, o adulto que conclui é atribuído automaticamente.

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
| [Convenções de código mobile](docs/architecture/mobile-code-conventions.md) | Convenções de Swift/SwiftUI, arquitetura, concorrência, segurança e testes. |
| [Arquitetura backend](docs/architecture/backend-architecture.md) | Backend 1.3: Node.js, Clean Architecture, monólito modular, Supabase/R2, transações, acesso e jobs. |
| [Contratos backend](docs/architecture/backend-contracts.md) | API `/v1`, permissões, erros, projeções e cobertura dos 19 UC e 27 RNF. |
| [Decisões backend](docs/architecture/backend-decisions.md) | BA-01–BA-20: escolhas confirmadas, propostas técnicas, alternativas e limites. |
| [Convenções de código backend](docs/architecture/backend-code-conventions.md) | Convenções de TypeScript/Fastify, contratos, SQL, segurança e testes. |
| [Índice e controle documental](docs/DOCUMENTACAO.md) | Rastreabilidade e convenções para manter a documentação consistente. |
| [Specs de entrega](specs/README.md) | Recortes aprovados que orientam a implementação conjunta de mobile e backend. |

A versão 1.14 identifica a base de definição do MVP. Não representa, por si só, uma declaração de que o aplicativo foi implementado ou publicado.

## Como executar localmente (onboarding rápido)

Passo a passo para sair de um clone limpo até backend e mobile rodando.

### Pré-requisitos

- Node.js 22 ou superior e npm 10 ou superior.
- Acesso ao projeto PostgreSQL no Supabase (a connection string fica no botão **Connect**, em *Connection Method > Session pooler*).
- Xcode 26 ou superior, com um simulador iOS/iPadOS 26, e `xcode-select` apontando para o Xcode completo.

### Passo 1 — Backend

```sh
cd backend
cp .env.example .env
npm ci
```

Edite o `.env` e substitua os placeholders `[PROJECT-REF]`, `[PASSWORD]` e `[REGION]` do
`DATABASE_URL` pelos valores do projeto no Supabase (botão **Connect**, *Session pooler*,
porta 5432). O `DATABASE_SSL=true` do template já é o valor correto para o Supabase remoto;
não acrescente `?sslmode=require` à URL, pois o driver `pg` trata isso como `verify-full` e
a conexão falha. Em seguida:

```sh
npm run migrate          # aplica as migrations em app.schema_migrations
npm run dev              # API em http://localhost:3000
```

Verifique as sondas operacionais em outro terminal:

```sh
curl http://localhost:3000/health/live     # 200 {"status":"ok",...}
curl http://localhost:3000/health/ready    # 200 {"status":"ready",...} com o banco acessível
```

Checagens de qualidade, as mesmas que a CI executa:

```sh
npm run lint
npm run typecheck
npm run test              # testes unitários, sem necessidade de banco
npm run build
npm run test:integration  # smoke de /health/live e /health/ready contra o banco do .env
```

### Passo 2 — Mobile

```sh
cd mobile
cp Configuration/Development.xcconfig.example Configuration/Development.xcconfig
cp Configuration/Production.xcconfig.example Configuration/Production.xcconfig
```

Preencha `API_BASE_URL` no `Development.xcconfig` com o endereço da API local
(use o IP da máquina, não `localhost`, quando rodar em dispositivo físico). Depois abra
`mobile.xcodeproj` no Xcode, escolha o scheme `FamilyRoutine` e um simulador iOS/iPadOS 26.

Pela linha de comando:

```sh
xcodebuild build -project mobile.xcodeproj -scheme FamilyRoutine \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

xcodebuild test -project mobile.xcodeproj -scheme FamilyRoutine \
  -destination 'platform=iOS Simulator,name=<simulador instalado>'
```

Use `xcrun simctl list devices available` para ver os simuladores instalados.
Detalhes e limites da fundação mobile estão em [mobile/SETUP.md](mobile/SETUP.md).

### Segredos

`.env` e os `*.xcconfig` são locais e ignorados pelo Git. Versione apenas os templates
`.env.example` e `*.xcconfig.example`, e nunca inclua credenciais reais neles.

## Estrutura de implementação

- `mobile/` é a raiz do aplicativo iOS/iPadOS.
- `backend/` é a raiz da API e dos jobs do servidor.
- `specs/` reúne as entregas aprovadas que conectam os dois projetos à base documental.
- `docs/` continua sendo a fonte de verdade para comportamento, UX, modelo e arquitetura.

Antes de desenvolver uma funcionalidade, a equipe deve partir de uma spec aprovada e
consultar somente as referências rastreáveis que ela indica. As instruções completas
para agentes estão em [AGENTS.md](AGENTS.md).

A Sprint 0 implementou a fundação técnica de mobile, backend, migrations e CI, sem introduzir comportamento de produto. As arquiteturas mantêm as funcionalidades, telas e integrações de produto como implementação futura orientada por SPECs aprovadas. O código e os nomes dos arquivos de código são em inglês; os textos da experiência são localizáveis.

## Área Família

A tela Família apresenta progresso no intervalo escolhido, lista de membros e, para Administradores, acesso às configurações e à inclusão de membros. A lista Tarefas da família reúne filtros por intervalo, membro e status; agrupa tarefas com contagens completas por estado e oferece Gerar relatório PDF no menu. Se o intervalo estiver em uma única semana, o PDF abre diretamente na folha nativa de compartilhamento; se tocar várias semanas, a pessoa escolhe a semana antes. Selecionar um membro abre seu detalhe com progresso e tarefas de hoje, enquanto outros dias são consultados pelo filtro da Família; edição de perfil e reenvio de convite ficam nesse detalhe, quando permitidos. A consulta familiar é adulta; a gestão continua exclusiva dos Administradores.

## Continuidade e recuperação de acesso

A sessão dos convidados é mantida por refresh token sem expiração temporal, sujeito à revogação de acesso. Se a sessão for perdida, um Administrador gera novo link e senha de uso único para o mesmo perfil ativo, preservando histórico e vínculos. O Criador retorna pelo Sign in with Apple.

## Decisões de produto consolidadas em 2026-10-05

- **Kids:** tab bar com duas abas independentes, “Minhas tarefas” e “Missões e conquistas”. Meu perfil abre pelo avatar/cabeçalho, sem terceira aba. Adicionar foto à sinalização abre diretamente a câmera, com foto ainda opcional.
- **Perfil:** foto opcional e etiqueta/apelido para todos, inclusive Kids. O apelido é visível à família, mas só o titular acessa sua configuração e edição. O perfil mostra os badges recebidos pelos marcos de 5, 10, 25 e 50 missões com participação.
- **Períodos:** progresso pessoal é diário. Adultos alternam dia e semana nas consultas familiares de tarefas, progresso e carga; Kids continuam sem acesso à distribuição de carga familiar. Progresso e carga usam métricas distintas, detalhadas em RN61.
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
| 1.22 | 2026-10-28 | TEL-032 usa Dia/Semana domingo–sábado, sem Parabenizar no detalhe; Admin autorizado edita nome Kids no topo. Folhas de filtros da Família e de Tarefas da família seguem variantes distintas. |
| 1.21 | 2026-10-28 | TEL-032 mostra progresso e tarefas de hoje com menu de gestão; a consulta de outros dias permanece em Tarefas da família. |
| 1.20 | 2026-10-28 | Resumo da navegação e apresentação da área Família atualizado conforme UX-009/UX-019 e TEL-011; base funcional preservada. |
| 1.19 | 2026-10-19 | RN38, RF59 e UC07: exclusão de tarefa que deixa a missão apenas com tarefas concluídas a conclui na mesma transação (SPEC-014/SPEC-007). Onboarding alinhado à criação conjunta de família e membros; revisão dos pares SPEC/UX-002, 003, 004 e 009 aprovada. |
| 1.18 | 2026-10-10 | Consolidação das SPECs 015–020 com as implementações de acesso, família, convites, tarefas e sessão do `develop`; registros técnicos preservados na documentação de arquitetura. |
| 1.17 | 2026-10-10 | Snapshot semanal passa a usar `referenceDate` e identifica crédito histórico como “Membro removido”. Para SPEC-019. |
| 1.16 | 2026-10-10 | Carga histórica preserva crédito de perfil removido como “Membro removido”. Para SPEC-018. |
| 1.15 | 2026-10-10 | Itens de recompensa coletiva ganham catálogo inicial, título personalizado único por família e descrição opcional de até 255 caracteres. Para SPEC-015. |
| 1.14 | 2026-10-07 | Onboarding do Criador: perfil antes da família, membros opcionais e convite explícito antes da área principal. Base funcional 1.14. |
| 1.13 | 2026-10-07 | Apelido do perfil ganha limite explícito: até 20 caracteres não-espaço após trim, sem caracteres de controle. Para SPEC-006. |
| 1.12 | 2026-10-07 | Missão ganha observação opcional (até 250 caracteres); criação de tarefa durante a vinculação de missão; consulta explícita por todos os perfis, inclusive Kids, em experiência simplificada. Para SPEC-014. |
| 1.11 | 2026-10-07 | Conclusão direta preserva responsáveis existentes ou atribui o adulto sem responsável. Reabertura por todos os perfis no seu alcance pode reabrir missão concluída e reverte recompensa, participações e badges. |
| 1.10 | 2026-10-06 | Tarefas com responsável Kids só podem ser concluídas manualmente por Administradores; sinalização/foto pendente é preservada para auditoria administrativa. Para SPEC-010. |
| 1.9 | 2026-10-06 | Consulta pessoal diária para todos os perfis; consultas familiares adultas por Dia/Semana; carga detalhada permanece na SPEC-018. |
| 1.7 | 2026-10-06 | RF02, RF03 e RF40 passam a definir o nome administrativo de membro e os papéis permitidos na criação, para elaboração de SPEC-003. Tarefa ganha limite de título (1–60 caracteres), observação opcional (até 250 caracteres) e regra de resolução de sinalização Kids pendente ao editar/excluir; SPEC-007 em elaboração. |
| 1.6 | 2026-10-06 | RF01 passa a definir o nome obrigatório da família: 1–60 caracteres Unicode visíveis após trim, sem caracteres de controle; SPEC-002 aprovada. |
| 1.5 | 2026-10-05 | Pendências consolidadas: fuso, datas livres, edição de concluídas, participações/badges, convites e sessão única; RF67/68; arquitetura, modelo e design 1.1. |
| 1.4 | 2026-10-02 | Família concentra indicadores, lista, inclusão de membros e PDF; detalhe do membro reúne tarefas Dia/Semana, edição e reenvio quando permitidos. RN60–61, RF60–61/RF66 e UC02/11/13/18 revisados. |
| 1.3 | 2026-10-02 | Duas abas Kids, câmera direta, foto/apelido e badges, progresso/carga Dia/Semana, PDF semanal e reconhecimento com WhatsApp; RN61–65, RF61–66, RNF26–27 e UC18–19. Empates e visibilidade do apelido confirmados. |
| 1.2 | 2026-10-01 | Área Família na navegação adulta, progresso coletivo diário e consulta por carrossel: RN60, RF60 e UC11. Design em elaboração na versão 1.0. |
| 1.1 | 2026-10-01 | Recuperação do mesmo perfil por novo convite e renovação sem expiração temporal, com revogação preservada: RN47, RF41, RF46, RF54, RNF22, UC02 e UC09. |
| 1.0 | 2026-10-01 | Consolidação da visão, do escopo e dos comportamentos do MVP, com regras, requisitos e casos de uso rastreáveis. |

Complemento de backend de 2026-10-05: arquitetura backend 1.0, contratos e decisões BA-01–BA-20; mobile/modelos 1.2 alinhados, design 1.1 e base funcional 1.5 preservados.
