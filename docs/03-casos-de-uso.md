# Especificação dos casos de uso

**Projeto:** App de Organização Familiar — MVP  
**Versão:** 1.2  
**Data:** 2026-10-01  
**Situação:** base documental consolidada

[Projeto](../README.md) · [Visão do produto](00-visao-do-produto.md) · [Índice e versões](DOCUMENTACAO.md) · [Regras de negócio](01-regras-de-negocio.md) · [Requisitos](02-requisitos.md) · [Casos de uso](03-casos-de-uso.md) · [Diagramas UML](04-diagramas-de-caso-de-uso.md) · [Screen map](design/screen-map.md)

Os 17 casos de uso abaixo descrevem os fluxos vigentes. As referências de regras são derivadas dos RF associados; os RNFs indicam as condições de qualidade aplicáveis.

[Consultar os diagramas UML](04-diagramas-de-caso-de-uso.md) — visão geral e quatro recortes por área.

## Atores

| Ator | Definição |
|---|---|
| Administrador | Gerencia membros, missões e recompensas; valida sinalizações Kids e executa as ações adultas de tarefas. |
| Criador da Família | Administrador com identificação especial, autenticação Apple e proteção contra remoção, rebaixamento e saída; não é um quarto perfil. |
| Membro | Perfil adulto com acesso às operações de tarefas, ao próprio perfil, à carga semanal e ao acompanhamento de missões. |
| Kids | Consulta suas tarefas e progresso, sinaliza realização com foto opcional e acompanha missões e recompensas. |
| Pessoa convidada | Pessoa que ainda irá efetivar o vínculo ao perfil previamente criado usando link e senha. |
| Serviço Apple | Sistema externo que participa da autenticação do Criador. |

## Condições comuns

Salvo nos fluxos de autenticação, criação de família e ingresso, o usuário deve possuir sessão válida associada a um perfil ativo da família. As permissões são verificadas em cada operação. A remoção do perfil revoga o acesso, mesmo por sessão anteriormente aberta. Falhas de gravação são informadas sem apresentar a operação como concluída.

## Rastreabilidade dos casos de uso

| Caso de uso | Objetivo | Requisitos funcionais |
|---|---|---|
| [UC01](#uc01) | Gerenciar família | [RF01](02-requisitos.md#rf01), [RF38](02-requisitos.md#rf38), [RF39](02-requisitos.md#rf39) |
| [UC02](#uc02) | Gerenciar membros | [RF02](02-requisitos.md#rf02), [RF03](02-requisitos.md#rf03), [RF04](02-requisitos.md#rf04), [RF05](02-requisitos.md#rf05), [RF06](02-requisitos.md#rf06), [RF40](02-requisitos.md#rf40), [RF41](02-requisitos.md#rf41), [RF54](02-requisitos.md#rf54) |
| [UC03](#uc03) | Validar conclusão de tarefa Kids | [RF25](02-requisitos.md#rf25), [RF26](02-requisitos.md#rf26), [RF55](02-requisitos.md#rf55), [RF56](02-requisitos.md#rf56) |
| [UC04](#uc04) | Autenticar com Apple | [RF37](02-requisitos.md#rf37), [RF39](02-requisitos.md#rf39) |
| [UC05](#uc05) | Gerenciar missões | [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF31](02-requisitos.md#rf31), [RF32](02-requisitos.md#rf32), [RF50](02-requisitos.md#rf50), [RF58](02-requisitos.md#rf58) |
| [UC06](#uc06) | Gerenciar itens de recompensas coletivas | [RF33](02-requisitos.md#rf33), [RF34](02-requisitos.md#rf34) |
| [UC07](#uc07) | Gerenciar tarefas | [RF07](02-requisitos.md#rf07), [RF08](02-requisitos.md#rf08), [RF09](02-requisitos.md#rf09), [RF10](02-requisitos.md#rf10), [RF15](02-requisitos.md#rf15), [RF16](02-requisitos.md#rf16), [RF27](02-requisitos.md#rf27), [RF58](02-requisitos.md#rf58), [RF59](02-requisitos.md#rf59) |
| [UC08](#uc08) | Definir recorrência de rotina | [RF13](02-requisitos.md#rf13), [RF14](02-requisitos.md#rf14) |
| [UC09](#uc09) | Ingressar por convite | [RF42](02-requisitos.md#rf42), [RF43](02-requisitos.md#rf43), [RF44](02-requisitos.md#rf44), [RF45](02-requisitos.md#rf45), [RF46](02-requisitos.md#rf46), [RF54](02-requisitos.md#rf54) |
| [UC10](#uc10) | Editar perfil | [RF48](02-requisitos.md#rf48) |
| [UC11](#uc11) | Visualizar minhas tarefas e consultar o dia da família | [RF60](02-requisitos.md#rf60), [RF11](02-requisitos.md#rf11), [RF17](02-requisitos.md#rf17), [RF22](02-requisitos.md#rf22), [RF49](02-requisitos.md#rf49) |
| [UC12](#uc12) | Concluir tarefa | [RF12](02-requisitos.md#rf12), [RF47](02-requisitos.md#rf47), [RF56](02-requisitos.md#rf56) |
| [UC13](#uc13) | Visualizar carga semanal | [RF18](02-requisitos.md#rf18), [RF19](02-requisitos.md#rf19), [RF20](02-requisitos.md#rf20), [RF21](02-requisitos.md#rf21), [RF56](02-requisitos.md#rf56), [RF57](02-requisitos.md#rf57) |
| [UC14](#uc14) | Acompanhar missões e recompensas | [RF30](02-requisitos.md#rf30), [RF31](02-requisitos.md#rf31), [RF36](02-requisitos.md#rf36), [RF58](02-requisitos.md#rf58) |
| [UC15](#uc15) | Sinalizar tarefa como realizada | [RF23](02-requisitos.md#rf23), [RF24](02-requisitos.md#rf24), [RF55](02-requisitos.md#rf55), [RF56](02-requisitos.md#rf56) |
| [UC16](#uc16) | Resgatar recompensa da missão | [RF35](02-requisitos.md#rf35), [RF51](02-requisitos.md#rf51), [RF52](02-requisitos.md#rf52), [RF53](02-requisitos.md#rf53) |
| [UC17](#uc17) | Retornar tarefa concluída para Pendente | [RF57](02-requisitos.md#rf57), [RF58](02-requisitos.md#rf58), [RF59](02-requisitos.md#rf59) |

## UC01

**Nome:** Gerenciar família

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Acesso, família e perfis](04-diagramas-de-caso-de-uso.md#02-acesso-familia-perfis)

**Requisitos funcionais:** [RF01](02-requisitos.md#rf01), [RF38](02-requisitos.md#rf38), [RF39](02-requisitos.md#rf39)  
**Regras relacionadas:** [RN01](01-regras-de-negocio.md#rn01), [RN09](01-regras-de-negocio.md#rn09), [RN44](01-regras-de-negocio.md#rn44)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF15](02-requisitos.md#rnf15), [RNF16](02-requisitos.md#rnf16)

**Objetivo:** criar uma família ou acessar a família já vinculada ao Criador.

**Ator:** usuário criador, identificado como Administrador após a criação.


**Pré-condição:** autenticação válida pelo Sign in with Apple.

**Fluxo principal:**

1. O usuário conclui a autenticação.
2. O sistema verifica se há uma família vinculada ao seu identificador Apple.
3. Não havendo vínculo, o usuário seleciona criar família e informa os dados solicitados.
4. O sistema valida os dados e cria a família.
5. O sistema associa o usuário à família como Administrador, com a identificação de Criador da Família.
6. O sistema registra a data de criação da família e apresenta sua área inicial.

**Alternativas e exceções:**

- Se já existir uma família vinculada, o sistema redireciona o usuário para ela, sem criar outra família.
- Dados obrigatórios inválidos devem ser corrigidos antes da criação.

**Pós-condição:** o usuário acessa sua família; se recém-criada, ela possui um Criador com perfil Administrador.

## UC02

**Nome:** Gerenciar membros

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Acesso, família e perfis](04-diagramas-de-caso-de-uso.md#02-acesso-familia-perfis)

**Requisitos funcionais:** [RF02](02-requisitos.md#rf02), [RF03](02-requisitos.md#rf03), [RF04](02-requisitos.md#rf04), [RF05](02-requisitos.md#rf05), [RF06](02-requisitos.md#rf06), [RF40](02-requisitos.md#rf40), [RF41](02-requisitos.md#rf41), [RF54](02-requisitos.md#rf54)  
**Regras relacionadas:** [RN01](01-regras-de-negocio.md#rn01), [RN02](01-regras-de-negocio.md#rn02), [RN03](01-regras-de-negocio.md#rn03), [RN04](01-regras-de-negocio.md#rn04), [RN05](01-regras-de-negocio.md#rn05), [RN06](01-regras-de-negocio.md#rn06), [RN07](01-regras-de-negocio.md#rn07), [RN08](01-regras-de-negocio.md#rn08), [RN10](01-regras-de-negocio.md#rn10), [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46), [RN47](01-regras-de-negocio.md#rn47)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF17](02-requisitos.md#rnf17), [RNF18](02-requisitos.md#rnf18), [RNF19](02-requisitos.md#rnf19), [RNF20](02-requisitos.md#rnf20), [RNF21](02-requisitos.md#rnf21), [RNF22](02-requisitos.md#rnf22)

**Objetivo:** criar e editar perfis, administrar permissões, remover membros e gerar convites.

**Ator:** Administrador.


**Pré-condição:** família existente e permissão de Administrador.

**Fluxo principal — Adicionar membro:**

1. O Administrador acessa o gerenciamento de membros e seleciona adicionar.
2. Informa os dados do perfil e define sua configuração, incluindo o Modo Kids quando aplicável.
3. O sistema valida e salva o perfil na família.
4. O Administrador solicita o convite.
5. O sistema gera um link e uma senha de ingresso vinculados àquela família e àquele perfil.
6. O sistema disponibiliza o link e a senha para envio conjunto à pessoa convidada.

**Alternativas e exceções:**

- Se um usuário perder a sessão, o Administrador pode selecionar seu perfil ativo existente e gerar um novo convite com link e senha de uso único. A recuperação preserva o perfil, o histórico, as tarefas e os vínculos; não exige adicionar outro membro.
- O Administrador pode editar os dados permitidos de outros perfis.
- Pode promover um Membro adulto a Administrador; perfis Kids devem sair desse modo antes da promoção.
- Pode rebaixar outro Administrador, exceto o Criador. Um Administrador também pode deixar seu próprio papel, exceto o Criador.
- Pode ativar ou desativar o Modo Kids; um Administrador não pode permanecer nesse modo.
- Ao remover um membro, o sistema revoga seu acesso à família, inclusive pelas sessões existentes; suas tarefas futuras ficam sem responsável e o histórico concluído é preservado.
- O sistema impede remoção, rebaixamento e saída do Criador.

**Pós-condição:** a alteração autorizada está salva. Um perfil removido não pode mais consultar nem alterar os dados da família.

## UC03

**Nome:** Validar conclusão de tarefa Kids

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Participação Kids](04-diagramas-de-caso-de-uso.md#04-participacao-kids)

**Requisitos funcionais:** [RF25](02-requisitos.md#rf25), [RF26](02-requisitos.md#rf26), [RF55](02-requisitos.md#rf55), [RF56](02-requisitos.md#rf56)  
**Regras relacionadas:** [RN22](01-regras-de-negocio.md#rn22), [RN23](01-regras-de-negocio.md#rn23), [RN24](01-regras-de-negocio.md#rn24), [RN25](01-regras-de-negocio.md#rn25), [RN26](01-regras-de-negocio.md#rn26), [RN30](01-regras-de-negocio.md#rn30), [RN35](01-regras-de-negocio.md#rn35), [RN54](01-regras-de-negocio.md#rn54), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF04](02-requisitos.md#rnf04), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF24](02-requisitos.md#rnf24), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** avaliar a sinalização de uma criança e confirmar ou recusar a realização da tarefa.

**Ator:** Administrador.


**Pré-condição:** tarefa aguardando confirmação após sinalização de um perfil Kids responsável.

**Fluxo principal:**

1. O Administrador abre a fila de confirmações e seleciona uma tarefa.
2. O sistema apresenta a tarefa, seus responsáveis, a criança que sinalizou e a foto, quando anexada.
3. O Administrador avalia a sinalização e confirma a realização.
4. O sistema verifica se a tarefa ainda aguarda decisão e registra quem confirmou.
5. O sistema conclui a tarefa para todos os responsáveis e a retira das filas de confirmação.
6. O sistema contabiliza o peso integral para cada responsável e atualiza as missões vinculadas, contando a tarefa uma única vez em cada missão.

**Alternativas e exceções:**

- A ausência de foto não impede a confirmação.
- Se o Administrador recusar, a tarefa volta a Pendente para todos, sem contribuição para a carga ou para o progresso de missões.
- Um Administrador ou Membro pode concluir manualmente a tarefa pelo [UC12](03-casos-de-uso.md#uc12), inclusive enquanto ela aguarda confirmação. Essa conclusão também vale para a criança.
- Se outra decisão válida ou conclusão manual já tiver sido registrada, o sistema apresenta o estado atual e impede processamento duplicado.

**Pós-condição:** a tarefa está concluída para todos os responsáveis ou voltou a Pendente; não há conclusão parcial por responsável.

## UC04

**Nome:** Autenticar com Apple

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Acesso, família e perfis](04-diagramas-de-caso-de-uso.md#02-acesso-familia-perfis)

**Requisitos funcionais:** [RF37](02-requisitos.md#rf37), [RF39](02-requisitos.md#rf39)  
**Regras relacionadas:** [RN44](01-regras-de-negocio.md#rn44)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF15](02-requisitos.md#rnf15), [RNF16](02-requisitos.md#rnf16)

**Objetivo:** autenticar o Criador e reconhecer sua associação à família.

**Ator principal:** Criador da Família ou usuário que irá criá-la.

**Ator de apoio:** serviço de autenticação da Apple.


**Pré-condição:** usuário na área de acesso destinada ao Criador.

**Fluxo principal:**

1. O usuário seleciona entrar com Apple.
2. O sistema inicia a integração oficial de autenticação.
3. O usuário conclui a autenticação junto à Apple.
4. O sistema valida o retorno e identifica o usuário.
5. Havendo família vinculada, o sistema concede acesso e redireciona para ela.

**Alternativas e exceções:**

- Sem família vinculada, o sistema disponibiliza a criação pelo [UC01](03-casos-de-uso.md#uc01).
- Cancelamento ou falha de autenticação não concede acesso.
- Os demais perfis ingressam por convite e senha, conforme [UC09](03-casos-de-uso.md#uc09).

**Pós-condição:** o Criador está autenticado e acessa sua família ou pode criá-la.

## UC05

**Nome:** Gerenciar missões

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Missões e recompensas](04-diagramas-de-caso-de-uso.md#05-missoes-recompensas)

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF31](02-requisitos.md#rf31), [RF32](02-requisitos.md#rf32), [RF50](02-requisitos.md#rf50), [RF58](02-requisitos.md#rf58)  
**Regras relacionadas:** [RN16](01-regras-de-negocio.md#rn16), [RN35](01-regras-de-negocio.md#rn35), [RN36](01-regras-de-negocio.md#rn36), [RN37](01-regras-de-negocio.md#rn37), [RN38](01-regras-de-negocio.md#rn38), [RN39](01-regras-de-negocio.md#rn39), [RN40](01-regras-de-negocio.md#rn40), [RN50](01-regras-de-negocio.md#rn50), [RN51](01-regras-de-negocio.md#rn51), [RN53](01-regras-de-negocio.md#rn53), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** criar e editar missões coletivas sem prazo, vinculadas a tarefas individuais.

**Ator:** Administrador.


**Pré-condição:** existência de tarefas da família disponíveis para vinculação.

**Fluxo principal — Criar missão:**

1. O Administrador seleciona criar missão e informa seus dados.
2. Seleciona individualmente uma ou mais tarefas, mesmo quando pertencem à mesma rotina.
3. Define um selo opcional.
4. O sistema estabelece como objetivo concluir todas as tarefas vinculadas, sem período de vigência ou prazo.
5. O Administrador confirma e o sistema salva a missão.
6. A missão permanece em andamento enquanto existir tarefa vinculada não concluída.
7. Quando todas estiverem concluídas, o sistema conclui a missão, concede o selo opcional e habilita o resgate da recompensa.

**Alternativas e exceções:**

- O Administrador pode editar os dados e vínculos de uma missão em andamento.
- O sistema impede salvar uma missão sem tarefas. A remoção da última exige substituição antes de salvar.
- Vincular uma tarefa não vincula sua rotina nem outras ocorrências presentes ou futuras.
- Remover uma tarefa dos vínculos de uma missão em andamento recalcula seu progresso; se todas as restantes estiverem concluídas, a missão é concluída.
- Uma missão concluída não pode ser editada nem ter seus vínculos alterados. Somente o resgate ainda disponível pode acrescentar a recompensa, pelo [UC16](03-casos-de-uso.md#uc16).

**Pós-condição:** a missão possui ao menos uma tarefa; permanece em andamento ou está concluída com seus dados preservados. Não existe expiração por prazo.

## UC06

**Nome:** Gerenciar itens de recompensas coletivas

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Missões e recompensas](04-diagramas-de-caso-de-uso.md#05-missoes-recompensas)

**Requisitos funcionais:** [RF33](02-requisitos.md#rf33), [RF34](02-requisitos.md#rf34)  
**Regras relacionadas:** [RN41](01-regras-de-negocio.md#rn41), [RN42](01-regras-de-negocio.md#rn42)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22)

**Objetivo:** permitir ao Administrador adicionar opções de recompensa que poderão ser sorteadas na roleta.

**Ator:** Administrador.


**Pré-condição:** permissão de Administrador.

**Fluxo principal:**

1. O Administrador acessa os itens disponíveis para sorteio.
2. O sistema apresenta os itens predefinidos pelo aplicativo e os personalizados já cadastrados.
3. O Administrador seleciona adicionar item de recompensa.
4. Informa a recompensa coletiva que deseja incluir.
5. Confirma o cadastro.
6. O sistema salva o item e o inclui entre as opções disponíveis nos próximos sorteios.

**Alternativas e exceções:**

- Dados obrigatórios incompletos impedem salvar até sua correção.
- O Administrador pode consultar os itens sem adicionar novos.

**Pós-condição:** o item adicionado pode ser sorteado. Seu cadastro não o vincula automaticamente a uma missão; esse vínculo ocorre somente após sorteio e aceitação no [UC16](03-casos-de-uso.md#uc16).

## UC07

**Nome:** Gerenciar tarefas

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina)

**Requisitos funcionais:** [RF07](02-requisitos.md#rf07), [RF08](02-requisitos.md#rf08), [RF09](02-requisitos.md#rf09), [RF10](02-requisitos.md#rf10), [RF15](02-requisitos.md#rf15), [RF16](02-requisitos.md#rf16), [RF27](02-requisitos.md#rf27), [RF58](02-requisitos.md#rf58), [RF59](02-requisitos.md#rf59)  
**Regras relacionadas:** [RN11](01-regras-de-negocio.md#rn11), [RN12](01-regras-de-negocio.md#rn12), [RN13](01-regras-de-negocio.md#rn13), [RN17](01-regras-de-negocio.md#rn17), [RN18](01-regras-de-negocio.md#rn18), [RN19](01-regras-de-negocio.md#rn19), [RN20](01-regras-de-negocio.md#rn20), [RN30](01-regras-de-negocio.md#rn30), [RN38](01-regras-de-negocio.md#rn38), [RN50](01-regras-de-negocio.md#rn50), [RN53](01-regras-de-negocio.md#rn53), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** criar, editar, atribuir, reatribuir e excluir tarefas conforme seu estado.

**Atores:** Administrador e Membro.


**Pré-condição:** permissão para gerenciamento de tarefas.

**Fluxo principal — Criar tarefa:**

1. O usuário seleciona criar tarefa.
2. Informa o título e o peso: 1 para pouco esforço, 2 para médio e 3 para alto.
3. Opcionalmente, seleciona um ou mais responsáveis.
4. Escolhe tarefa única ou configura uma rotina pelo [UC08](03-casos-de-uso.md#uc08).
5. Confirma o cadastro.
6. O sistema valida os dados e salva a tarefa ou a rotina.

**Alternativas e exceções:**

- Uma edição individual afeta somente a tarefa selecionada; alterações de rotina alcançam apenas as tarefas futuras abrangidas e preservam os dados passados e os registros protegidos de missões concluídas.
- A atribuição pode ser alterada para um ou mais responsáveis ou removida, respeitando as proteções das tarefas vinculadas a missões concluídas.
- Na exclusão de tarefa de rotina, o usuário escolhe somente a selecionada ou ela e as futuras. O sistema preserva as ocorrências concluídas e informa quais registros não podem ser excluídos.
- Uma tarefa concluída não pode ser excluída diretamente. O sistema informa que, se vinculada a missão em andamento e não protegida por missão concluída, somente um Administrador pode retorná-la a Pendente pelo [UC17](03-casos-de-uso.md#uc17) antes da exclusão.
- Ao excluir tarefa não concluída vinculada a missão em andamento, o sistema remove o vínculo e recalcula o progresso. Se ela for a única tarefa da missão, bloqueia a exclusão até que outra tarefa seja vinculada.
- O sistema impede excluir ou alterar uma tarefa quando isso modificar dados preservados de uma missão concluída.
- Título ausente, peso fora de 1 a 3 e operações de gerenciamento por Kids são rejeitados.

**Pós-condição:** a alteração permitida foi salva, sem exclusão direta de tarefas concluídas nem modificação de conquistas preservadas.

## UC08

**Nome:** Definir recorrência de rotina

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina)

**Requisitos funcionais:** [RF13](02-requisitos.md#rf13), [RF14](02-requisitos.md#rf14)  
**Regras relacionadas:** [RN11](01-regras-de-negocio.md#rn11), [RN14](01-regras-de-negocio.md#rn14), [RN16](01-regras-de-negocio.md#rn16), [RN17](01-regras-de-negocio.md#rn17)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** configurar a geração recorrente de tarefas individuais.

**Atores:** Administrador e Membro.


**Pré-condição:** criação de tarefa ou edição de rotina.

**Fluxo principal:**

1. O usuário acessa a configuração de repetição.
2. O sistema oferece: sem repetição, diária ou a cada 7, 14, 21 ou 28 dias.
3. O usuário escolhe a frequência e confirma.
4. O sistema salva a configuração e gera tarefas conforme o intervalo.
5. Cada tarefa recebe identificação e status próprios.

**Alternativas e exceções:**

- Sem repetição, o sistema cria uma tarefa única.
- Alterações de rotina afetam somente as tarefas futuras abrangidas, respeitando o histórico e as proteções de missões concluídas.
- Não existe frequência mensal.
- A limitação de consulta do carrossel não interrompe a geração de tarefas futuras.

**Pós-condição:** a configuração está salva; concluir uma ocorrência não conclui as demais.

## UC09

**Nome:** Ingressar por convite

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Acesso, família e perfis](04-diagramas-de-caso-de-uso.md#02-acesso-familia-perfis)

**Requisitos funcionais:** [RF42](02-requisitos.md#rf42), [RF43](02-requisitos.md#rf43), [RF44](02-requisitos.md#rf44), [RF45](02-requisitos.md#rf45), [RF46](02-requisitos.md#rf46), [RF54](02-requisitos.md#rf54)  
**Regras relacionadas:** [RN10](01-regras-de-negocio.md#rn10), [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46), [RN47](01-regras-de-negocio.md#rn47)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF04](02-requisitos.md#rnf04), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF17](02-requisitos.md#rnf17), [RNF18](02-requisitos.md#rnf18), [RNF19](02-requisitos.md#rnf19), [RNF20](02-requisitos.md#rnf20), [RNF21](02-requisitos.md#rnf21), [RNF22](02-requisitos.md#rnf22)

**Objetivo:** efetivar o vínculo ou recuperar o acesso ao mesmo perfil ativo mediante novo link e senha de ingresso.

**Atores:** pessoa convidada para perfil Membro, Kids ou Administrador promovido.


**Pré-condição:** perfil previamente criado e convite ainda disponível para ingresso.

**Fluxo principal:**

1. A pessoa abre o link recebido junto com a senha.
2. O sistema verifica o convite e solicita a senha de ingresso.
3. A pessoa informa a senha.
4. O sistema valida o link, a senha correspondente, o perfil, a família e a disponibilidade do convite.
5. O sistema efetiva o vínculo ao perfil indicado e cria sua sessão.
6. O sistema consome o convite e sua senha, impedindo outro ingresso com o mesmo conjunto.
7. O usuário acessa as funcionalidades permitidas para seu perfil.

**Alternativas e exceções:**

- Senha incorreta não efetiva o vínculo nem consome o convite como ingresso bem-sucedido. O sistema permite correção, respeitando os controles contra tentativas abusivas.
- Link inválido, já consumido ou associado a perfil removido não concede acesso.
- Tentativas simultâneas permitem somente um ingresso bem-sucedido.
- Nos acessos seguintes, a sessão é renovada por refresh token sem expiração temporal e dispensa o link e a senha de ingresso, respeitando a revogação de acesso.
- Se perder a sessão, a pessoa solicita um novo convite a um Administrador. O mesmo fluxo de link e senha recupera o acesso ao perfil ativo existente, preservando histórico, tarefas e vínculos.
- Perfil removido não pode recuperar acesso nem renovar sessão. O Criador retorna pelo Sign in with Apple (UC04), com redirecionamento à família existente (UC01).

**Pós-condição:** perfil vinculado, sessão criada e convite consumido. A senha serve exclusivamente para o ingresso, não como senha de login posterior.

## UC10

**Nome:** Editar perfil

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Acesso, família e perfis](04-diagramas-de-caso-de-uso.md#02-acesso-familia-perfis)

**Requisitos funcionais:** [RF48](02-requisitos.md#rf48)  
**Regras relacionadas:** Sem RN específica; aplica-se o RF48.  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22)

**Objetivo:** alterar os dados editáveis do próprio perfil.

**Atores:** Administrador e Membro.


**Pré-condição:** perfil ativo com sessão válida.

**Fluxo principal:**

1. O usuário acessa seu perfil e seleciona editar.
2. O sistema apresenta os campos permitidos.
3. O usuário altera os dados e confirma.
4. O sistema valida e salva as alterações.

**Alternativas e exceções:** dados inválidos exigem correção; alterações sem permissão são impedidas; cancelamento antes de salvar mantém os dados anteriores.

**Pós-condição:** os dados permitidos estão atualizados, sem alteração indevida de permissões.

## UC11

**Nome:** Visualizar minhas tarefas

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina) · [Participação Kids](04-diagramas-de-caso-de-uso.md#04-participacao-kids)

**Requisitos funcionais:** [RF60](02-requisitos.md#rf60), [RF11](02-requisitos.md#rf11), [RF17](02-requisitos.md#rf17), [RF22](02-requisitos.md#rf22), [RF49](02-requisitos.md#rf49)  
**Regras relacionadas:** [RN60](01-regras-de-negocio.md#rn60), [RN16](01-regras-de-negocio.md#rn16), [RN22](01-regras-de-negocio.md#rn22), [RN26](01-regras-de-negocio.md#rn26), [RN27](01-regras-de-negocio.md#rn27), [RN33](01-regras-de-negocio.md#rn33), [RN49](01-regras-de-negocio.md#rn49), [RN55](01-regras-de-negocio.md#rn55)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF04](02-requisitos.md#rnf04), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22)

**Objetivo:** consultar as próprias tarefas e o próprio progresso diário; para adultos, também consultar as tarefas e o progresso coletivo pela área Família.

**Atores:** Administrador, Membro e Kids.


**Pré-condição:** acesso válido ao perfil da família.

**Fluxo principal:**

1. O usuário abre o checklist.
2. O sistema seleciona o dia atual por padrão.
3. Apresenta as tarefas e os respectivos estados, respeitando as permissões do perfil.
4. Apresenta o progresso diário do usuário, independentemente de seu perfil.
5. O usuário navega pelo carrossel.
6. O sistema apresenta as tarefas e o progresso da data selecionada.

**Alternativas e exceções:**

- O intervalo permitido vai da data de criação da família até o último dia do mês corrente, inclusive.
- Dias futuros do mês corrente podem ser consultados. Datas anteriores à criação e meses seguintes são bloqueados.
- Dias sem tarefas são apresentados como tal, sem registros fictícios de conclusão.
- Na mudança de dia, o checklist passa a abrir no novo dia; tarefas não realizadas não geram penalidades.
- Kids visualizam seu próprio progresso diário, mas não a carga semanal da família.

**Consulta complementar — Família (Administrador e Membro):**

1. O adulto seleciona Família na navegação principal.
2. O sistema abre o dia atual e apresenta o progresso coletivo: tarefas concluídas dividido pelo total de tarefas daquele dia, contando cada tarefa individual uma vez, inclusive tarefas compartilhadas ou sem responsável.
3. O adulto navega pelo mesmo intervalo do carrossel de dias do checklist pessoal; o progresso acompanha a data selecionada.
4. Ao abrir as tarefas da família, o sistema mantém a data e permite consultar tarefas de outras pessoas e sem responsável. Gerenciar e concluir continuam sujeitos a UC07 e UC12.
5. A área oferece acesso à carga semanal por UC13. Somente Administradores também acessam gerenciamento de membros (UC02) e confirmações Kids (UC03).

Sem tarefas no dia, o sistema informa essa condição sem divisão por zero. Tarefas aguardando confirmação não entram nas concluídas. Conclusão, reabertura e exclusão autorizadas atualizam o progresso. Kids não acessam esta área. UC11 também abrange a consulta diária familiar adulta.

**Pós-condição:** o usuário consulta uma data permitida sem alterar o estado das tarefas.

## UC12

**Nome:** Concluir tarefa

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina) · [Participação Kids](04-diagramas-de-caso-de-uso.md#04-participacao-kids)

**Requisitos funcionais:** [RF12](02-requisitos.md#rf12), [RF47](02-requisitos.md#rf47), [RF56](02-requisitos.md#rf56)  
**Regras relacionadas:** [RN21](01-regras-de-negocio.md#rn21), [RN22](01-regras-de-negocio.md#rn22), [RN30](01-regras-de-negocio.md#rn30), [RN35](01-regras-de-negocio.md#rn35), [RN48](01-regras-de-negocio.md#rn48), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** registrar a conclusão integral de uma tarefa, mantendo ou substituindo seus responsáveis.

**Atores:** Administrador e Membro.


**Pré-condição:** tarefa da família ainda não concluída, inclusive quando aguarda confirmação de sinalização Kids.

**Fluxo principal:**

1. O usuário seleciona a tarefa e aciona concluir.
2. O sistema apresenta os responsáveis atuais.
3. Se o usuário não estiver entre eles, o sistema alerta que a conclusão será creditada aos responsáveis existentes e oferece mantê-los ou assumir a tarefa.
4. O usuário escolhe manter os responsáveis e confirma a conclusão.
5. O sistema registra quem executou a ação e conclui a tarefa para todos os responsáveis.
6. Cada responsável recebe o peso integral na carga; a tarefa conta uma única vez em cada missão vinculada.

**Alternativas e exceções:**

- **Assumir tarefa:** o sistema substitui todos os responsáveis pelo usuário que conclui. Somente ele recebe o peso dessa conclusão.
- **Sem responsável:** o sistema atribui automaticamente a tarefa ao usuário que conclui.
- **Usuário já responsável:** a conclusão mantém os responsáveis existentes e vale para todos.
- **Sinalização Kids existente:** o adulto pode avaliar a foto opcional ou concluir manualmente depois. A conclusão encerra a pendência de confirmação e vale também para os responsáveis Kids.
- **Cancelar:** nenhuma conclusão ou troca de responsável é salva.
- **Conclusão simultânea:** o sistema registra somente uma conclusão válida, sem duplicar carga ou atribuições.

**Pós-condição:** tarefa concluída para todos os responsáveis finais. Quem apenas executou a ação, mantendo outros responsáveis, não recebe peso se não for um deles. Outras ocorrências da rotina não são alteradas.

## UC13

**Nome:** Visualizar carga semanal

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina)

**Requisitos funcionais:** [RF18](02-requisitos.md#rf18), [RF19](02-requisitos.md#rf19), [RF20](02-requisitos.md#rf20), [RF21](02-requisitos.md#rf21), [RF56](02-requisitos.md#rf56), [RF57](02-requisitos.md#rf57)  
**Regras relacionadas:** [RN26](01-regras-de-negocio.md#rn26), [RN28](01-regras-de-negocio.md#rn28), [RN30](01-regras-de-negocio.md#rn30), [RN31](01-regras-de-negocio.md#rn31), [RN33](01-regras-de-negocio.md#rn33), [RN34](01-regras-de-negocio.md#rn34), [RN35](01-regras-de-negocio.md#rn35), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF03](02-requisitos.md#rnf03), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** acompanhar a distribuição da carga entre os membros da família.

**Atores:** Administrador e Membro.


**Pré-condição:** permissão de consulta da carga semanal.

**Fluxo principal:**

1. O usuário acessa a carga semanal.
2. O sistema considera a semana de segunda-feira a domingo.
3. Identifica as tarefas com conclusão válida no período.
4. Soma o peso integral de cada tarefa para cada responsável registrado em sua conclusão.
5. Calcula a carga total da família somando as cargas individuais.
6. Calcula a participação de cada membro dividindo sua carga pela carga total e multiplicando por 100.
7. Apresenta distribuição e equilíbrio, sem ranking.

**Alternativas e exceções:**

- Tarefas pendentes ou aguardando confirmação não entram no cálculo.
- A reabertura autorizada retira o peso de todos os responsáveis da semana da conclusão desfeita, inclusive se for uma semana anterior.
- Uma tarefa concluída não pode ser excluída diretamente. A exclusão depois da reabertura não produz nova subtração de carga.
- Sem carga na semana, o sistema informa a ausência de conclusões e não divide por zero.
- Kids não podem acessar esta visualização.

**Pós-condição:** a carga corresponde às conclusões válidas. Exemplo: uma tarefa de peso 3 com dois responsáveis adiciona 3 para cada um e 6 à carga total da família.

## UC14

**Nome:** Acompanhar missões e recompensas

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Missões e recompensas](04-diagramas-de-caso-de-uso.md#05-missoes-recompensas)

**Requisitos funcionais:** [RF30](02-requisitos.md#rf30), [RF31](02-requisitos.md#rf31), [RF36](02-requisitos.md#rf36), [RF58](02-requisitos.md#rf58)  
**Regras relacionadas:** [RN26](01-regras-de-negocio.md#rn26), [RN35](01-regras-de-negocio.md#rn35), [RN36](01-regras-de-negocio.md#rn36), [RN38](01-regras-de-negocio.md#rn38), [RN39](01-regras-de-negocio.md#rn39), [RN43](01-regras-de-negocio.md#rn43), [RN51](01-regras-de-negocio.md#rn51), [RN52](01-regras-de-negocio.md#rn52), [RN53](01-regras-de-negocio.md#rn53), [RN55](01-regras-de-negocio.md#rn55), [RN58](01-regras-de-negocio.md#rn58)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF04](02-requisitos.md#rnf04), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF23](02-requisitos.md#rnf23), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** consultar o progresso das missões coletivas e suas recompensas.

**Atores:** Administrador, Membro e Kids.


**Pré-condição:** acesso às missões da família.

**Fluxo principal:**

1. O usuário acessa as missões e seleciona uma delas.
2. O sistema apresenta seus dados, tarefas vinculadas e estado, sem prazo ou data de expiração.
3. Calcula o progresso dividindo a quantidade de tarefas vinculadas concluídas pelo total de tarefas vinculadas e multiplicando por 100.
4. Apresenta a missão em andamento enquanto houver tarefas não concluídas.
5. Quando todas estão concluídas, apresenta a missão concluída e a situação do resgate.
6. Se a recompensa já tiver sido aceita, apresenta o item registrado.

**Alternativas e exceções:**

- Tarefas Kids aguardando confirmação não contam como concluídas.
- Uma tarefa com vários responsáveis conta uma única vez no progresso da missão.
- A reabertura autorizada reduz o progresso das missões em andamento às quais a tarefa está vinculada.
- Missões concluídas preservam seus dados e vínculos.
- Somente Administradores acessam a ação de resgate pelo [UC16](03-casos-de-uso.md#uc16).
- Sem missões, o sistema apresenta essa situação.

**Pós-condição:** o usuário conhece o progresso e a situação da recompensa. Nenhuma missão expira por passagem do tempo.

## UC15

**Nome:** Sinalizar tarefa como realizada

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Participação Kids](04-diagramas-de-caso-de-uso.md#04-participacao-kids)

**Requisitos funcionais:** [RF23](02-requisitos.md#rf23), [RF24](02-requisitos.md#rf24), [RF55](02-requisitos.md#rf55), [RF56](02-requisitos.md#rf56)  
**Regras relacionadas:** [RN21](01-regras-de-negocio.md#rn21), [RN22](01-regras-de-negocio.md#rn22), [RN23](01-regras-de-negocio.md#rn23), [RN24](01-regras-de-negocio.md#rn24), [RN30](01-regras-de-negocio.md#rn30), [RN35](01-regras-de-negocio.md#rn35), [RN54](01-regras-de-negocio.md#rn54), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF04](02-requisitos.md#rnf04), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF24](02-requisitos.md#rnf24)

**Objetivo:** permitir à criança sinalizar sua realização da tarefa, opcionalmente com uma foto.

**Ator:** Kids.


**Pré-condição:** tarefa pendente da qual o perfil Kids é responsável.

**Fluxo principal:**

1. A criança seleciona a tarefa e informa que realizou sua parte.
2. O sistema oferece a opção de anexar uma foto.
3. A criança envia a sinalização, com ou sem foto.
4. O sistema registra quem sinalizou e altera a tarefa para Aguardando confirmação.
5. O sistema disponibiliza a sinalização e a foto, quando existente, para avaliação do Administrador.

**Alternativas e exceções:**

- A foto é opcional; não anexá-la não impede enviar a sinalização.
- Se o envio de uma foto falhar, o sistema informa que ela não foi salva e permite nova tentativa ou envio da sinalização sem foto.
- Kids não podem sinalizar tarefas das quais não sejam responsáveis.
- Tarefas já concluídas ou aguardando confirmação não recebem nova transição de status.
- Um adulto pode concluir manualmente pelo [UC12](03-casos-de-uso.md#uc12). A conclusão passa a valer para todos, inclusive a criança, independentemente de ter sido baseada na foto.

**Pós-condição:** a tarefa aguarda decisão, sem peso ou progresso parcial creditado à criança. A confirmação ou conclusão manual posterior conclui a tarefa inteira.

## UC16

**Nome:** Resgatar recompensa da missão

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Missões e recompensas](04-diagramas-de-caso-de-uso.md#05-missoes-recompensas)

**Requisitos funcionais:** [RF35](02-requisitos.md#rf35), [RF51](02-requisitos.md#rf51), [RF52](02-requisitos.md#rf52), [RF53](02-requisitos.md#rf53)  
**Regras relacionadas:** [RN36](01-regras-de-negocio.md#rn36), [RN38](01-regras-de-negocio.md#rn38), [RN42](01-regras-de-negocio.md#rn42), [RN43](01-regras-de-negocio.md#rn43), [RN52](01-regras-de-negocio.md#rn52), [RN53](01-regras-de-negocio.md#rn53)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF23](02-requisitos.md#rnf23), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** sortear e aceitar uma recompensa coletiva para uma missão concluída.

**Ator:** Administrador.


**Pré-condição:** missão concluída, ainda sem recompensa aceita.

**Fluxo principal:**

1. O Administrador acessa a missão e seleciona resgatar recompensa.
2. O sistema verifica a disponibilidade do resgate.
3. Apresenta a roleta com itens predefinidos e personalizados adicionados pelo Administrador.
4. O Administrador realiza o sorteio.
5. O sistema apresenta o resultado e o Administrador o aceita.
6. O sistema verifica novamente a disponibilidade, registra a recompensa e encerra o resgate para toda a família.

**Alternativas e exceções:**

- O Administrador pode recusar o resultado e sortear novamente até aceitar.
- Sair sem aceitar mantém o resgate disponível e a missão concluída.
- Se outro Administrador já tiver aceitado uma recompensa, o sistema apresenta o registro existente e impede outro resgate.
- Falha de gravação não é apresentada como aceitação concluída.

**Pós-condição:** uma única recompensa foi registrada. O resgate acrescenta esse registro sem modificar tarefas, progresso, selo ou demais dados preservados da missão concluída.

## UC17

**Nome:** Retornar tarefa concluída para Pendente

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina)

**Requisitos funcionais:** [RF57](02-requisitos.md#rf57), [RF58](02-requisitos.md#rf58), [RF59](02-requisitos.md#rf59)  
**Regras relacionadas:** [RN38](01-regras-de-negocio.md#rn38), [RN50](01-regras-de-negocio.md#rn50), [RN53](01-regras-de-negocio.md#rn53), [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** permitir ao Administrador desfazer uma conclusão em missão ainda em andamento, inclusive para possibilitar a exclusão posterior da tarefa.

**Ator:** Administrador.


**Pré-condições:** tarefa concluída, vinculada a pelo menos uma missão em andamento e não vinculada a nenhuma missão concluída.

**Fluxo principal:**

1. O Administrador seleciona a tarefa e solicita o retorno para Pendente.
2. O sistema verifica o perfil, o estado e os vínculos da tarefa.
3. Informa que a operação desfaz a conclusão para todos os responsáveis e altera a carga semanal e o progresso das missões em andamento.
4. O Administrador confirma.
5. O sistema retorna a tarefa para Pendente, mantendo seus responsáveis.
6. O sistema retira o peso anteriormente creditado a cada responsável da semana correspondente.
7. Recalcula o progresso das missões em andamento vinculadas à tarefa.

**Alternativas e exceções:**

- Se houver vínculo com qualquer missão concluída, o sistema bloqueia a operação e explica que os dados da conquista devem ser preservados.
- Se não houver vínculo com missão em andamento, a operação não está disponível neste escopo.
- Membros e Kids não podem executar a reabertura.
- Cancelamento mantém a conclusão.
- Após a reabertura, a exclusão pode ocorrer pelo [UC07](03-casos-de-uso.md#uc07), respeitando a exigência de ao menos uma tarefa por missão.

**Pós-condição:** tarefa pendente para todos os responsáveis, sem contribuição de sua conclusão anterior para a carga ou o progresso. O histórico da operação é preservado para consistência dos registros.


## Histórico de versões

| Versão | Data | Alteração |
|---|---|---|
| 1.2 | 2026-10-01 | Área Família na navegação adulta, progresso coletivo diário e consulta por carrossel: RN60, RF60 e UC11. Design em elaboração na versão 1.0. |
| 1.1 | 2026-10-01 | Recuperação do mesmo perfil por novo convite e renovação sem expiração temporal, com revogação preservada: RN47, RF41, RF46, RF54, RNF22, UC02 e UC09. |
| 1.0 | 2026-10-01 | Primeira versão consolidada, incluindo todas as decisões registradas até esta publicação e links para a visão e a apresentação do projeto. |

Complemento visual de 2026-10-01: adicionadas referências aos diagramas de UC01–UC17, mantendo a base funcional 1.0.
