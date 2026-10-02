# Requisitos funcionais e não funcionais

**Projeto:** App de Organização Familiar — MVP  
**Versão:** 1.2  
**Data:** 2026-10-01  
**Situação:** base documental consolidada

[Projeto](../README.md) · [Visão do produto](00-visao-do-produto.md) · [Índice e versões](DOCUMENTACAO.md) · [Regras de negócio](01-regras-de-negocio.md) · [Requisitos](02-requisitos.md) · [Casos de uso](03-casos-de-uso.md) · [Diagramas UML](04-diagramas-de-caso-de-uso.md) · [Screen map](design/screen-map.md)

RF descreve o comportamento que o sistema deve oferecer. RNF define condições de qualidade, segurança e integridade. As regras de negócio ficam no documento próprio; não é necessário consultar versões anteriores para interpretar esta base.

**Conteúdo:** 59 requisitos funcionais e 25 requisitos não funcionais.

## Índice

- [Requisitos funcionais](#requisitos-funcionais)
- [Requisitos não funcionais](#requisitos-nao-funcionais)

## Requisitos funcionais

### RF01

O sistema deve criar a família e atribuir ao criador o perfil Administrador e a identificação de Criador. Deve manter o vínculo único por usuário e redirecionar o Criador para a família existente quando já houver associação.

**Regras de negócio:** [RN01](01-regras-de-negocio.md#rn01), [RN09](01-regras-de-negocio.md#rn09)  
**Casos de uso:** [UC01](03-casos-de-uso.md#uc01)

### RF02

O sistema deve permitir somente a Administradores adicionar membros à família, criando os perfis que serão utilizados para o ingresso por convite.

**Regras de negócio:** [RN07](01-regras-de-negocio.md#rn07)  
**Casos de uso:** [UC02](03-casos-de-uso.md#uc02)

### RF03

O sistema deve permitir somente a Administradores editar os dados e o perfil de outros membros, respeitando as condições de promoção, rebaixamento e ativação ou desativação do Modo Kids.

**Regras de negócio:** [RN02](01-regras-de-negocio.md#rn02), [RN03](01-regras-de-negocio.md#rn03), [RN07](01-regras-de-negocio.md#rn07), [RN08](01-regras-de-negocio.md#rn08)  
**Casos de uso:** [UC02](03-casos-de-uso.md#uc02)

### RF04

O sistema deve permitir somente a Administradores remover membros, exceto o Criador. Deve revogar o acesso do removido, inclusive por sessões existentes, deixar suas tarefas futuras sem responsável e preservar o histórico concluído.

**Regras de negócio:** [RN05](01-regras-de-negocio.md#rn05), [RN07](01-regras-de-negocio.md#rn07), [RN10](01-regras-de-negocio.md#rn10)  
**Casos de uso:** [UC02](03-casos-de-uso.md#uc02)

### RF05

O sistema deve distinguir os perfis Administrador, Membro e Kids e identificar o Criador por uma flag. Deve aplicar as permissões de cada perfil e impedir a remoção, o rebaixamento ou a saída do Criador.

**Regras de negócio:** [RN01](01-regras-de-negocio.md#rn01), [RN02](01-regras-de-negocio.md#rn02), [RN03](01-regras-de-negocio.md#rn03), [RN04](01-regras-de-negocio.md#rn04), [RN05](01-regras-de-negocio.md#rn05), [RN06](01-regras-de-negocio.md#rn06)  
**Casos de uso:** [UC02](03-casos-de-uso.md#uc02)

### RF06

O sistema deve permitir somente a Administradores ativar ou desativar o Modo Kids de um perfil. Um Administrador não pode estar em Modo Kids, e um perfil Kids deve sair desse modo antes de ser promovido a Administrador.

**Regras de negócio:** [RN02](01-regras-de-negocio.md#rn02), [RN08](01-regras-de-negocio.md#rn08)  
**Casos de uso:** [UC02](03-casos-de-uso.md#uc02)

### RF07

O sistema deve permitir a Administradores e Membros criar tarefas com título e peso obrigatórios e responsável opcional. A criação deve oferecer tarefa única, sem repetição, ou a configuração de uma rotina que gere tarefas individuais.

**Regras de negócio:** [RN11](01-regras-de-negocio.md#rn11), [RN19](01-regras-de-negocio.md#rn19), [RN20](01-regras-de-negocio.md#rn20)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07)

### RF08

O sistema deve permitir a Administradores e Membros editar uma tarefa individual ou sua rotina, respeitando o alcance da alteração e preservando dados passados. Deve impedir mudanças que modifiquem registros preservados de missões concluídas.

**Regras de negócio:** [RN17](01-regras-de-negocio.md#rn17), [RN19](01-regras-de-negocio.md#rn19), [RN20](01-regras-de-negocio.md#rn20), [RN58](01-regras-de-negocio.md#rn58)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07)

### RF09

O sistema deve permitir excluir tarefas não concluídas e, em rotinas, selecionar somente a tarefa ou ela e as futuras, preservando ocorrências concluídas. Deve impedir exclusão direta de tarefa concluída e informar a possibilidade ou o impedimento de reabertura pelo [UC17](03-casos-de-uso.md#uc17). Deve respeitar os vínculos e as proteções das missões.

**Regras de negócio:** [RN18](01-regras-de-negocio.md#rn18), [RN19](01-regras-de-negocio.md#rn19), [RN20](01-regras-de-negocio.md#rn20), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07)

### RF10

O sistema deve permitir a Administradores e Membros atribuir ou reatribuir tarefas a um ou mais responsáveis ou deixá-las sem responsável. Deve impedir reatribuições que alterem dados preservados de missões concluídas.

**Regras de negócio:** [RN11](01-regras-de-negocio.md#rn11), [RN12](01-regras-de-negocio.md#rn12), [RN20](01-regras-de-negocio.md#rn20), [RN58](01-regras-de-negocio.md#rn58)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07)

### RF11

O sistema deve permitir consultar tarefas pelo carrossel, da criação da família até o último dia do mês corrente, respeitando o perfil, e bloquear datas fora desse intervalo.

**Regras de negócio:** [RN27](01-regras-de-negocio.md#rn27), [RN49](01-regras-de-negocio.md#rn49)  
**Casos de uso:** [UC11](03-casos-de-uso.md#uc11)

### RF12

O sistema deve permitir a Administradores e Membros concluir tarefas Pendentes ou Aguardando confirmação, mesmo atribuídas a outras pessoas. Deve oferecer manter os responsáveis ou assumir a tarefa quando o usuário não estiver entre eles, alertando sobre o crédito. A conclusão deve valer para todos os responsáveis finais da tarefa individual.

**Regras de negócio:** [RN21](01-regras-de-negocio.md#rn21), [RN22](01-regras-de-negocio.md#rn22), [RN48](01-regras-de-negocio.md#rn48), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56)  
**Casos de uso:** [UC12](03-casos-de-uso.md#uc12)

### RF13

O sistema deve permitir configurar a recorrência de uma rotina para gerar tarefas individuais. Cada tarefa gerada deve possuir identificação e status próprios, e a conclusão de uma delas não deve alterar as demais.

**Regras de negócio:** [RN11](01-regras-de-negocio.md#rn11), [RN14](01-regras-de-negocio.md#rn14), [RN16](01-regras-de-negocio.md#rn16), [RN17](01-regras-de-negocio.md#rn17)  
**Casos de uso:** [UC08](03-casos-de-uso.md#uc08)

### RF14

O sistema deve oferecer as opções de tarefa única sem repetição e de rotina diária ou a cada 7, 14, 21 ou 28 dias. Não deve oferecer frequência mensal.

**Regras de negócio:** [RN14](01-regras-de-negocio.md#rn14)  
**Casos de uso:** [UC08](03-casos-de-uso.md#uc08)

### RF15

O sistema deve exigir a definição do peso da tarefa e permitir somente os valores de 1 a 3. O peso informado deve ser utilizado no cálculo da carga após a conclusão da tarefa.

**Regras de negócio:** [RN11](01-regras-de-negocio.md#rn11), [RN13](01-regras-de-negocio.md#rn13), [RN30](01-regras-de-negocio.md#rn30)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07)

### RF16

O sistema deve apresentar a escala de peso com os significados de cada valor: 1 para pouco esforço, 2 para esforço médio e 3 para alto esforço.

**Regras de negócio:** [RN13](01-regras-de-negocio.md#rn13)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07)

### RF17

O sistema deve abrir o checklist no dia atual, exibir o estado único de cada tarefa e permitir navegar no intervalo de [RN49](01-regras-de-negocio.md#rn49).

**Regras de negócio:** [RN16](01-regras-de-negocio.md#rn16), [RN22](01-regras-de-negocio.md#rn22), [RN27](01-regras-de-negocio.md#rn27), [RN49](01-regras-de-negocio.md#rn49), [RN55](01-regras-de-negocio.md#rn55)  
**Casos de uso:** [UC11](03-casos-de-uso.md#uc11)

### RF18

O sistema deve calcular a carga de segunda-feira a domingo somando, para cada membro, os pesos integrais das tarefas com conclusão válida no período em que ele figure como responsável da conclusão. Deve ajustar a semana original quando uma conclusão for desfeita por reabertura autorizada.

**Regras de negócio:** [RN28](01-regras-de-negocio.md#rn28), [RN30](01-regras-de-negocio.md#rn30), [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57)  
**Casos de uso:** [UC13](03-casos-de-uso.md#uc13)

### RF19

O sistema deve excluir da carga tarefas Pendentes ou Aguardando confirmação e contabilizá-las somente após conclusão válida. Uma reabertura autorizada deve desfazer o crédito anterior para todos os responsáveis.

**Regras de negócio:** [RN26](01-regras-de-negocio.md#rn26), [RN30](01-regras-de-negocio.md#rn30), [RN57](01-regras-de-negocio.md#rn57)  
**Casos de uso:** [UC13](03-casos-de-uso.md#uc13)

### RF20

O sistema deve apresentar a Administradores e Membros a carga de todos e a participação de cada um na soma das cargas individuais, sem ranking e sem divisão por zero.

**Regras de negócio:** [RN30](01-regras-de-negocio.md#rn30), [RN31](01-regras-de-negocio.md#rn31), [RN33](01-regras-de-negocio.md#rn33), [RN34](01-regras-de-negocio.md#rn34)  
**Casos de uso:** [UC13](03-casos-de-uso.md#uc13)

### RF21

O sistema deve apresentar a distribuição da carga de forma que Administradores e Membros possam perceber sua concentração e o equilíbrio entre os membros. Essa apresentação não deve estabelecer competição nem classificar quem fez mais.

**Regras de negócio:** [RN31](01-regras-de-negocio.md#rn31), [RN34](01-regras-de-negocio.md#rn34)  
**Casos de uso:** [UC13](03-casos-de-uso.md#uc13)

### RF22

O sistema deve permitir a Kids consultar suas próprias tarefas da criação da família até o último dia do mês corrente, bloqueando datas fora desse intervalo.

**Regras de negócio:** [RN27](01-regras-de-negocio.md#rn27), [RN49](01-regras-de-negocio.md#rn49)  
**Casos de uso:** [UC11](03-casos-de-uso.md#uc11)

### RF23

O sistema deve permitir a Kids sinalizar a realização de tarefa sob sua responsabilidade, com foto opcional, sem produzir conclusão parcial ou imediata.

**Regras de negócio:** [RN21](01-regras-de-negocio.md#rn21), [RN23](01-regras-de-negocio.md#rn23), [RN54](01-regras-de-negocio.md#rn54), [RN55](01-regras-de-negocio.md#rn55)  
**Casos de uso:** [UC15](03-casos-de-uso.md#uc15)

### RF24

O sistema deve alterar de Pendente para Aguardando confirmação a tarefa sinalizada por Kids. Esse estado deve permanecer até confirmação, recusa ou conclusão manual válida por adulto.

**Regras de negócio:** [RN22](01-regras-de-negocio.md#rn22), [RN23](01-regras-de-negocio.md#rn23), [RN24](01-regras-de-negocio.md#rn24)  
**Casos de uso:** [UC15](03-casos-de-uso.md#uc15)

### RF25

O sistema deve permitir a Administradores visualizar a sinalização e a foto opcional, confirmar ou recusar, registrar quem confirmou e impedir decisões duplicadas sobre o mesmo estado. Confirmação conclui para todos; recusa retorna a Pendente; conclusão manual encerra a pendência de validação.

**Regras de negócio:** [RN24](01-regras-de-negocio.md#rn24), [RN25](01-regras-de-negocio.md#rn25), [RN54](01-regras-de-negocio.md#rn54), [RN55](01-regras-de-negocio.md#rn55)  
**Casos de uso:** [UC03](03-casos-de-uso.md#uc03)

### RF26

O sistema deve considerar a tarefa de Kids concluída após confirmação por Administrador ou conclusão manual por Administrador ou Membro. Antes disso, não deve gerar carga nem progresso concluído.

**Regras de negócio:** [RN22](01-regras-de-negocio.md#rn22), [RN23](01-regras-de-negocio.md#rn23), [RN26](01-regras-de-negocio.md#rn26), [RN55](01-regras-de-negocio.md#rn55)  
**Casos de uso:** [UC03](03-casos-de-uso.md#uc03)

### RF27

O sistema deve impedir que perfis Kids criem, editem ou excluam tarefas. Essas ações devem ficar disponíveis somente aos perfis autorizados a gerenciar tarefas.

**Regras de negócio:** [RN19](01-regras-de-negocio.md#rn19)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07)

### RF28

O sistema deve permitir somente a Administradores criar e gerenciar missões coletivas em andamento, sem prazo ou vigência e com ao menos uma tarefa individual vinculada. Deve impedir alterações em missões concluídas.

**Regras de negócio:** [RN35](01-regras-de-negocio.md#rn35), [RN36](01-regras-de-negocio.md#rn36), [RN37](01-regras-de-negocio.md#rn37), [RN40](01-regras-de-negocio.md#rn40), [RN50](01-regras-de-negocio.md#rn50), [RN51](01-regras-de-negocio.md#rn51), [RN58](01-regras-de-negocio.md#rn58)  
**Casos de uso:** [UC05](03-casos-de-uso.md#uc05)

### RF29

O sistema deve definir o objetivo coletivo da missão como concluir todas as tarefas vinculadas, sem prazo, metas individuais ou competição.

**Regras de negócio:** [RN35](01-regras-de-negocio.md#rn35), [RN36](01-regras-de-negocio.md#rn36), [RN40](01-regras-de-negocio.md#rn40), [RN50](01-regras-de-negocio.md#rn50), [RN51](01-regras-de-negocio.md#rn51)  
**Casos de uso:** [UC05](03-casos-de-uso.md#uc05)

### RF30

O sistema deve calcular o progresso pela quantidade de tarefas vinculadas concluídas dividida pelo total vinculado, multiplicada por 100. Cada tarefa deve contar uma única vez, independentemente do número de responsáveis. Tarefas aguardando confirmação não contam como concluídas.

**Regras de negócio:** [RN26](01-regras-de-negocio.md#rn26), [RN35](01-regras-de-negocio.md#rn35), [RN51](01-regras-de-negocio.md#rn51), [RN55](01-regras-de-negocio.md#rn55)  
**Casos de uso:** [UC14](03-casos-de-uso.md#uc14)

### RF31

O sistema deve concluir a missão quando todas as tarefas vinculadas estiverem concluídas e mantê-la em andamento enquanto houver tarefas não concluídas. Não deve expirar missões por tempo nem aplicar penalidades por demora.

**Regras de negócio:** [RN36](01-regras-de-negocio.md#rn36), [RN38](01-regras-de-negocio.md#rn38), [RN39](01-regras-de-negocio.md#rn39)  
**Casos de uso:** [UC05](03-casos-de-uso.md#uc05), [UC14](03-casos-de-uso.md#uc14)

### RF32

O sistema deve permitir que a missão tenha um selo opcional e concedê-lo à família quando ela for concluída. A concessão do selo não deve depender do sorteio ou da aceitação da recompensa.

**Regras de negócio:** [RN36](01-regras-de-negocio.md#rn36), [RN38](01-regras-de-negocio.md#rn38)  
**Casos de uso:** [UC05](03-casos-de-uso.md#uc05)

### RF33

O sistema deve disponibilizar recompensas de caráter coletivo, vinculadas às conquistas da família e destinadas a beneficiar seus membros em conjunto.

**Regras de negócio:** [RN41](01-regras-de-negocio.md#rn41)  
**Casos de uso:** [UC06](03-casos-de-uso.md#uc06)

### RF34

O sistema deve oferecer itens predefinidos para a roleta e permitir somente a Administradores adicionar itens personalizados que passarão a participar dos sorteios. Adicionar um item não deve atribuí-lo automaticamente a uma missão.

**Regras de negócio:** [RN41](01-regras-de-negocio.md#rn41), [RN42](01-regras-de-negocio.md#rn42)  
**Casos de uso:** [UC06](03-casos-de-uso.md#uc06)

### RF35

O sistema deve vincular a recompensa à missão somente após sua aceitação por um Administrador. Deve registrar a recompensa aceita nos dados da missão concluída para consulta posterior.

**Regras de negócio:** [RN36](01-regras-de-negocio.md#rn36), [RN38](01-regras-de-negocio.md#rn38), [RN43](01-regras-de-negocio.md#rn43), [RN53](01-regras-de-negocio.md#rn53)  
**Casos de uso:** [UC16](03-casos-de-uso.md#uc16)

### RF36

O sistema deve distinguir, na missão concluída, a disponibilidade de resgate e a existência de recompensa já resgatada. Deve exibir a recompensa aceita aos perfis que acompanham a missão e disponibilizar a ação de resgate somente a Administradores.

**Regras de negócio:** [RN38](01-regras-de-negocio.md#rn38), [RN43](01-regras-de-negocio.md#rn43), [RN52](01-regras-de-negocio.md#rn52), [RN53](01-regras-de-negocio.md#rn53)  
**Casos de uso:** [UC14](03-casos-de-uso.md#uc14)

### RF37

O sistema deve permitir ao Criador da Família autenticar-se por Sign in with Apple. Esse fluxo deve ser exclusivo do Criador; os demais perfis devem ingressar por convite.

**Regras de negócio:** [RN44](01-regras-de-negocio.md#rn44)  
**Casos de uso:** [UC04](03-casos-de-uso.md#uc04)

### RF38

Após autenticação Apple, o sistema deve permitir criar a família quando não existir vínculo e atribuir ao criador o papel de Administrador e sua identificação de Criador. Havendo vínculo, deve redirecioná-lo à família existente.

**Regras de negócio:** [RN01](01-regras-de-negocio.md#rn01), [RN09](01-regras-de-negocio.md#rn09), [RN44](01-regras-de-negocio.md#rn44)  
**Casos de uso:** [UC01](03-casos-de-uso.md#uc01)

### RF39

O sistema deve vincular a família ao identificador Apple do Criador obtido no fluxo de autenticação, permitindo reconhecer a associação entre esse usuário e sua família.

**Regras de negócio:** [RN44](01-regras-de-negocio.md#rn44)  
**Casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC04](03-casos-de-uso.md#uc04)

### RF40

O sistema deve permitir somente a Administradores criar os perfis dos demais membros antes do ingresso no aplicativo, inclusive perfis Kids. O perfil criado deve ser utilizado na geração do convite correspondente.

**Regras de negócio:** [RN07](01-regras-de-negocio.md#rn07), [RN45](01-regras-de-negocio.md#rn45)  
**Casos de uso:** [UC02](03-casos-de-uso.md#uc02)

### RF41

O sistema deve permitir ao Administrador gerar um link e uma senha de ingresso correspondentes a uma única família e a um único perfil previamente criado. Deve disponibilizá-los para envio conjunto e permitir somente um ingresso bem-sucedido. Em caso de perda da sessão, deve permitir gerar novo convite para o mesmo perfil ativo, preservando sua identidade, seu histórico e seus vínculos.

**Regras de negócio:** [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46), [RN47](01-regras-de-negocio.md#rn47)  
**Casos de uso:** [UC02](03-casos-de-uso.md#uc02)

### RF42

O sistema deve permitir o ingresso dos demais perfis mediante abertura do convite e informação da senha correspondente.

**Regras de negócio:** [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46)  
**Casos de uso:** [UC09](03-casos-de-uso.md#uc09)

### RF43

O sistema deve validar link, senha, associação à família e ao perfil, existência de perfil ativo e ausência de consumo anterior antes de conceder acesso.

**Regras de negócio:** [RN10](01-regras-de-negocio.md#rn10), [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46)  
**Casos de uso:** [UC09](03-casos-de-uso.md#uc09)

### RF44

O sistema deve consumir o convite e sua senha após o primeiro ingresso bem-sucedido, impedindo reutilização inclusive em tentativas simultâneas.

**Regras de negócio:** [RN46](01-regras-de-negocio.md#rn46)  
**Casos de uso:** [UC09](03-casos-de-uso.md#uc09)

### RF45

O sistema deve associar a sessão criada após o ingresso à família e ao perfil indicados pelo convite validado, aplicando as permissões correspondentes a esse perfil.

**Regras de negócio:** [RN47](01-regras-de-negocio.md#rn47)  
**Casos de uso:** [UC09](03-casos-de-uso.md#uc09)

### RF46

O sistema deve manter a sessão válida do membro após o ingresso, permitindo os acessos seguintes sem exigir novamente o link ou a senha de ingresso por renovação com refresh token sem expiração temporal, enquanto o perfil e o acesso permanecerem válidos. Se a sessão for perdida, deve orientar a obtenção de novo convite com um Administrador e permitir recuperar o mesmo perfil pelo ingresso com esse novo link e sua senha.

**Regras de negócio:** [RN46](01-regras-de-negocio.md#rn46), [RN47](01-regras-de-negocio.md#rn47)  
**Casos de uso:** [UC09](03-casos-de-uso.md#uc09)

### RF47

Ao concluir tarefa sem responsável, o sistema deve atribuí-la ao adulto que conclui. Ao optar por assumir uma tarefa atribuída a outros, deve substituir todos os responsáveis por esse usuário. Deve limitar a mudança à tarefa individual.

**Regras de negócio:** [RN48](01-regras-de-negocio.md#rn48), [RN56](01-regras-de-negocio.md#rn56)  
**Casos de uso:** [UC12](03-casos-de-uso.md#uc12)

### RF48

O sistema deve permitir a Membros e Administradores editar os dados do próprio perfil disponibilizados para edição, respeitando as permissões e as restrições aplicáveis ao perfil.

**Regras de negócio:** Sem RN específica; requisito autônomo de edição do próprio perfil.  
**Casos de uso:** [UC10](03-casos-de-uso.md#uc10)

### RF49

O sistema deve apresentar a todos os perfis seu próprio progresso diário, sem considerar tarefas aguardando confirmação como concluídas. Deve impedir que Kids consultem a carga semanal da família.

**Regras de negócio:** [RN26](01-regras-de-negocio.md#rn26), [RN33](01-regras-de-negocio.md#rn33)  
**Casos de uso:** [UC11](03-casos-de-uso.md#uc11)

### RF50

O sistema deve permitir selecionar cada tarefa individual da missão separadamente, exigir ao menos uma tarefa vinculada e impedir remoção ou exclusão da última sem substituição. Deve bloquear mudanças de vínculo em missões concluídas.

**Regras de negócio:** [RN16](01-regras-de-negocio.md#rn16), [RN35](01-regras-de-negocio.md#rn35), [RN36](01-regras-de-negocio.md#rn36), [RN50](01-regras-de-negocio.md#rn50), [RN51](01-regras-de-negocio.md#rn51), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Casos de uso:** [UC05](03-casos-de-uso.md#uc05)

### RF51

O sistema deve permitir somente a Administradores abrir a roleta de uma missão concluída e ainda sem resgate e sortear uma recompensa entre os itens predefinidos pelo aplicativo e os itens personalizados adicionados.

**Regras de negócio:** [RN38](01-regras-de-negocio.md#rn38), [RN42](01-regras-de-negocio.md#rn42), [RN43](01-regras-de-negocio.md#rn43), [RN52](01-regras-de-negocio.md#rn52)  
**Casos de uso:** [UC16](03-casos-de-uso.md#uc16)

### RF52

O sistema deve permitir ao Administrador aceitar o resultado do sorteio ou recusá-lo e sortear novamente até decidir aceitar. Se sair da roleta sem aceitar, a missão deve continuar concluída e com o resgate disponível.

**Regras de negócio:** [RN38](01-regras-de-negocio.md#rn38), [RN42](01-regras-de-negocio.md#rn42), [RN43](01-regras-de-negocio.md#rn43), [RN52](01-regras-de-negocio.md#rn52), [RN53](01-regras-de-negocio.md#rn53)  
**Casos de uso:** [UC16](03-casos-de-uso.md#uc16)

### RF53

O sistema deve encerrar o resgate da missão para toda a família após a aceitação da recompensa. Deve impedir qualquer Administrador de realizar outro sorteio ou resgate para essa mesma missão.

**Regras de negócio:** [RN53](01-regras-de-negocio.md#rn53)  
**Casos de uso:** [UC16](03-casos-de-uso.md#uc16)

### RF54

O sistema deve gerar a senha de ingresso com o convite, disponibilizar seu envio junto ao link e solicitá-la antes de efetivar o vínculo. A senha serve apenas ao ingresso com o respectivo convite e não deve ser exigida nos acessos posteriores com sessão válida. Um novo convite de recuperação exige sua própria senha e também admite um único uso bem-sucedido.

**Regras de negócio:** [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46), [RN47](01-regras-de-negocio.md#rn47)  
**Casos de uso:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

### RF55

O sistema deve permitir ao perfil Kids anexar opcionalmente uma foto à sinalização de realização e permitir sua visualização pelo Administrador na validação. A falta de foto não deve impedir sinalizar ou confirmar. Falhas de envio devem ser informadas.

**Regras de negócio:** [RN54](01-regras-de-negocio.md#rn54)  
**Casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC15](03-casos-de-uso.md#uc15)

### RF56

O sistema deve aplicar um único estado a todos os responsáveis, creditar o peso integral a cada responsável final e contar a tarefa uma única vez por missão. Deve distinguir quem executou a ação de quem recebeu o crédito.

**Regras de negócio:** [RN30](01-regras-de-negocio.md#rn30), [RN35](01-regras-de-negocio.md#rn35), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56)  
**Casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC15](03-casos-de-uso.md#uc15)

### RF57

O sistema deve permitir somente a Administradores retornar para Pendente uma tarefa concluída vinculada a missão em andamento, desde que não vinculada a missão concluída. Deve solicitar confirmação dos efeitos, manter os responsáveis e desfazer o crédito anterior na carga e no progresso das missões em andamento.

**Regras de negócio:** [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58)  
**Casos de uso:** [UC13](03-casos-de-uso.md#uc13), [UC17](03-casos-de-uso.md#uc17)

### RF58

O sistema deve impedir edição, exclusão ou mudança de vínculos da missão concluída e impedir operações sobre suas tarefas que modifiquem os dados preservados. Deve permitir apenas o registro da recompensa pelo resgate único ainda disponível, sem alterar a conquista.

**Regras de negócio:** [RN38](01-regras-de-negocio.md#rn38), [RN53](01-regras-de-negocio.md#rn53), [RN58](01-regras-de-negocio.md#rn58)  
**Casos de uso:** [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC14](03-casos-de-uso.md#uc14), [UC17](03-casos-de-uso.md#uc17)

### RF59

Ao excluir uma tarefa não concluída, o sistema deve remover seus vínculos de missões em andamento e recalcular o progresso. Deve impedir a operação quando afetar missão concluída ou deixar missão sem tarefas. A exclusão após reabertura não deve retirar carga novamente.

**Regras de negócio:** [RN50](01-regras-de-negocio.md#rn50), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07), [UC17](03-casos-de-uso.md#uc17)

### RF60

O sistema deve oferecer a Administradores e Membros uma área Família na navegação principal, com consulta do progresso total diário e acesso às tarefas de outras pessoas e sem responsável. Deve abrir no dia atual, aplicar o intervalo de RN49 e preservar a data selecionada ao abrir a subtela de tarefas da família.

Deve apresentar o progresso como tarefas concluídas divididas pelo total de tarefas da data selecionada, contando cada tarefa uma vez, sem ponderar peso nem multiplicar por responsáveis. Sem tarefas, deve informar essa condição. Tarefas Aguardando confirmação não contam como concluídas. Alterações válidas de estado ou exclusões devem atualizar o indicador.

A área deve oferecer acesso à carga semanal para ambos os perfis, mantendo o período de segunda a domingo. O gerenciamento de membros e a fila de confirmações Kids devem ser oferecidos somente ao Administrador, seguindo as permissões já definidas. A área Família não concede novas permissões a Kids.

**Regras de negócio:** [RN60](01-regras-de-negocio.md#rn60)  
**Casos de uso:** [UC11](03-casos-de-uso.md#uc11)

<a id="requisitos-nao-funcionais"></a>

## Requisitos não funcionais

Os requisitos transversais aplicam-se conforme a operação: por exemplo, persistência quando há gravação e proteção de sessão quando há acesso autenticado. RNF14 é uma restrição arquitetural para a implementação de todos os fluxos.

### RNF01

**Categoria:** Usabilidade

A interface deve apresentar as ações e informações necessárias às atividades de organização familiar com linguagem simples e navegação compreensível, evitando complexidade desnecessária para executar as tarefas previstas.

**Regras relacionadas:** Requisito transversal de qualidade; sem RN específica.  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

### RNF02

**Categoria:** Usabilidade

A interface deve apresentar de forma clara o título, o peso, o responsável quando houver e o status da tarefa, além de sua origem em uma rotina quando aplicável, permitindo compreender o que deve ser realizado e acompanhar sua situação.

**Regras relacionadas:** [RN11](01-regras-de-negocio.md#rn11), [RN13](01-regras-de-negocio.md#rn13), [RN22](01-regras-de-negocio.md#rn22), [RN55](01-regras-de-negocio.md#rn55)  
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC15](03-casos-de-uso.md#uc15), [UC17](03-casos-de-uso.md#uc17)

### RNF03

**Categoria:** Usabilidade

A apresentação da carga deve facilitar a compreensão da distribuição e da participação dos membros, utilizando linguagem e recursos visuais voltados ao equilíbrio familiar, sem ranking ou estímulo à competição.

**Regras relacionadas:** [RN30](01-regras-de-negocio.md#rn30), [RN31](01-regras-de-negocio.md#rn31), [RN34](01-regras-de-negocio.md#rn34)  
**Aplicação nos casos de uso:** [UC13](03-casos-de-uso.md#uc13)

### RNF04

**Categoria:** Usabilidade

A interface destinada ao perfil Kids deve usar linguagem e elementos visuais adequados a esse perfil, priorizar suas próprias tarefas e seu progresso diário e respeitar as restrições de acesso às demais funcionalidades.

**Regras relacionadas:** [RN19](01-regras-de-negocio.md#rn19), [RN33](01-regras-de-negocio.md#rn33)  
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC09](03-casos-de-uso.md#uc09), [UC11](03-casos-de-uso.md#uc11), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15)

### RNF05

**Categoria:** Acessibilidade

A interface não deve depender exclusivamente de cores para comunicar status, mensagens ou ações. Deve complementar as cores com texto, ícones identificáveis ou outro indicador que permita compreender a informação.

**Regras relacionadas:** Requisito transversal de qualidade; sem RN específica.  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

### RNF06

**Categoria:** Segurança

O sistema deve restringir o acesso aos dados à família associada ao usuário e às permissões de seu perfil, impedindo a consulta ou alteração de informações de outras famílias e de informações não autorizadas.

**Regras relacionadas:** [RN09](01-regras-de-negocio.md#rn09), [RN10](01-regras-de-negocio.md#rn10), [RN33](01-regras-de-negocio.md#rn33)  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

### RNF07

**Categoria:** Segurança

O sistema deve validar as permissões de perfil em cada operação protegida, sem depender apenas da visibilidade dos controles da interface. Isso inclui gerenciamento de membros, missões e tarefas, reabertura, adição de itens à roleta, sorteio e aceitação de recompensa.

**Regras relacionadas:** [RN02](01-regras-de-negocio.md#rn02), [RN03](01-regras-de-negocio.md#rn03), [RN04](01-regras-de-negocio.md#rn04), [RN05](01-regras-de-negocio.md#rn05), [RN07](01-regras-de-negocio.md#rn07), [RN08](01-regras-de-negocio.md#rn08), [RN19](01-regras-de-negocio.md#rn19), [RN20](01-regras-de-negocio.md#rn20), [RN21](01-regras-de-negocio.md#rn21), [RN24](01-regras-de-negocio.md#rn24), [RN37](01-regras-de-negocio.md#rn37), [RN42](01-regras-de-negocio.md#rn42), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58)  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

### RNF08

**Categoria:** Segurança

As comunicações que transportem dados de usuários, famílias, tarefas, missões, recompensas ou credenciais de acesso devem utilizar proteção criptográfica em trânsito para evitar sua exposição durante a transmissão.

**Regras relacionadas:** Requisito transversal de qualidade; sem RN específica.  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

### RNF09

**Categoria:** Integridade de dados

O sistema deve manter consistentes os estados, responsáveis, conclusões e vínculos de cada tarefa individual. Deve preservar o histórico das operações, respeitar os alcances de edição, exclusão e reabertura e impedir alterações nos dados preservados de missões concluídas.

**Regras relacionadas:** [RN10](01-regras-de-negocio.md#rn10), [RN16](01-regras-de-negocio.md#rn16), [RN17](01-regras-de-negocio.md#rn17), [RN18](01-regras-de-negocio.md#rn18), [RN48](01-regras-de-negocio.md#rn48), [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Aplicação nos casos de uso:** [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC17](03-casos-de-uso.md#uc17)

### RNF10

**Categoria:** Integridade da carga

O cálculo deve refletir as conclusões válidas, creditando o peso integral a cada responsável da conclusão. Deve distinguir o autor da ação dos beneficiários do crédito, excluir tarefas pendentes ou aguardando confirmação e desfazer o crédito anterior exatamente uma vez em reabertura autorizada.

**Regras relacionadas:** [RN26](01-regras-de-negocio.md#rn26), [RN28](01-regras-de-negocio.md#rn28), [RN30](01-regras-de-negocio.md#rn30), [RN31](01-regras-de-negocio.md#rn31), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56), [RN57](01-regras-de-negocio.md#rn57)  
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC07](03-casos-de-uso.md#uc07), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC17](03-casos-de-uso.md#uc17)

### RNF11

**Categoria:** Consistência da conclusão

Confirmação, recusa, conclusão manual e reabertura devem respeitar o estado corrente e ser consistentes sob concorrência. Não podem gerar conclusões, créditos ou decisões duplicadas. A sinalização Kids, com ou sem foto, não deve gerar conclusão parcial.

**Regras relacionadas:** [RN22](01-regras-de-negocio.md#rn22), [RN23](01-regras-de-negocio.md#rn23), [RN24](01-regras-de-negocio.md#rn24), [RN26](01-regras-de-negocio.md#rn26), [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57)  
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC12](03-casos-de-uso.md#uc12), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC17](03-casos-de-uso.md#uc17)

### RNF12

**Categoria:** Confiabilidade

O sistema não deve apresentar uma alteração como salva quando sua persistência falhar. Deve informar a falha ao usuário, evitando que a perda de dados ocorra sem indicação perceptível.

**Regras relacionadas:** Requisito transversal de qualidade; sem RN específica.  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

### RNF13

**Categoria:** Responsividade

As operações de rede não devem bloquear a interface. Durante o processamento, a interface deve permanecer responsiva e apresentar o estado da operação para que o usuário compreenda seu andamento ou eventual falha.

**Regras relacionadas:** Requisito transversal de qualidade; sem RN específica.  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

### RNF14

**Categoria:** Arquitetura

A organização do sistema deve manter separadas as responsabilidades dos domínios de família, tarefas e rotinas, carga semanal, missões, recompensas e acesso, permitindo sua manutenção sem misturar regras de negócio de áreas distintas.

**Regras relacionadas:** Requisito transversal de qualidade; sem RN específica.  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

### RNF15

**Categoria:** Segurança

A autenticação do Criador deve utilizar a integração oficial do Sign in with Apple e os mecanismos de validação previstos por essa integração.

**Regras relacionadas:** [RN44](01-regras-de-negocio.md#rn44)  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC04](03-casos-de-uso.md#uc04)

### RNF16

**Categoria:** Privacidade

O identificador Apple usado para vincular a família ao Criador deve ser protegido contra acesso ou divulgação não autorizados e utilizado no contexto de autenticação e associação do usuário à família.

**Regras relacionadas:** [RN44](01-regras-de-negocio.md#rn44)  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC04](03-casos-de-uso.md#uc04)

### RNF17

**Categoria:** Proteção das credenciais de ingresso

Tokens de convite e senhas de ingresso devem ser gerados de forma imprevisível e protegidos contra acesso não autorizado. A senha deve ser armazenada de forma que sua validação não exija manter uma cópia legível persistente.

**Regras relacionadas:** [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46)  
**Aplicação nos casos de uso:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

### RNF18

**Categoria:** Validação de ingresso

Link, senha, disponibilidade do convite e associação ao perfil ativo e à família devem ser validados no backend antes de conceder acesso.

**Regras relacionadas:** [RN10](01-regras-de-negocio.md#rn10), [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46)  
**Aplicação nos casos de uso:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

### RNF19

**Categoria:** Segurança

O processamento de um convite deve permanecer restrito à família e ao perfil vinculados ao token, impedindo que alterações nos dados enviados pelo cliente redirecionem o ingresso a outro perfil ou família.

**Regras relacionadas:** [RN46](01-regras-de-negocio.md#rn46)  
**Aplicação nos casos de uso:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

### RNF20

**Categoria:** Proteção contra tentativas abusivas

O serviço de ingresso deve proteger tanto a validação do link quanto a verificação da senha contra tentativas automatizadas e repetidas.

**Regras relacionadas:** [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46)  
**Aplicação nos casos de uso:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

### RNF21

**Categoria:** Consumo único

O consumo do convite e da senha e a efetivação do ingresso devem permanecer consistentes sob concorrência, sem permitir mais de um ingresso bem-sucedido.

**Regras relacionadas:** [RN46](01-regras-de-negocio.md#rn46)  
**Aplicação nos casos de uso:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

### RNF22

**Categoria:** Sessões e revogação

As sessões devem proteger seus identificadores e ter sua validade e associação ao perfil ativo e à família verificadas nas operações protegidas. A renovação utiliza refresh token sem expiração temporal. A remoção de um perfil deve revogar seu acesso, inclusive por sessões abertas antes da remoção e por tentativas de renovação com refresh tokens anteriores. Ausência de expiração temporal não equivale a ausência de revogação.

**Regras relacionadas:** [RN10](01-regras-de-negocio.md#rn10), [RN47](01-regras-de-negocio.md#rn47)  
**Aplicação nos casos de uso:** [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

### RNF23

**Categoria:** Integridade de dados

A aceitação da recompensa e o encerramento do resgate devem ser persistidos de forma consistente. Ações simultâneas de Administradores não podem registrar mais de uma recompensa nem permitir um segundo resgate da mesma missão.

**Regras relacionadas:** [RN53](01-regras-de-negocio.md#rn53)  
**Aplicação nos casos de uso:** [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16)

### RNF24

**Categoria:** Privacidade das fotos

O armazenamento e a consulta de fotos devem respeitar a associação à família e as permissões do perfil, impedindo acesso público ou por usuários não autorizados. A remoção de um membro também revoga seu acesso às fotos da família.

**Regras relacionadas:** [RN10](01-regras-de-negocio.md#rn10), [RN54](01-regras-de-negocio.md#rn54)  
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC15](03-casos-de-uso.md#uc15)

### RNF25

**Categoria:** Integridade de reabertura e conquista

Reabertura, atualização da carga, atualização de progresso e verificação de proteção por missão concluída devem ser processadas de forma consistente, inclusive sob concorrência, sem permitir estados parciais ou alteração de conquista preservada.

**Regras relacionadas:** [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)


## Histórico de versões

| Versão | Data | Alteração |
|---|---|---|
| 1.2 | 2026-10-01 | Área Família na navegação adulta, progresso coletivo diário e consulta por carrossel: RN60, RF60 e UC11. Design em elaboração na versão 1.0. |
| 1.1 | 2026-10-01 | Recuperação do mesmo perfil por novo convite e renovação sem expiração temporal, com revogação preservada: RN47, RF41, RF46, RF54, RNF22, UC02 e UC09. |
| 1.0 | 2026-10-01 | Primeira versão consolidada, incluindo todas as decisões registradas até esta publicação e links para a visão e a apresentação do projeto. |
