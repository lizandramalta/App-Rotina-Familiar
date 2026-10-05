# Documento de visão — MVP

**Projeto:** App de Organização Familiar  
**Versão:** 1.4  
**Data:** 2026-10-02  
**Situação:** visão consolidada do produto

[Projeto](../README.md) · [Índice documental](DOCUMENTACAO.md) · [Regras](01-regras-de-negocio.md) · [Requisitos](02-requisitos.md) · [Casos de uso](03-casos-de-uso.md) · [Diagramas UML](04-diagramas-de-caso-de-uso.md) · [Screen map](design/screen-map.md) · [Diagrama de classes](06-diagrama-de-classes.md)

## 1. Contexto e problema

A pesquisa com famílias relatada no documento de visão de origem apontou a concentração da gestão doméstica em uma única pessoa. Além de executar atividades, essa pessoa precisa lembrar, distribuir, acompanhar e cobrar os demais membros. O material recebido não apresenta amostra ou resultados quantitativos; esse diagnóstico é a base qualitativa da proposta.

Mesmo quando outras pessoas participam da execução, organizar a rotina pode continuar sendo uma responsabilidade centralizada. O produto busca tornar as responsabilidades domésticas mais visíveis, distribuídas e compartilhadas.

**Problema central:** como tornar a divisão das responsabilidades domésticas mais visível, equilibrada e colaborativa, reduzindo a sobrecarga de gerenciamento concentrada em uma única pessoa?

## 2. Objetivo do produto

Criar um aplicativo que ajude famílias a organizar e acompanhar responsabilidades domésticas de forma compartilhada, identificar concentrações na participação e incentivar o envolvimento de seus membros.

O resultado esperado é reduzir a percepção de sobrecarga e a centralização da gestão doméstica. A organização das tarefas é um meio para promover equilíbrio e colaboração. Esses benefícios são objetivos a validar com famílias, e não resultados já comprovados do aplicativo.

## 3. Visão da solução

Um aplicativo em que adultos compartilham o gerenciamento de tarefas e rotinas, crianças participam por uma experiência simplificada e a família acompanha seu progresso e suas conquistas coletivas.

As tarefas possuem peso de esforço e podem ter nenhum, um ou vários responsáveis. A visualização diária ou semanal apresenta a participação dos membros, enquanto missões sem prazo, selos opcionais e recompensas coletivas incentivam o engajamento com foco na colaboração.

A carga diária ou semanal representa a participação creditada em tarefas concluídas. Ela não mede diretamente tempo gasto, esforço efetivamente individual ou todo o trabalho de planejamento doméstico. Em uma tarefa compartilhada, cada responsável recebe o peso integral; por isso, a visualização deve apoiar a conversa sobre equilíbrio sem ser apresentada como medida exata de sobrecarga.

## 4. Princípios da experiência

- **Visibilidade:** cada pessoa entende suas tarefas e seu progresso diário ou semanal. Administradores e Membros também acompanham a carga diária ou semanal da família, respeitando as restrições do perfil Kids.
- **Equilíbrio:** a apresentação ajuda a perceber concentrações de participação, com uma visão de distribuição; o destaque semanal reconhece o primeiro lugar em pontos e convida à convivência familiar.
- **Colaboração:** adultos podem gerenciar tarefas e a família compartilha objetivos e recompensas.
- **Participação infantil:** Kids sinalizam a realização com foto opcional; a sinalização não produz conclusão parcial nem pontuação imediata.
- **Engajamento coletivo:** missões, selos e recompensas valorizam conquistas da família, sem penalidades por demora.
- **Simplicidade e acessibilidade:** linguagem clara, navegação compreensível e informações que não dependam apenas de cores.
- **Confiança:** permissões, confirmação de gravações e preservação de conquistas mantêm os registros coerentes.

## 5. Público-alvo e perfis

O público-alvo são famílias que compartilham a rotina doméstica e desejam organizar suas responsabilidades, reduzir a centralização da gestão e ampliar a participação dos demais membros.

| Perfil ou identificação | Participação no produto |
|---|---|
| Administrador | Gerencia membros, permissões, missões e itens de recompensa; valida sinalizações Kids; sorteia e aceita recompensas; também gerencia e conclui tarefas. Pode haver vários Administradores. |
| Membro | Gerencia tarefas e rotinas, inclusive de outros membros; conclui tarefas; edita os dados permitidos de seu perfil; consulta progresso diário ou semanal, carga diária ou semanal e missões. |
| Kids | Consulta suas tarefas e seu progresso diário ou semanal, sinaliza realização com foto opcional e acompanha missões e recompensas. Edita sua foto e apelido, consulta badges e recebe seu destaque semanal. Não gerencia tarefas nem acessa a carga familiar. |
| Criador da Família | É um Administrador com identificação especial, não um quarto perfil. Usa Sign in with Apple e não pode ser removido, rebaixado nem sair da família. |

Somente Administradores gerenciam membros e ativam ou desativam o Modo Kids. Um Administrador não pode permanecer em Modo Kids. Cada usuário pertence a uma única família.

Referências: [RN01](01-regras-de-negocio.md#rn01) a [RN10](01-regras-de-negocio.md#rn10), [RF05](02-requisitos.md#rf05), [UC02](03-casos-de-uso.md#uc02).

## 6. Jornada principal

1. O Criador autentica-se com Apple. Se já tiver família vinculada, é redirecionado para ela; caso contrário, cria sua família.
2. Um Administrador cria os perfis e disponibiliza convites com link e senha gerada pelo sistema. A pessoa convidada informa a senha para efetivar o vínculo. O convite admite um ingresso bem-sucedido, e a sessão válida permite os próximos acessos sem reutilizá-lo.
3. Administradores e Membros criam tarefas com título e peso obrigatório, responsáveis opcionais e, quando necessário, uma rotina de repetição.
4. Cada perfil consulta suas tarefas e seu progresso diário ou semanal. O carrossel vai da criação da família até o último dia do mês corrente, incluindo dias futuros dentro desse mês.
5. Adultos concluem tarefas. Ao concluir tarefa atribuída a outras pessoas, podem manter os responsáveis ou assumir a tarefa, substituindo-os por si mesmos após aviso sobre o crédito. Tarefa sem responsável é atribuída a quem a conclui.
6. Kids sinalizam a realização de sua parte, com foto opcional. Um Administrador pode confirmar ou recusar. Um adulto também pode concluir manualmente a tarefa. A conclusão vale para todos os responsáveis finais, inclusive Kids.
7. O aplicativo calcula a carga por dia ou semana (segunda-feira a domingo), creditando o peso integral da tarefa a cada responsável. Administradores e Membros consultam a distribuição sem ranking.
8. Um Administrador cria missões coletivas sem prazo, vinculando tarefas individuais. A família acompanha o progresso até todas as tarefas serem concluídas.
9. A conclusão da missão concede seu selo opcional e habilita a roleta. Um Administrador sorteia e aceita uma recompensa coletiva, encerrando o resgate para toda a família.

Os fluxos completos estão na [especificação dos casos de uso](03-casos-de-uso.md).

## 7. Regras centrais da experiência

| Tema | Comportamento da versão 1.4 | Referências |
|---|---|---|
| Acesso e vínculo | Apple exclusivo do Criador; demais perfis ingressam com link e senha de uso único. Remover um membro revoga o acesso, inclusive por sessões abertas. | [RN10](01-regras-de-negocio.md#rn10), [RN44](01-regras-de-negocio.md#rn44), [RN46](01-regras-de-negocio.md#rn46), [UC09](03-casos-de-uso.md#uc09) |
| Tarefas e rotinas | Tarefa única ou rotina diária ou a cada 7, 14, 21 ou 28 dias. Não existe frequência mensal. Cada ocorrência possui identificação e estado próprios. | [RN14](01-regras-de-negocio.md#rn14), [RN16](01-regras-de-negocio.md#rn16), [UC08](03-casos-de-uso.md#uc08) |
| Esforço | Peso obrigatório de 1 a 3: pouco, médio e alto esforço. | [RN13](01-regras-de-negocio.md#rn13), [RF15](02-requisitos.md#rf15), [RF16](02-requisitos.md#rf16) |
| Responsáveis e conclusão | Tarefas podem ter vários responsáveis. A conclusão é única e vale para todos. Cada responsável recebe o peso integral, sem divisão. Quem apenas marca a conclusão pode não receber crédito. | [RN30](01-regras-de-negocio.md#rn30), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56), [UC12](03-casos-de-uso.md#uc12) |
| Kids | Foto opcional; confirmação pelo Administrador ou conclusão manual por adulto. Aguardar confirmação não gera carga nem progresso concluído. | [RN23](01-regras-de-negocio.md#rn23), [RN26](01-regras-de-negocio.md#rn26), [RN54](01-regras-de-negocio.md#rn54), [UC03](03-casos-de-uso.md#uc03), [UC15](03-casos-de-uso.md#uc15) |
| Consulta e progresso | Todos veem seu próprio progresso diário ou semanal. O carrossel vai da criação da família até o último dia do mês corrente. Kids não visualizam a carga diária ou semanal. | [RN33](01-regras-de-negocio.md#rn33), [RN49](01-regras-de-negocio.md#rn49), [UC11](03-casos-de-uso.md#uc11) |
| Carga diária ou semanal | Soma dos pesos creditados por responsável nas conclusões válidas do período. A carga total soma as cargas individuais. A apresentação prioriza equilíbrio, sem ranking. | [RN28](01-regras-de-negocio.md#rn28), [RN30](01-regras-de-negocio.md#rn30), [RN31](01-regras-de-negocio.md#rn31), [RN34](01-regras-de-negocio.md#rn34), [UC13](03-casos-de-uso.md#uc13) |
| Missões | Coletivas, sem prazo ou expiração, com pelo menos uma tarefa individual. Cada tarefa conta uma vez no progresso, mesmo com vários responsáveis. | [RN35](01-regras-de-negocio.md#rn35), [RN36](01-regras-de-negocio.md#rn36), [RN39](01-regras-de-negocio.md#rn39), [RN50](01-regras-de-negocio.md#rn50), [UC05](03-casos-de-uso.md#uc05) |
| Recompensas | Itens predefinidos e personalizados por Administradores. Após a missão, podem sortear novamente até aceitar; sair sem aceitar mantém o resgate disponível. A aceitação encerra o resgate para todos. | [RN42](01-regras-de-negocio.md#rn42), [RN52](01-regras-de-negocio.md#rn52), [RN53](01-regras-de-negocio.md#rn53), [UC06](03-casos-de-uso.md#uc06), [UC16](03-casos-de-uso.md#uc16) |
| Exclusão e reabertura | Tarefa concluída não é excluída diretamente. Somente Administrador pode reabri-la se vinculada a missão em andamento e a nenhuma missão concluída. Isso desfaz a contribuição anterior na carga e no progresso. | [RN18](01-regras-de-negocio.md#rn18), [RN57](01-regras-de-negocio.md#rn57), [RN59](01-regras-de-negocio.md#rn59), [UC17](03-casos-de-uso.md#uc17) |
| Preservação de conquistas | Missões concluídas e seus vínculos são preservados. Alterações nas tarefas não podem modificar esses dados. O resgate ainda disponível pode acrescentar a recompensa. Excluir uma tarefa não pode deixar missão em andamento sem tarefas. | [RN50](01-regras-de-negocio.md#rn50), [RN58](01-regras-de-negocio.md#rn58), [RF58](02-requisitos.md#rf58), [RF59](02-requisitos.md#rf59) |

## 8. Escopo do MVP

O escopo vigente corresponde ao conjunto consolidado de regras, requisitos e casos de uso da versão 1.4. A priorização inicial foi ajustada para incorporar as decisões posteriores; assumir tarefas e atribuir vários responsáveis já fazem parte do MVP.

| Capacidade incluída | Casos de uso |
|---|---|
| Criação e acesso à família; autenticação do Criador | [UC01](03-casos-de-uso.md#uc01), [UC04](03-casos-de-uso.md#uc04) |
| Gerenciamento de membros, permissões e convites; ingresso com senha | [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09) |
| Gerenciamento de tarefas, responsáveis e rotinas; conclusão e reabertura permitida | [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC12](03-casos-de-uso.md#uc12), [UC17](03-casos-de-uso.md#uc17) |
| Foto opcional, apelido próprio e badges para todos os perfis | [UC10](03-casos-de-uso.md#uc10) |
| Checklist por data e progresso diário ou semanal para todos | [UC11](03-casos-de-uso.md#uc11) |
| Modo Kids, sinalização com foto opcional e validação | [UC03](03-casos-de-uso.md#uc03), [UC15](03-casos-de-uso.md#uc15) |
| Distribuição da carga diária ou semanal para adultos | [UC13](03-casos-de-uso.md#uc13) |
| Missões coletivas sem prazo, selo opcional e acompanhamento | [UC05](03-casos-de-uso.md#uc05), [UC14](03-casos-de-uso.md#uc14) |
| Itens de recompensa personalizados, roleta e resgate único | [UC06](03-casos-de-uso.md#uc06), [UC16](03-casos-de-uso.md#uc16) |
| Relatório familiar semanal PDF | [UC18](03-casos-de-uso.md#uc18) |
| Apuração, notificação e compartilhamento do destaque semanal | [UC19](03-casos-de-uso.md#uc19) |

Segurança, privacidade, acessibilidade, responsividade e integridade são condições de implementação descritas nos [requisitos não funcionais](02-requisitos.md#requisitos-nao-funcionais).

## 9. Fora do MVP e possíveis evoluções

As possibilidades abaixo permanecem fora da versão 1.0 e dependem de reavaliação após a validação da proposta principal.

- **Should Have da priorização inicial, ainda fora do MVP:** widget de lembrete das atividades diárias, disponibilidade do membro, calendário compartilhado e fluxo específico de negociação ou troca de tarefas entre membros. A reatribuição direta e a opção de assumir ao concluir já estão incluídas.
- **Could Have da priorização inicial, ainda fora do MVP:** cutucar/chinelar, lista de compras compartilhada, pedido de ajuda, reconhecimento entre membros, rotina inteligente com IA, avatares customizáveis, preferências de tarefas e rodízio automático para tarefas desagradáveis.
- **Outras possibilidades futuras:** sugestões automáticas de redistribuição e permissões personalizáveis por membro.

“Tarefas em grupo” deixa de ser um item genericamente excluído: a versão 1.0 já permite vários responsáveis em uma tarefa com conclusão compartilhada. Não há acompanhamento de conclusão parcial por pessoa.

## 10. Funcionalidades excluídas da visão atual

- Streak familiar.
- Tempo de tela definido conforme o esforço nas tarefas.
- Tamagotchi da família.
- Competição entre famílias ou ranking completo individual. O reconhecimento semanal do primeiro lugar em pontos integra o MVP.
- Mapas e funcionalidades baseadas em localização.

Recorrência mensal e missões com prazo também não fazem parte das regras vigentes; não são apresentadas como compromissos futuros.

## 11. Critérios de sucesso do MVP

O MVP deve validar se ajuda as famílias a perceber e reduzir a centralização da gestão doméstica. A quantidade de tarefas concluídas, isoladamente, não demonstra esse resultado.

| Critério | Evidência qualitativa a buscar na validação |
|---|---|
| Clareza de responsabilidades | Os membros conseguem identificar suas tarefas, responsáveis e estados sem depender constantemente de outra pessoa. |
| Percepção de equilíbrio | Adultos compreendem a distribuição da carga e usam essa informação para conversar sobre a rotina, sem tratá-la como ranking. |
| Menor centralização | A pessoa que normalmente organiza a casa relata menor necessidade de lembrar, distribuir e cobrar; outros adultos participam da gestão. |
| Compreensão do esforço | A escala de 1 a 3 é compreendida, inclusive o crédito integral para cada responsável de tarefa compartilhada. |
| Engajamento coletivo | Missões e recompensas motivam participação sem criar competição ou pressão por prazo. |
| Participação infantil | Crianças conseguem consultar tarefas e sinalizar realização, com foto opcional, e adultos entendem a confirmação e a conclusão compartilhada. |

Esses critérios orientam avaliação com famílias. Não há metas numéricas ou resultados de testes definidos neste documento.

## 12. Síntese da visão

O produto busca tornar as responsabilidades domésticas visíveis e compartilhadas. A organização de tarefas e rotinas estrutura a experiência; a carga diária ou semanal apoia a percepção de distribuição; e as conquistas coletivas incentivam a participação. O sucesso depende de ajudar a família a dividir também o trabalho de organizar e acompanhar a rotina.

## 13. Base e rastreabilidade

Esta versão preserva o contexto, o problema, os objetivos e os princípios do arquivo de origem `Documento_Visao_MVP 2.pdf`, ajustando seu escopo às decisões consolidadas da versão 1.0. O PDF é referência histórica; este documento contém a visão vigente sem exigir sua consulta.

Os comportamentos são detalhados nas [regras de negócio](01-regras-de-negocio.md), nos [requisitos funcionais e não funcionais](02-requisitos.md) e nos [casos de uso](03-casos-de-uso.md). As tabelas das seções 7 e 8 conectam a visão a esses documentos. Mudanças futuras de escopo devem ser refletidas no conjunto, conforme o [controle de versões](DOCUMENTACAO.md).

## Área Família

A tela Família apresenta diretamente carga e progresso por dia/semana, lista de membros, botão Gerar relatório PDF e, para Administradores, Adicionar membro. Selecionar uma pessoa abre seu detalhe com tarefas por dia/semana; edição de perfil e reenvio de convite ficam nesse detalhe, quando permitidos. A consulta da lista e das tarefas é adulta; a gestão continua exclusiva dos Administradores. O relatório permanece semanal.

## Continuidade e recuperação de acesso

A sessão dos convidados é mantida por refresh token sem expiração temporal, sujeito à revogação de acesso. Se a sessão for perdida, um Administrador gera novo link e senha de uso único para o mesmo perfil ativo, preservando histórico e vínculos. O Criador retorna pelo Sign in with Apple.

## Decisões de 2026-10-02

- **Kids:** tab bar com duas abas independentes, “Minhas tarefas” e “Missões e conquistas”. Meu perfil abre pelo avatar/cabeçalho, sem terceira aba. Adicionar foto à sinalização abre diretamente a câmera, com foto ainda opcional.
- **Perfil:** foto opcional e etiqueta/apelido para todos, inclusive Kids. O apelido é visível à família, mas só o titular acessa sua configuração e edição. O perfil mostra os badges recebidos coletivamente ao concluir missões com selo.
- **Períodos:** progresso pessoal e familiar e carga/sobrecarga alternam entre dia e semana. Kids continuam sem acesso à distribuição de carga familiar. Progresso e carga usam métricas distintas, detalhadas em RN61.
- **PDF semanal:** adultos geram relatório de segunda a domingo com gráficos de carga e progresso total da família, peso creditado e número de tarefas realizadas por membro. O relatório identifica período e geração; a semana atual é parcial.
- **Destaque semanal:** na segunda-feira, apurar o primeiro lugar em pontos da semana encerrada, notificar a pessoa e mostrar o resultado no app. Pontos correspondem aos pesos creditados; todos os empatados em primeiro são reconhecidos. Compartilhar via WhatsApp é opcional e convida a sugerir uma atividade em família.

Referências: RN61–65; RF61–66; UC18–19; TEL-051/052; UF-14/15. RF48, RF55, RN34 e os fluxos existentes também foram revisados.

## Histórico de versões

| Versão | Data | Alteração |
|---|---|---|
| 1.4 | 2026-10-02 | Família concentra indicadores, lista, inclusão de membros e PDF; detalhe do membro reúne tarefas Dia/Semana, edição e reenvio quando permitidos. RN60–61, RF60–61/RF66 e UC02/11/13/18 revisados. |
| 1.3 | 2026-10-02 | Duas abas Kids, câmera direta, foto/apelido e badges, progresso/carga Dia/Semana, PDF semanal e reconhecimento com WhatsApp; RN61–65, RF61–66, RNF26–27 e UC18–19. Empates e visibilidade do apelido confirmados. |
| 1.2 | 2026-10-01 | Área Família na navegação adulta, progresso coletivo diário e consulta por carrossel: RN60, RF60 e UC11. Design em elaboração na versão 1.0. |
| 1.1 | 2026-10-01 | Recuperação do mesmo perfil por novo convite e renovação sem expiração temporal, com revogação preservada: RN47, RF41, RF46, RF54, RNF22, UC02 e UC09. |
| 1.0 | 2026-10-01 | Primeira visão consolidada em Markdown. Alinhamento de perfis e permissões, acesso por convite e senha, frequências de rotina, tarefas compartilhadas, foto opcional, carga, navegação, missões sem prazo, recompensas e preservação de conquistas. Atualização do escopo e das exclusões. |
