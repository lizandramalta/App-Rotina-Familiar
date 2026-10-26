# Especificação dos casos de uso

**Projeto:** App de Organização Familiar — MVP  
**Versão:** 1.18\
**Data:** 2026-10-22\
**Situação:** base documental consolidada

[Projeto](../README.md) · [Visão do produto](00-visao-do-produto.md) · [Índice e versões](DOCUMENTACAO.md) · [Regras de negócio](01-regras-de-negocio.md) · [Requisitos](02-requisitos.md) · [Casos de uso](03-casos-de-uso.md) · [Diagramas UML](04-diagramas-de-caso-de-uso.md) · [Screen map](design/screen-map.md) · [Diagrama de classes](06-diagrama-de-classes.md)

Os 19 casos de uso abaixo descrevem os fluxos vigentes. As referências de regras são derivadas dos RF associados; os RNFs indicam as condições de qualidade aplicáveis.

[Consultar os diagramas UML](04-diagramas-de-caso-de-uso.md) — visão geral e quatro recortes por área.

## Atores

| Ator | Definição |
|---|---|
| Administrador | Gerencia membros, missões e recompensas; valida sinalizações Kids e executa as ações adultas de tarefas. |
| Criador da Família | Administrador com identificação especial, autenticação Apple e proteção contra remoção, rebaixamento e saída; não é um quarto perfil. |
| Membro | Perfil adulto com acesso às operações de tarefas, ao próprio perfil, à carga diária ou semanal e ao acompanhamento de missões. |
| Kids | Consulta tarefas e progresso diário/semanal, sinaliza com câmera opcional, edita foto/apelido próprios, consulta badges e recebe seu reconhecimento semanal. |
| Pessoa convidada | Pessoa que ainda irá efetivar o vínculo ao perfil previamente criado usando link e senha. |
| Serviço Apple | Sistema externo que participa da autenticação do Criador. |
| Agendador | Dispara a apuração automática semanal, independentemente de sessão aberta. |
| WhatsApp | Aplicativo externo em que a pessoa revisa e confirma o envio do destaque. |

## Condições comuns

Salvo nos fluxos de autenticação, criação de família e ingresso, o usuário deve possuir sessão válida associada a um perfil ativo da família. As permissões são verificadas em cada operação. A remoção do perfil revoga o acesso, mesmo por sessão anteriormente aberta. Falhas de gravação são informadas sem apresentar a operação como concluída.

## Rastreabilidade dos casos de uso

| Caso de uso | Objetivo | Requisitos funcionais |
|---|---|---|
| [UC01](#uc01) | Gerenciar família | [RF01](02-requisitos.md#rf01), [RF02](02-requisitos.md#rf02), [RF38](02-requisitos.md#rf38), [RF39](02-requisitos.md#rf39), [RF40](02-requisitos.md#rf40), [RF41](02-requisitos.md#rf41), [RF48](02-requisitos.md#rf48), [RF67](02-requisitos.md#rf67) |
| [UC02](#uc02) | Gerenciar membros | [RF02](02-requisitos.md#rf02), [RF03](02-requisitos.md#rf03), [RF04](02-requisitos.md#rf04), [RF05](02-requisitos.md#rf05), [RF06](02-requisitos.md#rf06), [RF40](02-requisitos.md#rf40), [RF41](02-requisitos.md#rf41), [RF54](02-requisitos.md#rf54) |
| [UC03](#uc03) | Validar conclusão de tarefa Kids | [RF25](02-requisitos.md#rf25), [RF26](02-requisitos.md#rf26), [RF55](02-requisitos.md#rf55), [RF56](02-requisitos.md#rf56) |
| [UC04](#uc04) | Autenticar com Apple | [RF37](02-requisitos.md#rf37), [RF39](02-requisitos.md#rf39) |
| [UC05](#uc05) | Gerenciar missões | [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF31](02-requisitos.md#rf31), [RF32](02-requisitos.md#rf32), [RF50](02-requisitos.md#rf50), [RF58](02-requisitos.md#rf58) |
| [UC06](#uc06) | Gerenciar itens de recompensas coletivas | [RF33](02-requisitos.md#rf33), [RF34](02-requisitos.md#rf34) |
| [UC07](#uc07) | Gerenciar tarefas | [RF07](02-requisitos.md#rf07), [RF08](02-requisitos.md#rf08), [RF09](02-requisitos.md#rf09), [RF10](02-requisitos.md#rf10), [RF15](02-requisitos.md#rf15), [RF16](02-requisitos.md#rf16), [RF27](02-requisitos.md#rf27), [RF58](02-requisitos.md#rf58), [RF59](02-requisitos.md#rf59) |
| [UC08](#uc08) | Definir recorrência de rotina | [RF13](02-requisitos.md#rf13), [RF14](02-requisitos.md#rf14) |
| [UC09](#uc09) | Ingressar por convite | [RF42](02-requisitos.md#rf42), [RF43](02-requisitos.md#rf43), [RF44](02-requisitos.md#rf44), [RF45](02-requisitos.md#rf45), [RF46](02-requisitos.md#rf46), [RF54](02-requisitos.md#rf54), [RF68](02-requisitos.md#rf68) |
| [UC10](#uc10) | Editar perfil | [RF48](02-requisitos.md#rf48), [RF62](02-requisitos.md#rf62), [RF65](02-requisitos.md#rf65) |
| [UC11](#uc11) | Visualizar minhas tarefas | [RF11](02-requisitos.md#rf11), [RF17](02-requisitos.md#rf17), [RF22](02-requisitos.md#rf22), [RF49](02-requisitos.md#rf49), [RF60](02-requisitos.md#rf60), [RF65](02-requisitos.md#rf65), [RF66](02-requisitos.md#rf66) |
| [UC12](#uc12) | Concluir tarefa | [RF12](02-requisitos.md#rf12), [RF47](02-requisitos.md#rf47), [RF56](02-requisitos.md#rf56) |
| [UC13](#uc13) | Visualizar carga diária ou semanal | [RF18](02-requisitos.md#rf18), [RF19](02-requisitos.md#rf19), [RF20](02-requisitos.md#rf20), [RF21](02-requisitos.md#rf21), [RF56](02-requisitos.md#rf56), [RF57](02-requisitos.md#rf57), [RF66](02-requisitos.md#rf66) |
| [UC14](#uc14) | Acompanhar missões e recompensas | [RF30](02-requisitos.md#rf30), [RF31](02-requisitos.md#rf31), [RF36](02-requisitos.md#rf36), [RF58](02-requisitos.md#rf58), [RF62](02-requisitos.md#rf62), [RF65](02-requisitos.md#rf65) |
| [UC15](#uc15) | Sinalizar tarefa como realizada | [RF23](02-requisitos.md#rf23), [RF24](02-requisitos.md#rf24), [RF55](02-requisitos.md#rf55), [RF56](02-requisitos.md#rf56) |
| [UC16](#uc16) | Resgatar recompensa da missão | [RF35](02-requisitos.md#rf35), [RF51](02-requisitos.md#rf51), [RF52](02-requisitos.md#rf52), [RF53](02-requisitos.md#rf53) |
| [UC17](#uc17) | Retornar tarefa concluída para Pendente | [RF57](02-requisitos.md#rf57), [RF58](02-requisitos.md#rf58), [RF59](02-requisitos.md#rf59) |
| [UC18](#uc18) | Gerar relatório semanal em PDF | [RF61](02-requisitos.md#rf61) |
| [UC19](#uc19) | Apurar e compartilhar destaque semanal | [RF63](02-requisitos.md#rf63), [RF64](02-requisitos.md#rf64) |

## UC01

**Modelo de classes:** [Tipos e rastreabilidade de UC01](06-diagrama-de-classes.md#rastreio-uc01).

**Backend:** [Contratos e garantias de UC01](architecture/backend-contracts.md#backend-uc01).

**Nome:** Gerenciar família

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Acesso, família e perfis](04-diagramas-de-caso-de-uso.md#02-acesso-familia-perfis)

**Requisitos funcionais:** [RF01](02-requisitos.md#rf01), [RF02](02-requisitos.md#rf02), [RF38](02-requisitos.md#rf38), [RF39](02-requisitos.md#rf39), [RF40](02-requisitos.md#rf40), [RF41](02-requisitos.md#rf41), [RF48](02-requisitos.md#rf48), [RF67](02-requisitos.md#rf67)\
**Regras relacionadas:** [RN01](01-regras-de-negocio.md#rn01), [RN07](01-regras-de-negocio.md#rn07), [RN09](01-regras-de-negocio.md#rn09), [RN28](01-regras-de-negocio.md#rn28), [RN44](01-regras-de-negocio.md#rn44), [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46), [RN63](01-regras-de-negocio.md#rn63), [RN65](01-regras-de-negocio.md#rn65)\
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF15](02-requisitos.md#rnf15), [RNF16](02-requisitos.md#rnf16)

**Objetivo:** criar/acessar a família pelo onboarding do Criador e permitir aos Administradores configurar seu fuso.

**Atores:** Criador na criação/retorno; qualquer Administrador na configuração do fuso.


**Pré-condição:** na criação/retorno, autenticação válida pelo Sign in with Apple; na configuração do fuso, sessão ativa de Administrador da família.

**Fluxo principal:**

1. O usuário conclui a autenticação.
2. O sistema verifica se há uma família vinculada ao seu identificador Apple.
3. Não havendo vínculo, o usuário informa o nome administrativo obrigatório e pode configurar foto e etiqueta/apelido opcionais para o próprio perfil. Ao escolher a foto, o sistema tenta enviá-la antes da criação, sem conceder acesso familiar; falha permite repetir ou continuar sem foto.
4. O usuário informa o nome e escolhe o fuso da família, inicialmente `America/Sao_Paulo`, e pode preparar zero ou mais membros com nome e papel no mesmo formulário. Adicionar, editar e retirar integrantes nesta etapa altera apenas o rascunho.
5. O sistema valida os dados e cria, na mesma operação, a família, o perfil do usuário como Administrador e Criador da Família e todos os membros preparados. A foto enviada só é vinculada ao próprio Criador após a criação confirmada; nenhum convite é gerado automaticamente.
6. O sistema registra a data de criação da família e abre a sessão do Criador. Sem membros iniciais, apresenta diretamente a área principal. Com membros, apresenta a etapa de convites para os perfis já criados.
7. Na etapa de convites, o Criador pode gerar explicitamente o primeiro convite de cada perfil, com compartilhamento direto e sem confirmação intermediária; pode também adiar os convites. Uma reemissão exige confirmação prévia dos efeitos sobre convite e sessão anteriores.
8. Ao concluir ou adiar os convites, o sistema apresenta a área principal do aplicativo.

**Alternativas e exceções:**

- Se já existir uma família vinculada, o sistema redireciona o usuário para ela, sem criar outra família.
- Nome do Criador, da família ou de membro inicial inválido deve ser corrigido antes da criação. Foto e etiqueta/apelido são opcionais; falha no envio da foto não impede o avanço.
- Falha em qualquer parte da criação não deixa família, Criador ou membros iniciais parcialmente persistidos. O conteúdo do formulário permanece disponível para corrigir ou tentar novamente, sem anunciar sucesso incerto como confirmado.
- O Criador pode criar a família sem adicionar membro e seguir diretamente à área principal. Cancelar o compartilhamento de um convite já emitido não desfaz o perfil de membro criado nem a emissão confirmada.
- Voltar da etapa de convites aos dados da família abre a família já criada em modo de edição, sem nova criação. Prosseguir sem mudanças não grava novamente; mudanças autorizadas são salvas na família e nos membros conforme as permissões administrativas, antes de retornar aos convites. Novos membros são incluídos pelo fluxo persistente normal. Alterar o fuso depois da criação segue Configurações da família e sua confirmação específica.

**Fluxo complementar — Configurar fuso:** Administrador abre Família → Configurações da família (TEL-053), escolhe o fuso e lê o informativo (MOD-012). Escolhe aplicação imediata ou no próximo ciclo, confirma e aguarda persistência. A tela informa fuso vigente e eventual alteração programada. Cancelamento não salva; falha preserva a configuração anterior. Transições e apuração seguem RN28 e RF67.

**Pós-condição:** família criada/acessível ou configuração de fuso autorizada salva.

## UC02

**Modelo de classes:** [Tipos e rastreabilidade de UC02](06-diagrama-de-classes.md#rastreio-uc02).

**Backend:** [Contratos e garantias de UC02](architecture/backend-contracts.md#backend-uc02).

**Nome:** Gerenciar membros

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Acesso, família e perfis](04-diagramas-de-caso-de-uso.md#02-acesso-familia-perfis)

**Requisitos funcionais:** [RF02](02-requisitos.md#rf02), [RF03](02-requisitos.md#rf03), [RF04](02-requisitos.md#rf04), [RF05](02-requisitos.md#rf05), [RF06](02-requisitos.md#rf06), [RF40](02-requisitos.md#rf40), [RF41](02-requisitos.md#rf41), [RF54](02-requisitos.md#rf54)  
**Regras relacionadas:** [RN01](01-regras-de-negocio.md#rn01), [RN02](01-regras-de-negocio.md#rn02), [RN03](01-regras-de-negocio.md#rn03), [RN04](01-regras-de-negocio.md#rn04), [RN05](01-regras-de-negocio.md#rn05), [RN06](01-regras-de-negocio.md#rn06), [RN07](01-regras-de-negocio.md#rn07), [RN08](01-regras-de-negocio.md#rn08), [RN10](01-regras-de-negocio.md#rn10), [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46), [RN47](01-regras-de-negocio.md#rn47)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF17](02-requisitos.md#rnf17), [RNF18](02-requisitos.md#rnf18), [RNF19](02-requisitos.md#rnf19), [RNF20](02-requisitos.md#rnf20), [RNF21](02-requisitos.md#rnf21), [RNF22](02-requisitos.md#rnf22)

**Objetivo:** criar e editar perfis, administrar permissões, remover membros e gerar convites.

**Ator:** Administrador.


**Pré-condição:** família existente e permissão de Administrador para operações persistentes de gestão e convite. A preparação de membros em UC01 ocorre antes da criação, como rascunho do futuro Criador, sem perfil ou sessão de Administrador e sem persistência própria.

**Entrada de edição/convite:** Família → selecionar item da lista → TEL-032; no onboarding, a etapa de convites apresenta os membros criados com a família. Consultar o detalhe e suas tarefas é permitido aos adultos por UC11; as ações administrativas seguem este caso de uso. A primeira emissão abre diretamente o compartilhamento após a ação explícita. Reenviar exige confirmação, emite novo link e senha, invalida os convites anteriores e revoga a sessão anterior do mesmo perfil, sem recriar o membro. O Criador retorna por Apple; a configuração de apelido só pode ser alterada pelo titular em UC10.

**Fluxo principal — Adicionar membro:**

1. O Administrador acessa Família (TEL-050) e aciona o botão Adicionar membro na própria tela.
2. Informa os dados do perfil e define sua configuração, incluindo o Modo Kids quando aplicável.
3. O sistema valida e salva o perfil na família.
4. O Administrador solicita explicitamente o convite para o perfil ativo.
5. Na primeira emissão, o sistema gera link e senha sem confirmação intermediária; na reemissão, informa os efeitos e exige confirmação antes de gerar as novas credenciais. Convites e sessão anteriores do perfil são invalidados na mesma operação da reemissão.
6. O sistema disponibiliza o link e a senha para envio conjunto à pessoa convidada.

**Variação — Onboarding inicial:** o futuro Criador prepara zero ou mais membros antes da criação da família em UC01; os perfis são persistidos junto com a família, sem convite automático. Com membros, a etapa seguinte oferece a primeira emissão por ação explícita e compartilhamento direto, ou permite adiar. Sem membros, UC01 segue diretamente à área principal. Voltar da etapa de convites aos dados da família permite editar a família existente e gerenciar seus membros conforme as permissões administrativas; não cria outra família nem repete gravação sem mudanças. Novos membros incluídos após a criação seguem o fluxo persistente normal.

**Alternativas e exceções:**

- Se um usuário perder a sessão, o Administrador pode selecionar seu perfil ativo existente e gerar um novo convite com link e senha de uso único. A recuperação preserva o perfil, o histórico, as tarefas e os vínculos; não exige adicionar outro membro.
- O Administrador pode editar os dados permitidos de outros perfis.
- Pode promover um Membro adulto a Administrador; perfis Kids devem sair desse modo antes da promoção.
- Pode rebaixar outro Administrador, exceto o Criador. Um Administrador também pode deixar seu próprio papel, exceto o Criador.
- Pode ativar ou desativar o Modo Kids; um Administrador não pode permanecer nesse modo.
- Ao remover um membro, o sistema revoga seu acesso à família, inclusive pelas sessões existentes; somente ele é retirado das tarefas futuras não concluídas/não protegidas, preservando os demais responsáveis e o histórico.
- O sistema impede remoção, rebaixamento e saída do Criador.

**Pós-condição:** a alteração autorizada está salva. Um perfil removido não pode mais consultar nem alterar os dados da família.

## UC03

**Modelo de classes:** [Tipos e rastreabilidade de UC03](06-diagrama-de-classes.md#rastreio-uc03).

**Backend:** [Contratos e garantias de UC03](architecture/backend-contracts.md#backend-uc03).

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

**Modelo de classes:** [Tipos e rastreabilidade de UC04](06-diagrama-de-classes.md#rastreio-uc04).

**Backend:** [Contratos e garantias de UC04](architecture/backend-contracts.md#backend-uc04).

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

- Sem família vinculada, o sistema disponibiliza o onboarding de perfil e família pelo [UC01](03-casos-de-uso.md#uc01).
- Cancelamento ou falha de autenticação não concede acesso.
- Os demais perfis ingressam por convite e senha, conforme [UC09](03-casos-de-uso.md#uc09).

**Pós-condição:** o Criador está autenticado e acessa sua família ou pode criá-la.

## UC05

**Modelo de classes:** [Tipos e rastreabilidade de UC05](06-diagrama-de-classes.md#rastreio-uc05).

**Backend:** [Contratos e garantias de UC05](architecture/backend-contracts.md#backend-uc05).

**Nome:** Gerenciar missões

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Missões e recompensas](04-diagramas-de-caso-de-uso.md#05-missoes-recompensas)

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF31](02-requisitos.md#rf31), [RF32](02-requisitos.md#rf32), [RF50](02-requisitos.md#rf50), [RF58](02-requisitos.md#rf58), [RF71](02-requisitos.md#rf71)  
**Regras relacionadas:** [RN16](01-regras-de-negocio.md#rn16), [RN35](01-regras-de-negocio.md#rn35), [RN36](01-regras-de-negocio.md#rn36), [RN37](01-regras-de-negocio.md#rn37), [RN38](01-regras-de-negocio.md#rn38), [RN39](01-regras-de-negocio.md#rn39), [RN40](01-regras-de-negocio.md#rn40), [RN50](01-regras-de-negocio.md#rn50), [RN51](01-regras-de-negocio.md#rn51), [RN53](01-regras-de-negocio.md#rn53), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59), [RN64](01-regras-de-negocio.md#rn64), [RN68](01-regras-de-negocio.md#rn68)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** criar e editar missões coletivas sem prazo, vinculadas a tarefas individuais.

**Ator:** Administrador. Demais perfis da família, inclusive Kids, podem consultar a missão (título, observação, tarefas vinculadas e status), sem ações de gestão.


**Pré-condição:** existência de tarefas da família disponíveis para vinculação.

**Fluxo principal — Criar missão:**

1. O Administrador seleciona criar missão e informa seus dados (título e observação opcional de até 250 caracteres).
2. Seleciona individualmente uma ou mais tarefas, mesmo quando pertencem à mesma rotina. Pode também criar uma tarefa nova a partir desse ponto, pelo fluxo já existente de criação de tarefa, que retorna com a nova tarefa pré-selecionada.
3. Confere as tarefas; não há campo de selo por missão. Os badges seguem os marcos fixos de participação em RN64.
4. O sistema estabelece como objetivo concluir todas as tarefas vinculadas, sem período de vigência ou prazo.
5. O Administrador confirma e o sistema salva a missão.
6. A missão permanece em andamento enquanto existir tarefa vinculada não concluída.
7. Quando todas estiverem concluídas, o sistema conclui a missão, registra participações e concede badges nos marcos atingidos e habilita o resgate da recompensa.

**Alternativas e exceções:**

- O Administrador pode editar os dados e vínculos de uma missão em andamento.
- O sistema impede salvar uma missão sem tarefas. A remoção da última exige substituição antes de salvar.
- Vincular uma tarefa não vincula sua rotina nem outras ocorrências presentes ou futuras.
- Remover uma tarefa dos vínculos de uma missão em andamento recalcula seu progresso; se todas as restantes estiverem concluídas, a missão é concluída.
- Uma missão concluída não pode ser editada nem ter seus vínculos alterados. Somente o resgate ainda disponível pode acrescentar a recompensa, pelo [UC16](03-casos-de-uso.md#uc16). A reabertura confirmada de uma tarefa vinculada pelo UC17 é a exceção: retorna a missão para Em andamento e reverte seus dados derivados.

**Pós-condição:** a missão possui ao menos uma tarefa; permanece em andamento ou está concluída com seus dados preservados. Não existe expiração por prazo.

## UC06

**Modelo de classes:** [Tipos e rastreabilidade de UC06](06-diagrama-de-classes.md#rastreio-uc06).

**Backend:** [Contratos e garantias de UC06](architecture/backend-contracts.md#backend-uc06).

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
4. Informa o título obrigatório da recompensa coletiva e, se desejar, uma descrição opcional.
5. Confirma o cadastro.
6. O sistema salva o item e o inclui entre as opções disponíveis nos próximos sorteios.

**Alternativas e exceções:**

- Título vazio após `trim`, com caracteres de controle ou acima de 60 caracteres não-espaço impede salvar até sua correção.
- Descrição acima de 255 caracteres, contando espaços, impede salvar até sua correção.
- Título personalizado já usado na mesma família após `trim`, sem distinguir maiúsculas/minúsculas, impede salvar até sua correção.
- O Administrador pode consultar os itens sem adicionar novos.

**Pós-condição:** o item adicionado pode ser sorteado. Seu cadastro não o vincula automaticamente a uma missão; esse vínculo ocorre somente após sorteio e aceitação no [UC16](03-casos-de-uso.md#uc16).

## UC07

**Modelo de classes:** [Tipos e rastreabilidade de UC07](06-diagrama-de-classes.md#rastreio-uc07).

**Backend:** [Contratos e garantias de UC07](architecture/backend-contracts.md#backend-uc07).

**Nome:** Gerenciar tarefas

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina)

**Requisitos funcionais:** [RF07](02-requisitos.md#rf07), [RF08](02-requisitos.md#rf08), [RF09](02-requisitos.md#rf09), [RF10](02-requisitos.md#rf10), [RF15](02-requisitos.md#rf15), [RF16](02-requisitos.md#rf16), [RF27](02-requisitos.md#rf27), [RF58](02-requisitos.md#rf58), [RF59](02-requisitos.md#rf59), [RF69](02-requisitos.md#rf69), [RF70](02-requisitos.md#rf70)  
**Regras relacionadas:** [RN11](01-regras-de-negocio.md#rn11), [RN12](01-regras-de-negocio.md#rn12), [RN13](01-regras-de-negocio.md#rn13), [RN17](01-regras-de-negocio.md#rn17), [RN18](01-regras-de-negocio.md#rn18), [RN19](01-regras-de-negocio.md#rn19), [RN20](01-regras-de-negocio.md#rn20), [RN30](01-regras-de-negocio.md#rn30), [RN38](01-regras-de-negocio.md#rn38), [RN50](01-regras-de-negocio.md#rn50), [RN53](01-regras-de-negocio.md#rn53), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59), [RN66](01-regras-de-negocio.md#rn66), [RN67](01-regras-de-negocio.md#rn67)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** criar, editar, atribuir, reatribuir e excluir tarefas conforme seu estado.

**Atores:** Administrador e Membro, conforme responsáveis da tarefa.


**Pré-condição:** permissão para gerenciamento de tarefas.

**Fluxo principal — Criar tarefa:**

1. O usuário seleciona criar tarefa.
2. Informa o título (1 a 60 caracteres visíveis) e o peso: 1 para pouco esforço, 2 para médio e 3 para alto.
3. Escolhe a data prevista, inicialmente hoje, sem restrição de passado/futuro ou criação da família, e opcionalmente seleciona responsáveis e uma observação de até 250 caracteres.
4. Escolhe tarefa única ou configura uma rotina pelo [UC08](03-casos-de-uso.md#uc08).
5. Confirma o cadastro.
6. O sistema valida os dados e salva a tarefa ou a rotina.

**Alternativas e exceções:**

- Uma edição individual afeta somente a tarefa selecionada; alterações de rotina alcançam apenas as tarefas futuras abrangidas e preservam os dados passados e os registros protegidos de missões concluídas.
- A atribuição pode ser alterada para um ou mais responsáveis ou removida, respeitando as proteções das tarefas vinculadas a missões concluídas.
- Na exclusão de tarefa de rotina, o usuário escolhe somente a selecionada ou ela e as futuras. O sistema preserva as ocorrências concluídas e informa quais registros não podem ser excluídos.
- Uma tarefa concluída não pode ser excluída diretamente. O sistema informa que, se vinculada a missão em andamento e não protegida por missão concluída, somente um Administrador pode retorná-la a Pendente pelo [UC17](03-casos-de-uso.md#uc17) antes da exclusão.
- Ao excluir tarefa não concluída vinculada a missão em andamento, o sistema remove o vínculo e recalcula o progresso. Se restarem apenas tarefas concluídas, a missão é concluída na mesma operação, conforme [RN38](01-regras-de-negocio.md#rn38), com participações, badges e resgate habilitado. Se ela for a única tarefa da missão, bloqueia a exclusão até que outra tarefa seja vinculada.
- O sistema impede excluir ou alterar uma tarefa quando isso modificar dados preservados de uma missão concluída.
- Título ausente, com mais de 60 caracteres visíveis ou peso fora de 1 a 3 e operações de gerenciamento por Kids são rejeitados.
- Concluída sem proteção admite edição individual de título, peso, data, responsáveis e observação. Informar os efeitos: créditos e progresso são recalculados, instante original da conclusão e auditoria são preservados. Sem responsáveis, não há crédito individual. Última edição válida efetivada no servidor prevalece, sem comparação de versão antiga (RN17).
- Editar uma tarefa Aguardando confirmação exige escolher, no mesmo salvamento, entre retornar a Pendente — descartando a sinalização corrente da criança — ou manter Aguardando confirmação com os dados atualizados e a sinalização corrente intacta (RN66). Excluir uma tarefa Aguardando confirmação remove a sinalização corrente junto com a tarefa, sem registrar confirmação ou recusa.

**Pós-condição:** a alteração permitida foi salva, sem exclusão direta de tarefas concluídas nem modificação de conquistas preservadas.

## UC08

**Modelo de classes:** [Tipos e rastreabilidade de UC08](06-diagrama-de-classes.md#rastreio-uc08).

**Backend:** [Contratos e garantias de UC08](architecture/backend-contracts.md#backend-uc08).

**Nome:** Definir recorrência de rotina

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina)

**Requisitos funcionais:** [RF13](02-requisitos.md#rf13), [RF14](02-requisitos.md#rf14), [RF70](02-requisitos.md#rf70)
**Regras relacionadas:** [RN11](01-regras-de-negocio.md#rn11), [RN14](01-regras-de-negocio.md#rn14), [RN16](01-regras-de-negocio.md#rn16), [RN17](01-regras-de-negocio.md#rn17), [RN67](01-regras-de-negocio.md#rn67)
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** configurar a geração recorrente de tarefas individuais.

**Atores:** Administrador e Membro.


**Pré-condição:** criação de tarefa ou edição de rotina.

**Fluxo principal:**

1. O usuário escolhe a data inicial em DatePicker, inicialmente hoje e sem limites de produto, pode informar observação opcional e acessa a repetição; não há data final obrigatória.
2. O sistema oferece: sem repetição, diária ou a cada 7, 14, 21 ou 28 dias.
3. O usuário escolhe a frequência e confirma.
4. O sistema salva a configuração e gera tarefas até o fim do mês seguinte, repondo o horizonte diariamente e em consulta quando necessário. Início além desse horizonte fica programado; datas passadas são respeitadas sem truncamento silencioso.
5. Cada tarefa recebe identificação e status próprios.

**Alternativas e exceções:**

- Sem repetição, o sistema cria uma tarefa única.
- Alterações no alcance “selecionada e futuras” incluem a ocorrência escolhida e as futuras elegíveis, respeitando o histórico e as proteções de missões concluídas.
- Não existe frequência mensal.
- A limitação de consulta do carrossel não interrompe a geração de tarefas futuras.

**Pós-condição:** a configuração está salva; concluir uma ocorrência não conclui as demais.

## UC09

**Modelo de classes:** [Tipos e rastreabilidade de UC09](06-diagrama-de-classes.md#rastreio-uc09).

**Backend:** [Contratos e garantias de UC09](architecture/backend-contracts.md#backend-uc09).

**Nome:** Ingressar por convite

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Acesso, família e perfis](04-diagramas-de-caso-de-uso.md#02-acesso-familia-perfis)

**Requisitos funcionais:** [RF42](02-requisitos.md#rf42), [RF43](02-requisitos.md#rf43), [RF44](02-requisitos.md#rf44), [RF45](02-requisitos.md#rf45), [RF46](02-requisitos.md#rf46), [RF54](02-requisitos.md#rf54), [RF68](02-requisitos.md#rf68)\
**Regras relacionadas:** [RN09](01-regras-de-negocio.md#rn09), [RN10](01-regras-de-negocio.md#rn10), [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46), [RN47](01-regras-de-negocio.md#rn47)\
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF04](02-requisitos.md#rnf04), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF17](02-requisitos.md#rnf17), [RNF18](02-requisitos.md#rnf18), [RNF19](02-requisitos.md#rnf19), [RNF20](02-requisitos.md#rnf20), [RNF21](02-requisitos.md#rnf21), [RNF22](02-requisitos.md#rnf22)

**Objetivo:** efetivar o vínculo ou recuperar o acesso ao mesmo perfil ativo mediante novo link e senha de ingresso.

**Atores:** pessoa convidada para perfil Membro, Kids ou Administrador promovido.


**Pré-condição:** perfil previamente criado e convite ainda disponível para ingresso.

**Fluxo principal:**

1. A pessoa abre o link. Sem app, é direcionada à loja e orientada a reabrir o link após instalar. Com sessão ativa, MOD-013 solicita confirmação da troca de acesso; cancelar mantém a sessão.
2. O sistema verifica o convite e solicita a senha de ingresso.
3. A pessoa informa a senha.
4. O sistema valida o link, a senha correspondente, o perfil, a família e a disponibilidade do convite.
5. O sistema efetiva o ingresso no perfil indicado, estabelece uma sessão ativa vinculada à instalação e só então substitui o acesso local, limpando dados anteriores. O membro anterior não é removido da sua família e nenhum histórico é migrado.
6. O sistema consome o convite e sua senha, impedindo outro ingresso com o mesmo conjunto.
7. O usuário acessa as funcionalidades permitidas para seu perfil.

**Alternativas e exceções:**

- Senha incorreta não efetiva o vínculo nem consome o convite como ingresso bem-sucedido. O sistema permite correção, respeitando os controles contra tentativas abusivas.
- Link inválido, já consumido ou associado a perfil removido não concede acesso.
- Tentativas simultâneas permitem somente um ingresso bem-sucedido.
- Nos acessos seguintes, a sessão é renovada por refresh token sem expiração temporal e dispensa o link e a senha de ingresso, respeitando a revogação de acesso.
- Se perder a sessão, a pessoa solicita um novo convite a um Administrador. O mesmo fluxo de link e senha recupera o acesso ao perfil ativo existente, preservando histórico, tarefas e vínculos.
- Perfil removido não pode recuperar acesso nem renovar sessão. O Criador retorna pelo Sign in with Apple (UC04), com redirecionamento à família existente (UC01).

**Recuperação de resposta perdida:** comprovar a tentativa e a instalação original permite recuperar o ingresso por dez minutos sem consumir novamente; depois é necessário novo convite. Consulta geral de estado não substitui essa recuperação de credenciais.

**Pós-condição:** perfil vinculado, sessão única criada e convite consumido. A senha serve exclusivamente para o ingresso, não como senha de login posterior.

## UC10

**Modelo de classes:** [Tipos e rastreabilidade de UC10](06-diagrama-de-classes.md#rastreio-uc10).

**Backend:** [Contratos e garantias de UC10](architecture/backend-contracts.md#backend-uc10).

**Nome:** Editar perfil

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Acesso, família e perfis](04-diagramas-de-caso-de-uso.md#02-acesso-familia-perfis)

**Requisitos funcionais:** [RF48](02-requisitos.md#rf48), [RF62](02-requisitos.md#rf62), [RF65](02-requisitos.md#rf65)  
**Regras relacionadas:** [RN33](01-regras-de-negocio.md#rn33), [RN63](01-regras-de-negocio.md#rn63), [RN64](01-regras-de-negocio.md#rn64)\
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF24](02-requisitos.md#rnf24), [RNF27](02-requisitos.md#rnf27)

**Objetivo:** alterar os dados editáveis do próprio perfil.

**Atores:** Administrador, Membro e Kids.


**Pré-condição:** perfil ativo com sessão válida.

**Fluxo principal:**

1. O usuário acessa Meu perfil pela navegação adulta ou pelo avatar/cabeçalho Kids; consulta foto, apelido (ou nome), papel, nome da família, total de missões com participação e badges cumulativos.
2. Ao selecionar editar, o sistema apresenta foto opcional por câmera ou galeria, etiqueta/apelido próprios e, para Administrador e Membro, o nome de identificação.
3. O usuário adiciona, substitui ou remove a foto e/ou altera o apelido (e o nome, se adulto) e confirma.
4. O sistema valida e salva as alterações.

**Alternativas e exceções:**

- Somente o titular acessa a configuração do apelido; outros membros, inclusive Administradores, podem vê-lo, mas não editá-lo.
- Sem foto, apresentar identificação padrão. Falha de upload mantém a foto anterior e oferece nova tentativa; cancelar não salva.
- Cada missão encerrada com participação creditada conta uma vez para os marcos cumulativos bronze 5, prata 10, ouro 25 e diamante 50. Selecionar um marco conquistado abre [TEL-054](design/screen-map.md#tel-054); marcos pendentes apenas exibem a meta correspondente e não são selecionáveis. TEL-054 mostra as missões contribuintes e permite abrir TEL-021; voltar restaura a origem. Sem badges, mostrar total e próximo marco, sem simular conquista. Não há concessão retroativa.
- Dados inválidos exigem correção; alterações de permissões são impedidas. Kids não podem ativar/desativar seu modo nem editar o nome por este fluxo.

**Pós-condição:** os dados permitidos estão atualizados, sem alteração indevida de permissões.

## UC11

**Modelo de classes:** [Tipos e rastreabilidade de UC11](06-diagrama-de-classes.md#rastreio-uc11).

**Backend:** [Contratos e garantias de UC11](architecture/backend-contracts.md#backend-uc11).

**Nome:** Visualizar minhas tarefas

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina) · [Participação Kids](04-diagramas-de-caso-de-uso.md#04-participacao-kids)

**Requisitos funcionais:** [RF11](02-requisitos.md#rf11), [RF17](02-requisitos.md#rf17), [RF22](02-requisitos.md#rf22), [RF49](02-requisitos.md#rf49), [RF60](02-requisitos.md#rf60), [RF65](02-requisitos.md#rf65), [RF66](02-requisitos.md#rf66)\
**Regras relacionadas:** [RN16](01-regras-de-negocio.md#rn16), [RN22](01-regras-de-negocio.md#rn22), [RN23](01-regras-de-negocio.md#rn23), [RN26](01-regras-de-negocio.md#rn26), [RN27](01-regras-de-negocio.md#rn27), [RN28](01-regras-de-negocio.md#rn28), [RN33](01-regras-de-negocio.md#rn33), [RN49](01-regras-de-negocio.md#rn49), [RN55](01-regras-de-negocio.md#rn55), [RN60](01-regras-de-negocio.md#rn60), [RN61](01-regras-de-negocio.md#rn61), [RN63](01-regras-de-negocio.md#rn63)\
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF04](02-requisitos.md#rnf04), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22)

**Objetivo:** consultar as próprias tarefas e o próprio progresso diário; para adultos, também consultar tarefas e progresso coletivo pela área Família, por dia ou semana.

**Atores:** Administrador, Membro e Kids.


**Pré-condição:** acesso válido ao perfil da família.

**Fluxo principal:**

1. O usuário abre o checklist.
2. O sistema seleciona o dia atual por padrão.
3. Apresenta apenas as tarefas próprias e seus estados conforme a visualização do perfil, sem mudar o estado efetivo nem as permissões da tarefa.
4. Apresenta o progresso diário do usuário.
5. O usuário escolhe a data de referência, navegando entre dias permitidos.
6. O sistema apresenta tarefas e progresso daquele dia, contando concluídas sobre o total previsto conforme RN61.

**Alternativas e exceções:**

- O intervalo permitido vai da data de criação da família até o último dia do mês corrente, inclusive.
- Dias futuros do mês corrente podem ser consultados. Datas anteriores à criação e meses seguintes são bloqueados.
- Kids alternam diretamente entre Minhas tarefas e Missões e conquistas pelo tab bar de duas abas (RF65).
- Dias sem tarefas são apresentados como tal, sem registros fictícios de conclusão.
- Na mudança de dia, o checklist passa a abrir no novo dia; tarefas não realizadas não geram penalidades.
- Na tarefa compartilhada entre adulto e Kids, a sinalização Kids muda o estado único para Aguardando confirmação. A lista pessoal do adulto corresponsável apresenta Pendente; a visualização pessoal Kids apresenta Aguardando confirmação. O progresso continua sem contar a tarefa como concluída, e as ações adultas seguem as permissões do estado efetivo.
- Kids visualizam somente seu próprio progresso diário e não acessam a área, o progresso nem a carga familiar.

**Consulta complementar — Família (Administrador e Membro):**

1. O adulto seleciona Família na navegação principal.
2. O sistema abre o dia atual e oferece Dia/Semana; apresenta concluídas/total de tarefas previstas no período, contando cada tarefa uma vez, inclusive compartilhadas ou sem responsável.
3. O adulto seleciona dia ou semana dentro dos limites de RN49 e RN61; o progresso acompanha o período.
4. Ao abrir as tarefas da família, o sistema mantém o período e permite consultar tarefas de outras pessoas e sem responsável. Gerenciar e concluir continuam sujeitos a UC07 e UC12.
5. A própria área apresenta a carga diária ou semanal por UC13 e o botão Gerar relatório PDF por UC18. Também apresenta a lista de membros: selecionar uma pessoa abre TEL-032 com suas tarefas por dia/semana. O detalhe herda o período e mantém o filtro por pessoa; voltar restaura o contexto da Família. Somente Administradores têm Adicionar membro na Família e, no detalhe, Editar perfil e Gerar/reenviar convite quando permitidos por UC02. Confirmações Kids continuam exclusivas dos Administradores.

Sem tarefas no período, o sistema informa essa condição sem divisão por zero. Tarefas aguardando confirmação não entram nas concluídas. Conclusão, reabertura e exclusão autorizadas atualizam o progresso. Kids não acessam esta área. UC11 também abrange a consulta familiar adulta por dia ou semana.

**Pós-condição:** o usuário consulta um período permitido sem alterar o estado das tarefas.

## UC12

**Modelo de classes:** [Tipos e rastreabilidade de UC12](06-diagrama-de-classes.md#rastreio-uc12).

**Backend:** [Contratos e garantias de UC12](architecture/backend-contracts.md#backend-uc12).

**Nome:** Concluir tarefa

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina) · [Participação Kids](04-diagramas-de-caso-de-uso.md#04-participacao-kids)

**Requisitos funcionais:** [RF12](02-requisitos.md#rf12), [RF47](02-requisitos.md#rf47), [RF56](02-requisitos.md#rf56)  
**Regras relacionadas:** [RN21](01-regras-de-negocio.md#rn21), [RN22](01-regras-de-negocio.md#rn22), [RN30](01-regras-de-negocio.md#rn30), [RN35](01-regras-de-negocio.md#rn35), [RN48](01-regras-de-negocio.md#rn48), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** registrar diretamente a conclusão integral de uma tarefa, mantendo os responsáveis existentes ou atribuindo o adulto quando não houver responsável.

**Atores:** Administrador e Membro.


**Pré-condição:** tarefa da família ainda não concluída. Quando houver responsável Kids, somente Administrador pode concluir manualmente, inclusive se aguarda confirmação.

**Fluxo principal:**

1. O usuário aciona o círculo da tarefa em TEL-010 ou abre o detalhe TEL-012 e aciona Concluir.
2. Se a tarefa tiver responsável Kids e o usuário for Membro, o sistema não oferece concluir. Caso contrário, envia a conclusão sem alerta.
3. O sistema mantém os responsáveis atuais; se não houver, atribui a tarefa ao adulto que conclui.
4. O sistema registra quem executou a ação e conclui a tarefa para todos os responsáveis finais.
5. Cada responsável final recebe o peso integral na carga; a tarefa conta uma única vez em cada missão vinculada.

**Alternativas e exceções:**

- **Sem responsável:** o sistema atribui automaticamente a tarefa ao usuário que conclui.
- **Usuário já responsável:** a conclusão mantém os responsáveis existentes e vale para todos.
- **Sinalização Kids existente:** somente Administrador pode avaliar a foto opcional, confirmar/recusar ou concluir manualmente. A conclusão encerra a pendência, preserva sinalização/foto para auditoria administrativa e vale para todos os responsáveis.
- **Membro diante de tarefa Kids:** pode visualizá-la na área Família, mas não pode concluí-la.
- **Conclusão simultânea:** o sistema registra somente uma conclusão válida, sem duplicar carga ou atribuições.

**Pós-condição:** tarefa concluída para todos os responsáveis finais. Quem apenas executou a ação, mantendo outros responsáveis, não recebe peso se não for um deles. Outras ocorrências da rotina não são alteradas.

## UC13

**Modelo de classes:** [Tipos e rastreabilidade de UC13](06-diagrama-de-classes.md#rastreio-uc13).

**Backend:** [Contratos e garantias de UC13](architecture/backend-contracts.md#backend-uc13).

**Nome:** Visualizar carga diária ou semanal

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina)

**Requisitos funcionais:** [RF18](02-requisitos.md#rf18), [RF19](02-requisitos.md#rf19), [RF20](02-requisitos.md#rf20), [RF21](02-requisitos.md#rf21), [RF56](02-requisitos.md#rf56), [RF57](02-requisitos.md#rf57), [RF66](02-requisitos.md#rf66)  
**Regras relacionadas:** [RN26](01-regras-de-negocio.md#rn26), [RN28](01-regras-de-negocio.md#rn28), [RN30](01-regras-de-negocio.md#rn30), [RN31](01-regras-de-negocio.md#rn31), [RN33](01-regras-de-negocio.md#rn33), [RN34](01-regras-de-negocio.md#rn34), [RN35](01-regras-de-negocio.md#rn35), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN60](01-regras-de-negocio.md#rn60), [RN61](01-regras-de-negocio.md#rn61)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF03](02-requisitos.md#rnf03), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** acompanhar a distribuição da carga entre os membros da família.

**Atores:** Administrador e Membro.


**Pré-condição:** permissão de consulta da carga diária ou semanal.

**Fluxo principal:**

1. O usuário consulta a carga diretamente na tela Família (TEL-050) e seleciona Dia ou Semana e uma data de referência.
2. O sistema preserva o período da origem; para Semana, considera segunda-feira a domingo.
3. Identifica as tarefas com conclusão válida no período.
4. Soma o peso integral de cada tarefa para cada responsável registrado em sua conclusão.
5. Calcula a carga total da família somando as cargas individuais.
6. Calcula a participação de cada membro dividindo sua carga pela carga total e multiplicando por 100.
7. Apresenta distribuição e equilíbrio, sem ranking.

**Alternativas e exceções:**

- Tarefas pendentes ou aguardando confirmação não entram no cálculo.
- A reabertura autorizada retira o peso de todos os responsáveis do dia e da semana da conclusão desfeita, inclusive se for uma semana anterior.
- Uma tarefa concluída não pode ser excluída diretamente. A exclusão depois da reabertura não produz nova subtração de carga.
- Sem carga no período, o sistema informa a ausência de conclusões e não divide por zero.
- Crédito válido de perfil removido permanece na carga histórica em linha “Membro removido”, sem expor dados pessoais.
- Kids não podem acessar esta visualização.
- Gerar relatório abre UC18 com a semana correspondente à data selecionada, mesmo se a consulta estava em Dia.
- O primeiro lugar semanal é apurado e consultado separadamente em UC19.

**Pós-condição:** a carga corresponde às conclusões válidas. Exemplo: uma tarefa de peso 3 com dois responsáveis adiciona 3 para cada um e 6 à carga total da família.

## UC14

**Modelo de classes:** [Tipos e rastreabilidade de UC14](06-diagrama-de-classes.md#rastreio-uc14).

**Backend:** [Contratos e garantias de UC14](architecture/backend-contracts.md#backend-uc14).

**Nome:** Acompanhar missões e recompensas

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Missões e recompensas](04-diagramas-de-caso-de-uso.md#05-missoes-recompensas)

**Requisitos funcionais:** [RF30](02-requisitos.md#rf30), [RF31](02-requisitos.md#rf31), [RF36](02-requisitos.md#rf36), [RF58](02-requisitos.md#rf58), [RF62](02-requisitos.md#rf62), [RF65](02-requisitos.md#rf65)  
**Regras relacionadas:** [RN26](01-regras-de-negocio.md#rn26), [RN33](01-regras-de-negocio.md#rn33), [RN35](01-regras-de-negocio.md#rn35), [RN36](01-regras-de-negocio.md#rn36), [RN38](01-regras-de-negocio.md#rn38), [RN39](01-regras-de-negocio.md#rn39), [RN43](01-regras-de-negocio.md#rn43), [RN51](01-regras-de-negocio.md#rn51), [RN52](01-regras-de-negocio.md#rn52), [RN53](01-regras-de-negocio.md#rn53), [RN55](01-regras-de-negocio.md#rn55), [RN58](01-regras-de-negocio.md#rn58), [RN63](01-regras-de-negocio.md#rn63), [RN64](01-regras-de-negocio.md#rn64)\
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF04](02-requisitos.md#rnf04), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF23](02-requisitos.md#rnf23), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** consultar o progresso das missões coletivas e suas recompensas.

**Atores:** Administrador, Membro e Kids.


**Pré-condição:** acesso às missões da família.

**Fluxo principal:**

1. O usuário acessa Missões e conquistas diretamente na navegação principal adulta ou no tab bar Kids e seleciona uma missão.
2. O sistema apresenta seus dados, tarefas vinculadas, participações e estado, sem prazo ou data de expiração.
3. Calcula o progresso dividindo a quantidade de tarefas vinculadas concluídas pelo total de tarefas vinculadas e multiplicando por 100.
4. Apresenta a missão em andamento enquanto houver tarefas não concluídas.
5. Quando todas estão concluídas, apresenta a missão concluída, a situação do resgate e as participações registradas; badges dos marcos atingidos aparecem em Meu perfil conforme RN64.
6. Se a recompensa já tiver sido aceita, apresenta o item registrado.

**Alternativas e exceções:**

- Tarefas Kids aguardando confirmação não contam como concluídas.
- Uma tarefa com vários responsáveis conta uma única vez no progresso da missão.
- A reabertura autorizada reduz o progresso das missões vinculadas. Quando a missão já estiver concluída, ela retorna para Em andamento, sem recompensa, participações ou badges derivados.
- Missões concluídas preservam seus dados e vínculos, exceto pela reabertura confirmada de tarefa vinculada no UC17.
- Somente Administradores acessam a ação de resgate pelo [UC16](03-casos-de-uso.md#uc16).
- Sem missões, o sistema apresenta essa situação.

**Pós-condição:** o usuário conhece o progresso e a situação da recompensa. Nenhuma missão expira por passagem do tempo.

## UC15

**Modelo de classes:** [Tipos e rastreabilidade de UC15](06-diagrama-de-classes.md#rastreio-uc15).

**Backend:** [Contratos e garantias de UC15](architecture/backend-contracts.md#backend-uc15).

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
2. Ao escolher adicionar foto, o aplicativo abre diretamente a câmera, solicitando permissão se necessário. A criança captura e revisa a foto, podendo refazer ou descartar.
3. A criança envia a sinalização, com ou sem foto.
4. O sistema registra quem sinalizou e altera a tarefa para Aguardando confirmação.
5. O sistema disponibiliza a sinalização e a foto, quando existente, para avaliação do Administrador.

**Alternativas e exceções:**

- A foto é opcional; não anexá-la não impede enviar a sinalização. Negativa de permissão, câmera indisponível ou captura cancelada retornam à sinalização com opção de continuar sem foto. Não há seletor câmera/galeria.
- Se o envio de uma foto falhar, o sistema informa que ela não foi salva e permite nova tentativa ou envio da sinalização sem foto.
- Kids não podem sinalizar tarefas das quais não sejam responsáveis.
- Tarefas já concluídas ou aguardando confirmação não recebem nova transição de status.
- Um adulto pode concluir manualmente pelo [UC12](03-casos-de-uso.md#uc12). A conclusão passa a valer para todos, inclusive a criança, independentemente de ter sido baseada na foto.

**Pós-condição:** a tarefa aguarda decisão, sem peso ou progresso parcial creditado à criança. A confirmação ou conclusão manual posterior conclui a tarefa inteira.

## UC16

**Modelo de classes:** [Tipos e rastreabilidade de UC16](06-diagrama-de-classes.md#rastreio-uc16).

**Backend:** [Contratos e garantias de UC16](architecture/backend-contracts.md#backend-uc16).

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
4. O aplicativo sorteia localmente um item do catálogo elegível e apresenta a animação; o resultado ainda não está resgatado.
5. O sistema apresenta o resultado e o Administrador o aceita.
6. O sistema verifica novamente a disponibilidade, registra a recompensa e encerra o resgate para toda a família.

**Alternativas e exceções:**

- O Administrador pode recusar o resultado e sortear novamente até aceitar.
- Sair sem aceitar mantém o resgate disponível e a missão concluída.
- Se outro Administrador já tiver aceitado uma recompensa, o sistema apresenta o registro existente e impede outro resgate.
- Falha de gravação não é apresentada como aceitação concluída.

**Pós-condição:** uma única recompensa foi registrada enquanto a missão permanecer concluída. Reabertura confirmada posterior de tarefa vinculada remove esse registro junto com os demais dados derivados do encerramento.

## UC17

**Modelo de classes:** [Tipos e rastreabilidade de UC17](06-diagrama-de-classes.md#rastreio-uc17).

**Backend:** [Contratos e garantias de UC17](architecture/backend-contracts.md#backend-uc17).

**Nome:** Retornar tarefa concluída para Pendente

**Diagramas:** [Visão geral do sistema](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina)

**Requisitos funcionais:** [RF57](02-requisitos.md#rf57), [RF58](02-requisitos.md#rf58), [RF59](02-requisitos.md#rf59)  
**Regras relacionadas:** [RN38](01-regras-de-negocio.md#rn38), [RN50](01-regras-de-negocio.md#rn50), [RN53](01-regras-de-negocio.md#rn53), [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Requisitos não funcionais:** [RNF01](02-requisitos.md#rnf01), [RNF02](02-requisitos.md#rnf02), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF08](02-requisitos.md#rnf08), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF14](02-requisitos.md#rnf14), [RNF22](02-requisitos.md#rnf22), [RNF25](02-requisitos.md#rnf25)

**Objetivo:** permitir a qualquer perfil desfazer uma conclusão acessível, inclusive quando isso reabre uma missão e remove seus dados derivados.

**Atores:** Administrador, Membro e Kids (somente tarefa própria).


**Pré-condições:** tarefa concluída e acessível ao ator.

**Fluxo principal:**

1. O ator aciona o círculo de uma tarefa concluída em Minhas tarefas (TEL-010/TEL-040, quando permitida) ou abre TEL-012 e solicita o retorno para Pendente.
2. O sistema verifica o perfil, o estado e os vínculos da tarefa.
3. Se houver missão concluída e/ou recompensa aceita, informa que a missão será reaberta e que recompensa, participações e badges derivados serão removidos; nos demais casos, informa os efeitos sobre carga e progresso.
4. O ator confirma quando o alerta for apresentado.
5. O sistema retorna a tarefa para Pendente, mantendo seus responsáveis.
6. O sistema retira o peso anteriormente creditado a cada responsável do dia e da semana correspondentes.
7. Recalcula o progresso das missões vinculadas e, se necessário, retorna cada missão concluída para Em andamento, removendo recompensa, participações e badges derivados na mesma transação.

**Alternativas e exceções:**

- Sem missão concluída ou recompensa aceita, a reabertura ocorre diretamente.
- Cancelamento do alerta mantém a conclusão.
- Após a reabertura, a exclusão pode ocorrer pelo [UC07](03-casos-de-uso.md#uc07), respeitando a exigência de ao menos uma tarefa por missão.

**Pós-condição:** tarefa pendente para todos os responsáveis, sem contribuição de sua conclusão anterior para carga ou progresso. Missões reabertas ficam sem recompensa, participações e badges derivados; não há preservação desse histórico.


## UC18

**Modelo de classes:** [Tipos e rastreabilidade de UC18](06-diagrama-de-classes.md#rastreio-uc18).

**Backend:** [Contratos e garantias de UC18](architecture/backend-contracts.md#backend-uc18).

**Nome:** Gerar relatório semanal em PDF

**Diagramas:** [Visão geral](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Tarefas e rotina](04-diagramas-de-caso-de-uso.md#03-tarefas-rotina)

**Requisitos funcionais:** [RF61](02-requisitos.md#rf61)  
**Regras relacionadas:** [RN62](01-regras-de-negocio.md#rn62)  
**Requisitos não funcionais:** RNF05–08, RNF10, RNF12–13, RNF22, RNF26–27.

**Objetivo:** exportar carga e progresso familiar de uma semana em PDF.

**Atores:** Administrador e Membro.

**Pré-condição:** sessão válida e acesso à família; semana atual ou passada com interseção com a existência da família.

**Fluxo principal:**

1. O adulto aciona Gerar relatório PDF na própria tela Minha família (TEL-050) e abre TEL-051.
2. Seleciona uma `referenceDate`; o servidor resolve a semana de segunda a domingo no fuso da família, e a data da origem sugere a semana correspondente.
3. O sistema identifica o período e, se atual, indica que o relatório é parcial até o momento da geração.
4. O adulto confirma gerar. O backend fornece um snapshot consistente; o aplicativo gera o PDF e monta gráficos de carga semanal por membro e progresso total da família, com concluídas/total e percentual.
5. Inclui tabela com o peso total creditado e o número de tarefas realizadas por membro, período, família, geração e explicação das métricas e do crédito compartilhado; crédito de removido aparece como “Membro removido” (RN62).
6. Disponibiliza o PDF para visualizar, salvar ou compartilhar por ação do usuário.

**Alternativas e exceções:**

- Sem dados, gerar com zeros e indicação “Sem tarefas”, sem divisão por zero.
- Semana futura é impedida. Semana da criação inclui tarefas retroativas existentes no período; não pressupõe ausência de dados anteriores à criação.
- Falha de geração informa erro e permite tentar de novo, preservando seleção; não apresentar arquivo incompleto.
- Cancelar geração ou compartilhamento retorna à origem sem alterar tarefas; abrir interface externa não confirma envio.
- Kids e usuários sem acesso à família não podem gerar o relatório.
- Alterações posteriores de tarefas não modificam um arquivo exportado; gerar novamente para consultar os valores atualizados.

**Pós-condição:** PDF referente ao período e ao momento de geração disponível, ou falha/cancelamento informado sem alterações nos dados da rotina.

## UC19

**Modelo de classes:** [Tipos e rastreabilidade de UC19](06-diagrama-de-classes.md#rastreio-uc19).

**Backend:** [Contratos e garantias de UC19](architecture/backend-contracts.md#backend-uc19).

**Nome:** Apurar e compartilhar destaque semanal

**Diagramas:** [Visão geral](04-diagramas-de-caso-de-uso.md#01-visao-geral) · [Destaque semanal](04-diagramas-de-caso-de-uso.md#06-destaque-semanal)

**Requisitos funcionais:** [RF63](02-requisitos.md#rf63), [RF64](02-requisitos.md#rf64)  
**Regras relacionadas:** [RN28](01-regras-de-negocio.md#rn28), [RN30](01-regras-de-negocio.md#rn30), [RN65](01-regras-de-negocio.md#rn65)  
**Requisitos não funcionais:** RNF01, RNF04–08, RNF10, RNF12–13, RNF22, RNF26–27.

**Objetivo:** reconhecer o primeiro lugar em pontos da semana encerrada e incentivar convivência familiar.

**Atores:** Agendador; pessoa reconhecida (Administrador, Membro ou Kids); WhatsApp no compartilhamento opcional.

**Pré-condição:** semana anterior encerrada no fuso de referência comum; consulta exige sessão válida do reconhecido. A apuração automática independe de sessão aberta.

**Fluxo principal:**

1. Às 00:00 de segunda-feira no fuso da família, o Agendador inicia a apuração do ciclo encerrado. Recupera atrasos/falhas sem depender do app e respeita as transições de RN28.
2. O sistema soma os pesos de conclusões válidas por responsável final, segundo RN30 e RN65.
3. Identifica a maior pontuação positiva. Em empate, reconhece todos os empatados no primeiro lugar.
4. Registra o resultado final e uma intenção única de notificar cada pessoa reconhecida. A fila persistente recupera falhas de envio; aceitação pelo provedor não comprova entrega ou leitura.
5. A pessoa abre a notificação ou o acesso ao destaque em Minhas tarefas; TEL-052 apresenta período, pontos e tarefas realizadas.
6. A tela convida: “Mande para sua família e sugira algo para vocês fazerem juntos.”
7. Se escolher compartilhar, o sistema prepara mensagem editável e abre o WhatsApp para a pessoa escolher o destinatário, revisar e confirmar o envio.

**Alternativas e exceções:**

- Sem pontos positivos, registrar ausência de vencedor, conforme RN65.
- Falha na apuração permite retentativa idempotente; não publicar resultado incompleto.
- Sem permissão de notificação externa ou falha de entrega, o destaque continua disponível no app.
- Sem sessão, concluir o acesso e revalidar a titularidade antes de mostrar o resultado; usuário removido não acessa.
- Sem WhatsApp, oferecer copiar mensagem. Cancelar ou voltar não desfaz o reconhecimento e não indica envio.
- Kids reconhecidos acessam a variante apropriada sem ganhar acesso à carga ou ao relatório familiar.
- Fuso configurável segue RN28. Edições e reaberturas posteriores não revisam o destaque finalizado nem emitem outra notificação; carga e novos PDFs usam os dados corrigidos.

**Pós-condição:** resultado semanal registrado e acessível ao reconhecido; compartilhamento é opcional e o envio é controlado pelo usuário no aplicativo externo.

## Histórico de versões

| Versão | Data | Alteração |
|---|---|---|
| 1.18 | 2026-10-26 | UC12 e UC17 permitem concluir/reabrir pelo círculo da lista pessoal; o restante da linha abre o detalhe. Permissões e efeitos mantidos. |
| 1.17 | 2026-10-22 | UC10: nome da família e papel na consulta do perfil; titular adulto edita o próprio nome, Kids não. Para SPEC-006 (SCRUM-52). |
| 1.16 | 2026-10-19 | UC07: exclusão que deixa só tarefas concluídas fecha a missão (RN38/RF59; SPEC-014/SPEC-007). UC01/UC02: foto antecipada, membros criados com a família, convites posteriores e edição sem segunda criação. UC11: apresentação por perfil da tarefa sinalizada, preservando estado único. |
| 1.15 | 2026-10-10 | UC18 adota `referenceDate` para semana e identifica crédito histórico como “Membro removido”. Para SPEC-019. |
| 1.14 | 2026-10-10 | UC13 preserva crédito histórico de perfil removido como “Membro removido”. Para SPEC-018. |
| 1.13 | 2026-10-10 | UC06 passa a detalhar título obrigatório, descrição opcional, limites e unicidade de item personalizado; catálogo inicial definido em RN42. Para SPEC-015. |
| 1.12 | 2026-10-07 | UC01 passa a cobrir perfil do Criador, família, adição opcional de membros e convite explícito antes da área principal; UC02 e UC04 registram a variação de onboarding. |
| 1.11 | 2026-10-07 | UC05 passa a admitir observação opcional na missão (RF71/RN68), atalho de criação de tarefa durante a vinculação e consulta explícita por todos os perfis, inclusive Kids. Para SPEC-014. |
| 1.10 | 2026-10-07 | UC12 conclui diretamente mantendo responsáveis ou atribuindo adulto sem responsável. UC17 libera reabertura no alcance do perfil e permite reabrir missão concluída, removendo recompensa, participações e badges derivados. |
| 1.9 | 2026-10-06 | UC12 restringe conclusão manual de tarefa com responsável Kids ao Administrador e preserva a evidência pendente para auditoria. Para SPEC-010. |
| 1.8 | 2026-10-06 | UC11 passa a definir consulta própria diária e consulta familiar adulta por Dia/Semana. Para SPEC-009. |
| 1.7 | 2026-10-06 | UC08 passa a registrar observação opcional na rotina, ausência de data final obrigatória e alcance inclusivo da ocorrência selecionada. Para SPEC-008. |
| 1.6 | 2026-10-06 | UC07 passa a citar o limite de título (1–60 caracteres), a observação opcional (RN67/RF70) e a escolha entre Pendente e Aguardando confirmação ao editar tarefa sinalizada, com remoção da sinalização ao excluir (RN66/RF69). Para SPEC-007. |
| 1.5 | 2026-10-05 | Pendências consolidadas: fuso, datas livres, edição de concluídas, participações/badges, convites e sessão única; RF67/68; arquitetura, modelo e design 1.1. |
| 1.4 | 2026-10-02 | Família concentra indicadores, lista, inclusão de membros e PDF; detalhe do membro reúne tarefas Dia/Semana, edição e reenvio quando permitidos. RN60–61, RF60–61/RF66 e UC02/11/13/18 revisados. |
| 1.3 | 2026-10-02 | Duas abas Kids, câmera direta, foto/apelido e badges, progresso/carga Dia/Semana, PDF semanal e reconhecimento com WhatsApp; RN61–65, RF61–66, RNF26–27 e UC18–19. Empates e visibilidade do apelido confirmados. |
| 1.2 | 2026-10-01 | Área Família na navegação adulta, progresso coletivo diário e consulta por carrossel: RN60, RF60 e UC11. Design em elaboração na versão 1.0. |
| 1.1 | 2026-10-01 | Recuperação do mesmo perfil por novo convite e renovação sem expiração temporal, com revogação preservada: RN47, RF41, RF46, RF54, RNF22, UC02 e UC09. |
| 1.0 | 2026-10-01 | Primeira versão consolidada, incluindo todas as decisões registradas até esta publicação e links para a visão e a apresentação do projeto. |

Complemento visual de 2026-10-01: adicionadas referências aos diagramas de UC01–UC17, mantendo a base funcional 1.0.
