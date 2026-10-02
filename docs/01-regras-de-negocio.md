# Regras de negócio

**Projeto:** App de Organização Familiar — MVP  
**Versão:** 1.4  
**Data:** 2026-10-02  
**Situação:** base documental consolidada

[Projeto](../README.md) · [Visão do produto](00-visao-do-produto.md) · [Índice e versões](DOCUMENTACAO.md) · [Regras de negócio](01-regras-de-negocio.md) · [Requisitos](02-requisitos.md) · [Casos de uso](03-casos-de-uso.md) · [Diagramas UML](04-diagramas-de-caso-de-uso.md) · [Screen map](design/screen-map.md)

Este documento contém todas as regras vigentes da versão 1.4. Os requisitos concretizam essas regras, e os casos de uso descrevem os fluxos em que são aplicadas. As referências de UC nesta página são derivadas dos requisitos relacionados.

**Identificadores preservados:** RN15, RN29 e RN32 não estavam definidos na base recebida e permanecem não utilizados. Não representam conteúdo faltante desta versão.

## Índice de regras

[RN01](#rn01) · [RN02](#rn02) · [RN03](#rn03) · [RN04](#rn04) · [RN05](#rn05) · [RN06](#rn06) · [RN07](#rn07) · [RN08](#rn08) · [RN09](#rn09) · [RN10](#rn10) · [RN11](#rn11) · [RN12](#rn12) · [RN13](#rn13) · [RN14](#rn14) · [RN16](#rn16) · [RN17](#rn17) · [RN18](#rn18) · [RN19](#rn19) · [RN20](#rn20) · [RN21](#rn21) · [RN22](#rn22) · [RN23](#rn23) · [RN24](#rn24) · [RN25](#rn25) · [RN26](#rn26) · [RN27](#rn27) · [RN28](#rn28) · [RN30](#rn30) · [RN31](#rn31) · [RN33](#rn33) · [RN34](#rn34) · [RN35](#rn35) · [RN36](#rn36) · [RN37](#rn37) · [RN38](#rn38) · [RN39](#rn39) · [RN40](#rn40) · [RN41](#rn41) · [RN42](#rn42) · [RN43](#rn43) · [RN44](#rn44) · [RN45](#rn45) · [RN46](#rn46) · [RN47](#rn47) · [RN48](#rn48) · [RN49](#rn49) · [RN50](#rn50) · [RN51](#rn51) · [RN52](#rn52) · [RN53](#rn53) · [RN54](#rn54) · [RN55](#rn55) · [RN56](#rn56) · [RN57](#rn57) · [RN58](#rn58) · [RN59](#rn59) · [RN60](#rn60) · [RN61](#rn61) · [RN62](#rn62) · [RN63](#rn63) · [RN64](#rn64) · [RN65](#rn65)

## RN01

Quem cria a família se torna automaticamente Administrador e Criador da Família, identificado pela flag isFamilyCreator. A família pode ter mais de um Administrador, todos com as mesmas permissões, exceto as proteções exclusivas do Criador.

**Requisitos funcionais:** [RF01](02-requisitos.md#rf01), [RF05](02-requisitos.md#rf05), [RF38](02-requisitos.md#rf38)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02)

## RN02

Qualquer Administrador pode promover um Membro adulto a Administrador. Perfis Kids não podem ser promovidos sem antes sair do Modo Kids.

**Requisitos funcionais:** [RF03](02-requisitos.md#rf03), [RF05](02-requisitos.md#rf05), [RF06](02-requisitos.md#rf06)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02)

## RN03

Qualquer Administrador pode rebaixar outro Administrador a Membro, exceto o Criador da Família.

**Requisitos funcionais:** [RF03](02-requisitos.md#rf03), [RF05](02-requisitos.md#rf05)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02)

## RN04

Um Administrador pode deixar o papel por conta própria, exceto o Criador da Família.

**Requisitos funcionais:** [RF05](02-requisitos.md#rf05)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02)

## RN05

O Criador da Família não pode ser removido, rebaixado nem sair da família. Assim, a família sempre tem pelo menos um Administrador.

**Requisitos funcionais:** [RF04](02-requisitos.md#rf04), [RF05](02-requisitos.md#rf05)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02)

## RN06

Existem três perfis: Administrador, Membro e Kids. O Criador da Família é um Administrador identificado por flag, não um perfil à parte.

**Requisitos funcionais:** [RF05](02-requisitos.md#rf05)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02)

## RN07

Apenas Administradores podem adicionar, editar e remover membros administrativamente. A edição do próprio perfil é permitida a todos conforme RN63; a configuração de etiqueta/apelido pertence exclusivamente ao titular, inclusive quando o titular é Kids.

**Requisitos funcionais:** [RF02](02-requisitos.md#rf02), [RF03](02-requisitos.md#rf03), [RF04](02-requisitos.md#rf04), [RF40](02-requisitos.md#rf40)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02)

## RN08

Apenas Administradores podem ativar ou desativar o Modo Kids de um perfil. Um Administrador não pode estar em Modo Kids.

**Requisitos funcionais:** [RF03](02-requisitos.md#rf03), [RF06](02-requisitos.md#rf06)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02)

## RN09

Cada usuário pertence a uma única família. Ao autenticar-se, o Criador que já possui família vinculada é redirecionado para ela, sem criar um novo vínculo.

**Requisitos funcionais:** [RF01](02-requisitos.md#rf01), [RF38](02-requisitos.md#rf38)  
**Requisitos não funcionais específicos:** [RNF06](02-requisitos.md#rnf06)  
**Casos de uso relacionados:** [UC01](03-casos-de-uso.md#uc01)

## RN10

A remoção de um membro revoga seu acesso aos dados da família, inclusive por sessões existentes. Suas tarefas futuras ficam sem responsável e o histórico de tarefas concluídas é preservado.

**Requisitos funcionais:** [RF04](02-requisitos.md#rf04), [RF43](02-requisitos.md#rf43)  
**Requisitos não funcionais específicos:** [RNF06](02-requisitos.md#rnf06), [RNF09](02-requisitos.md#rnf09), [RNF18](02-requisitos.md#rnf18), [RNF22](02-requisitos.md#rnf22), [RNF24](02-requisitos.md#rnf24)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

## RN11

Toda tarefa tem título e peso obrigatórios. O responsável é opcional. A tarefa pode ser criada sem repetição ou ser gerada por uma rotina; a recorrência é uma configuração da rotina.

**Requisitos funcionais:** [RF07](02-requisitos.md#rf07), [RF10](02-requisitos.md#rf10), [RF13](02-requisitos.md#rf13), [RF15](02-requisitos.md#rf15)  
**Requisitos não funcionais específicos:** [RNF02](02-requisitos.md#rnf02)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08)

## RN12

Tarefas podem ter mais de um responsável.

**Requisitos funcionais:** [RF10](02-requisitos.md#rf10)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07)

## RN13

O peso é obrigatório e vai de 1 a 3: 1 = pouco esforço, 2 = médio esforço e 3 = alto esforço.

**Requisitos funcionais:** [RF15](02-requisitos.md#rf15), [RF16](02-requisitos.md#rf16)  
**Requisitos não funcionais específicos:** [RNF02](02-requisitos.md#rnf02)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07)

## RN14

A criação permite tarefa única, sem repetição, ou rotina diária ou a cada 7, 14, 21 ou 28 dias. As rotinas geram tarefas individuais conforme o intervalo definido. Não existe frequência mensal.

**Requisitos funcionais:** [RF13](02-requisitos.md#rf13), [RF14](02-requisitos.md#rf14)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC08](03-casos-de-uso.md#uc08)

## RN16

Cada tarefa, inclusive a gerada por uma rotina, possui identificação e status próprios. Concluir uma tarefa não altera as demais tarefas da mesma rotina.

**Requisitos funcionais:** [RF13](02-requisitos.md#rf13), [RF17](02-requisitos.md#rf17), [RF50](02-requisitos.md#rf50)  
**Requisitos não funcionais específicos:** [RNF09](02-requisitos.md#rnf09)  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC08](03-casos-de-uso.md#uc08), [UC11](03-casos-de-uso.md#uc11)

## RN17

A edição individual altera apenas a tarefa selecionada. Alterações de rotina afetam somente as tarefas futuras abrangidas, preservando os dados passados. Alterações que modifiquem dados preservados de missões concluídas são proibidas.

**Requisitos funcionais:** [RF08](02-requisitos.md#rf08), [RF13](02-requisitos.md#rf13)  
**Requisitos não funcionais específicos:** [RNF09](02-requisitos.md#rnf09)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08)

## RN18

Tarefas concluídas não podem ser excluídas diretamente. Em tarefas de rotina, é possível excluir a selecionada ou ela e as futuras, preservando ocorrências concluídas e registros protegidos de missões concluídas. A reabertura segue [RN57](01-regras-de-negocio.md#rn57) e [RN58](01-regras-de-negocio.md#rn58).

**Requisitos funcionais:** [RF09](02-requisitos.md#rf09)  
**Requisitos não funcionais específicos:** [RNF09](02-requisitos.md#rnf09)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07)

## RN19

Perfis Kids não criam, editam nem excluem tarefas.

**Requisitos funcionais:** [RF07](02-requisitos.md#rf07), [RF08](02-requisitos.md#rf08), [RF09](02-requisitos.md#rf09), [RF27](02-requisitos.md#rf27)  
**Requisitos não funcionais específicos:** [RNF04](02-requisitos.md#rnf04), [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07)

## RN20

Administradores e Membros gerenciam tarefas: criam, editam, excluem, atribuem e reatribuem, inclusive tarefas de outros membros, respeitando as restrições de estado e a preservação das missões concluídas.

**Requisitos funcionais:** [RF07](02-requisitos.md#rf07), [RF08](02-requisitos.md#rf08), [RF09](02-requisitos.md#rf09), [RF10](02-requisitos.md#rf10)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07)

## RN21

Administradores e Membros podem concluir tarefas da família, ainda que não sejam responsáveis. Kids somente sinalizam tarefas sob sua responsabilidade. Ao concluir tarefa atribuída a outras pessoas, o adulto escolhe manter os responsáveis ou substituí-los por si mesmo, após ser informado dos efeitos sobre o crédito da conclusão.

**Requisitos funcionais:** [RF12](02-requisitos.md#rf12), [RF23](02-requisitos.md#rf23)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC12](03-casos-de-uso.md#uc12), [UC15](03-casos-de-uso.md#uc15)

## RN22

Administradores e Membros podem concluir uma tarefa Pendente ou Aguardando confirmação. A conclusão é única e vale para todos os responsáveis finais, inclusive Kids.

**Requisitos funcionais:** [RF12](02-requisitos.md#rf12), [RF17](02-requisitos.md#rf17), [RF24](02-requisitos.md#rf24), [RF26](02-requisitos.md#rf26)  
**Requisitos não funcionais específicos:** [RNF02](02-requisitos.md#rnf02), [RNF11](02-requisitos.md#rnf11)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC15](03-casos-de-uso.md#uc15)

## RN23

A sinalização de um perfil Kids altera a tarefa de Pendente para Aguardando confirmação, sem gerar conclusão parcial. A confirmação por Administrador ou a conclusão manual por Administrador ou Membro torna a tarefa Concluída para todos os responsáveis.

**Requisitos funcionais:** [RF23](02-requisitos.md#rf23), [RF24](02-requisitos.md#rf24), [RF26](02-requisitos.md#rf26)  
**Requisitos não funcionais específicos:** [RNF11](02-requisitos.md#rnf11)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC15](03-casos-de-uso.md#uc15)

## RN24

Qualquer Administrador pode confirmar ou recusar uma sinalização Kids. A primeira decisão válida sobre o estado corrente é registrada e retira a tarefa das demais filas. A recusa retorna a tarefa para Pendente. Uma conclusão manual anterior à decisão encerra a pendência de validação e impede confirmação ou recusa duplicada.

**Requisitos funcionais:** [RF24](02-requisitos.md#rf24), [RF25](02-requisitos.md#rf25)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07), [RNF11](02-requisitos.md#rnf11)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC15](03-casos-de-uso.md#uc15)

## RN25

O registro de confirmação guarda qual Administrador confirmou.

**Requisitos funcionais:** [RF25](02-requisitos.md#rf25)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03)

## RN26

Tarefas aguardando confirmação não contam para carga, progresso diário ou semanal concluído ou progresso de missões. Passam a contar após confirmação ou conclusão manual válida por adulto.

**Requisitos funcionais:** [RF19](02-requisitos.md#rf19), [RF26](02-requisitos.md#rf26), [RF30](02-requisitos.md#rf30), [RF49](02-requisitos.md#rf49)  
**Requisitos não funcionais específicos:** [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC11](03-casos-de-uso.md#uc11), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14)

## RN27

Tarefas não realizadas não geram penalidade nem perda de pontos. O checklist abre por padrão no dia atual e permite consultar outras datas conforme [RN49](01-regras-de-negocio.md#rn49). Aguardando confirmação permanece um estado distinto de Pendente até decisão válida.

**Requisitos funcionais:** [RF11](02-requisitos.md#rf11), [RF17](02-requisitos.md#rf17), [RF22](02-requisitos.md#rf22)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC11](03-casos-de-uso.md#uc11)

## RN28

A semana vai de segunda-feira a domingo. Consultas, relatório e apuração semanal devem usar o mesmo fuso de referência da família, sem variar conforme o dispositivo. O fuso e o horário operacional da apuração permanecem pendentes de definição; não há configuração de fuso pelo usuário especificada nesta versão.

**Requisitos funcionais:** [RF18](02-requisitos.md#rf18), [RF63](02-requisitos.md#rf63), [RF66](02-requisitos.md#rf66)  
**Requisitos não funcionais específicos:** [RNF10](02-requisitos.md#rnf10)  
**Casos de uso relacionados:** [UC13](03-casos-de-uso.md#uc13), [UC11](03-casos-de-uso.md#uc11), [UC19](03-casos-de-uso.md#uc19)

## RN30

A carga de um membro é a soma dos pesos integrais das tarefas com conclusão válida no dia ou na semana selecionada nas quais ele consta como responsável da conclusão. Em tarefas compartilhadas, cada responsável recebe o peso integral. Executar a ação de concluir não gera crédito para quem não for responsável. Pontos do destaque semanal usam essa mesma soma, sem uma segunda moeda de pontuação.

**Requisitos funcionais:** [RF15](02-requisitos.md#rf15), [RF18](02-requisitos.md#rf18), [RF19](02-requisitos.md#rf19), [RF20](02-requisitos.md#rf20), [RF56](02-requisitos.md#rf56), [RF63](02-requisitos.md#rf63)  
**Requisitos não funcionais específicos:** [RNF03](02-requisitos.md#rnf03), [RNF10](02-requisitos.md#rnf10)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC07](03-casos-de-uso.md#uc07), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC15](03-casos-de-uso.md#uc15), [UC19](03-casos-de-uso.md#uc19)

## RN31

A carga total da família é a soma das cargas individuais. A participação de cada membro é sua carga dividida pela carga total, em percentual. Quando o total for zero, não se realiza divisão por zero.

**Requisitos funcionais:** [RF20](02-requisitos.md#rf20), [RF21](02-requisitos.md#rf21)  
**Requisitos não funcionais específicos:** [RNF03](02-requisitos.md#rnf03), [RNF10](02-requisitos.md#rnf10)  
**Casos de uso relacionados:** [UC13](03-casos-de-uso.md#uc13)

## RN33

Todos os perfis visualizam seu próprio progresso por dia ou semana. Administradores e Membros também visualizam o progresso familiar e a distribuição da carga/sobrecarga por dia ou semana. Kids não acessam a distribuição de carga, a área Família nem o relatório familiar. Podem receber seu próprio reconhecimento semanal conforme RN65.

**Requisitos funcionais:** [RF20](02-requisitos.md#rf20), [RF49](02-requisitos.md#rf49), [RF65](02-requisitos.md#rf65), [RF66](02-requisitos.md#rf66)  
**Requisitos não funcionais específicos:** [RNF04](02-requisitos.md#rnf04), [RNF06](02-requisitos.md#rnf06)  
**Casos de uso relacionados:** [UC11](03-casos-de-uso.md#uc11), [UC13](03-casos-de-uso.md#uc13), [UC10](03-casos-de-uso.md#uc10), [UC14](03-casos-de-uso.md#uc14)

## RN34

A visualização de carga apresenta distribuição e equilíbrio. O destaque de primeiro lugar semanal é uma funcionalidade específica prevista em RN65, com convite a uma atividade em família. Não há ranking completo, competição entre famílias ou penalidade para os demais membros.

**Requisitos funcionais:** [RF20](02-requisitos.md#rf20), [RF21](02-requisitos.md#rf21)  
**Requisitos não funcionais específicos:** [RNF03](02-requisitos.md#rnf03)  
**Casos de uso relacionados:** [UC13](03-casos-de-uso.md#uc13)

## RN35

Missões são coletivas. O progresso corresponde à quantidade de tarefas individuais vinculadas concluídas dividida pelo total de tarefas vinculadas, em percentual. Cada tarefa conta uma vez, independentemente de quantos responsáveis possua.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF30](02-requisitos.md#rf30), [RF50](02-requisitos.md#rf50), [RF56](02-requisitos.md#rf56)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC05](03-casos-de-uso.md#uc05), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15)

## RN36

Uma missão possui ao menos uma tarefa individual vinculada e não tem prazo ou período de vigência. Seu objetivo é concluir todas as tarefas vinculadas. O selo é opcional; a recompensa é definida após a conclusão, por sorteio e aceitação.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF31](02-requisitos.md#rf31), [RF32](02-requisitos.md#rf32), [RF35](02-requisitos.md#rf35), [RF50](02-requisitos.md#rf50)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16)

## RN37

Apenas Administradores criam missões, de forma personalizada.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05)

## RN38

A missão é concluída quando todas as tarefas vinculadas estiverem concluídas. A conclusão concede o selo opcional e habilita o resgate. A recompensa só é registrada após aceitação por Administrador. Os dados da missão concluída são preservados conforme [RN58](01-regras-de-negocio.md#rn58).

**Requisitos funcionais:** [RF31](02-requisitos.md#rf31), [RF32](02-requisitos.md#rf32), [RF35](02-requisitos.md#rf35), [RF36](02-requisitos.md#rf36), [RF51](02-requisitos.md#rf51), [RF52](02-requisitos.md#rf52), [RF58](02-requisitos.md#rf58)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

## RN39

Missões não expiram por tempo. Permanecem em andamento enquanto houver tarefas vinculadas pendentes ou aguardando confirmação, sem penalidade por demora.

**Requisitos funcionais:** [RF31](02-requisitos.md#rf31)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC14](03-casos-de-uso.md#uc14)

## RN40

Não existem missões individuais nem competição entre membros ou entre famílias.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05)

## RN41

Recompensas são coletivas e beneficiam a família inteira.

**Requisitos funcionais:** [RF33](02-requisitos.md#rf33), [RF34](02-requisitos.md#rf34)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC06](03-casos-de-uso.md#uc06)

## RN42

A roleta oferece itens predefinidos e itens personalizados adicionados por Administradores. Somente Administradores podem adicionar itens, sortear e aceitar recompensas. Adicionar um item o torna elegível para sorteios, sem vinculá-lo automaticamente a uma missão.

**Requisitos funcionais:** [RF34](02-requisitos.md#rf34), [RF51](02-requisitos.md#rf51), [RF52](02-requisitos.md#rf52)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC06](03-casos-de-uso.md#uc06), [UC16](03-casos-de-uso.md#uc16)

## RN43

Uma missão concluída e sem recompensa resgatada disponibiliza a opção de resgatar ou sortear recompensa aos Administradores. Essa ação abre a roleta com os itens predefinidos pelo aplicativo e os itens adicionados. O sorteio apresenta uma recompensa para aceitação.

**Requisitos funcionais:** [RF35](02-requisitos.md#rf35), [RF36](02-requisitos.md#rf36), [RF51](02-requisitos.md#rf51), [RF52](02-requisitos.md#rf52)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16)

## RN44

Apenas o Criador da Família se autentica via Sign in with Apple, e a família é vinculada ao identificador Apple dele.

**Requisitos funcionais:** [RF37](02-requisitos.md#rf37), [RF38](02-requisitos.md#rf38), [RF39](02-requisitos.md#rf39)  
**Requisitos não funcionais específicos:** [RNF15](02-requisitos.md#rnf15), [RNF16](02-requisitos.md#rnf16)  
**Casos de uso relacionados:** [UC01](03-casos-de-uso.md#uc01), [UC04](03-casos-de-uso.md#uc04)

## RN45

Os demais perfis, inclusive Administradores promovidos e Kids, ingressam pelo link do perfil criado por um Administrador e pela senha de ingresso gerada pelo sistema e enviada junto com esse link.

**Requisitos funcionais:** [RF40](02-requisitos.md#rf40), [RF41](02-requisitos.md#rf41), [RF42](02-requisitos.md#rf42), [RF43](02-requisitos.md#rf43), [RF54](02-requisitos.md#rf54)  
**Requisitos não funcionais específicos:** [RNF17](02-requisitos.md#rnf17), [RNF18](02-requisitos.md#rnf18), [RNF20](02-requisitos.md#rnf20)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

## RN46

O conjunto de link e senha está vinculado a uma única família e a um único perfil e admite um único ingresso bem-sucedido. Sua validação e consumo devem impedir ingressos simultâneos duplicados. A senha não é usada para login posterior.

**Requisitos funcionais:** [RF41](02-requisitos.md#rf41), [RF42](02-requisitos.md#rf42), [RF43](02-requisitos.md#rf43), [RF44](02-requisitos.md#rf44), [RF46](02-requisitos.md#rf46), [RF54](02-requisitos.md#rf54)  
**Requisitos não funcionais específicos:** [RNF17](02-requisitos.md#rnf17), [RNF18](02-requisitos.md#rnf18), [RNF19](02-requisitos.md#rnf19), [RNF20](02-requisitos.md#rnf20), [RNF21](02-requisitos.md#rnf21)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

## RN47

Após o ingresso, o membro mantém a sessão por renovação com refresh token sem expiração temporal e não precisa usar o link a cada acesso. A ausência de expiração não impede a revogação: a remoção do perfil revoga também a capacidade de renovar seu acesso.

Se perder a sessão, o usuário solicita a um Administrador um novo convite (link e senha de uso único) para o mesmo perfil ativo. O novo ingresso recupera o acesso sem criar outro perfil, mantendo histórico, tarefas e vínculos. O Criador recupera o acesso pelo Sign in with Apple.

**Requisitos funcionais:** [RF41](02-requisitos.md#rf41), [RF45](02-requisitos.md#rf45), [RF46](02-requisitos.md#rf46), [RF54](02-requisitos.md#rf54)  
**Requisitos não funcionais específicos:** [RNF22](02-requisitos.md#rnf22)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

## RN48

Ao concluir tarefa sem responsável, o adulto que conclui torna-se seu responsável. Ao assumir tarefa com responsáveis, substitui todos eles por si mesmo. Ambas as operações afetam somente a tarefa individual, sem propagação para a rotina.

**Requisitos funcionais:** [RF12](02-requisitos.md#rf12), [RF47](02-requisitos.md#rf47)  
**Requisitos não funcionais específicos:** [RNF09](02-requisitos.md#rnf09)  
**Casos de uso relacionados:** [UC12](03-casos-de-uso.md#uc12)

## RN49

O carrossel permite consultar da data de criação da família até o último dia do mês corrente, inclusive, respeitando as permissões. Inclui dias futuros dentro do mês atual e impede datas anteriores à criação e meses seguintes. A restrição de consulta não cancela a geração pelas rotinas.

**Requisitos funcionais:** [RF11](02-requisitos.md#rf11), [RF17](02-requisitos.md#rf17), [RF22](02-requisitos.md#rf22)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC11](03-casos-de-uso.md#uc11)

## RN50

Uma missão só pode ser salva com ao menos uma tarefa vinculada. Em missão em andamento, remover ou excluir sua última tarefa exige vincular outra antes de efetivar a operação. Missões concluídas não admitem alteração dos vínculos.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF50](02-requisitos.md#rf50), [RF59](02-requisitos.md#rf59)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC17](03-casos-de-uso.md#uc17)

## RN51

O vínculo com a missão é feito por tarefa individual. Tarefas geradas pela mesma rotina são selecionadas separadamente. Vincular uma tarefa não vincula sua rotina nem inclui automaticamente outras tarefas já existentes ou geradas posteriormente.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF30](02-requisitos.md#rf30), [RF50](02-requisitos.md#rf50)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC14](03-casos-de-uso.md#uc14)

## RN52

Enquanto a recompensa não for aceita, o Administrador pode recusar o resultado e realizar novos sorteios até decidir aceitá-la. Sair da roleta sem aceitar mantém a missão concluída e o resgate disponível.

**Requisitos funcionais:** [RF36](02-requisitos.md#rf36), [RF51](02-requisitos.md#rf51), [RF52](02-requisitos.md#rf52)  
**Requisitos não funcionais específicos:** Aplicam-se as condições gerais de qualidade e segurança.  
**Casos de uso relacionados:** [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16)

## RN53

Ao aceitar a recompensa, o sistema a registra nos dados da missão concluída e encerra o resgate para toda a família. A mesma missão não pode ser resgatada novamente por nenhum Administrador, inclusive em acessos simultâneos.

**Requisitos funcionais:** [RF35](02-requisitos.md#rf35), [RF36](02-requisitos.md#rf36), [RF52](02-requisitos.md#rf52), [RF53](02-requisitos.md#rf53), [RF58](02-requisitos.md#rf58)  
**Requisitos não funcionais específicos:** [RNF23](02-requisitos.md#rnf23)  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

## RN54

O perfil Kids pode anexar uma foto à sinalização da tarefa. Ao tocar em adicionar foto, o aplicativo abre diretamente a câmera, solicitando permissão do dispositivo quando necessária, sem etapa de escolha entre câmera e galeria. A criança pode revisar, refazer ou descartar a captura antes de enviar. Cancelamento, permissão negada ou câmera indisponível permitem continuar sem foto. A ausência de foto não impede sinalizar nem confirmar. O Administrador pode visualizar a foto ao avaliar a sinalização.

**Requisitos funcionais:** [RF23](02-requisitos.md#rf23), [RF25](02-requisitos.md#rf25), [RF55](02-requisitos.md#rf55)  
**Requisitos não funcionais específicos:** [RNF24](02-requisitos.md#rnf24)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC15](03-casos-de-uso.md#uc15)

## RN55

Uma tarefa possui estado único para todos os responsáveis. Sua conclusão vale para todos, sem divisão do peso e sem conclusões parciais individuais. A reabertura autorizada também vale para todos.

**Requisitos funcionais:** [RF12](02-requisitos.md#rf12), [RF17](02-requisitos.md#rf17), [RF18](02-requisitos.md#rf18), [RF23](02-requisitos.md#rf23), [RF25](02-requisitos.md#rf25), [RF26](02-requisitos.md#rf26), [RF30](02-requisitos.md#rf30), [RF56](02-requisitos.md#rf56), [RF57](02-requisitos.md#rf57)  
**Requisitos não funcionais específicos:** [RNF02](02-requisitos.md#rnf02), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11), [RNF25](02-requisitos.md#rnf25)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC17](03-casos-de-uso.md#uc17)

## RN56

Antes de concluir tarefa atribuída a outras pessoas, o adulto deve ser informado de quem receberá o crédito e pode manter os responsáveis ou assumir a tarefa, substituindo a lista completa. A troca só é efetivada junto com a conclusão confirmada.

**Requisitos funcionais:** [RF12](02-requisitos.md#rf12), [RF47](02-requisitos.md#rf47), [RF56](02-requisitos.md#rf56)  
**Requisitos não funcionais específicos:** [RNF10](02-requisitos.md#rnf10)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC15](03-casos-de-uso.md#uc15)

## RN57

Somente Administradores podem retornar a Pendente uma tarefa concluída vinculada a missão em andamento, desde que ela não esteja vinculada a nenhuma missão concluída. A reabertura remove a contribuição da conclusão anterior da carga de todos os responsáveis e do progresso das missões em andamento, inclusive ajustando uma semana passada.

**Requisitos funcionais:** [RF09](02-requisitos.md#rf09), [RF18](02-requisitos.md#rf18), [RF19](02-requisitos.md#rf19), [RF57](02-requisitos.md#rf57), [RF59](02-requisitos.md#rf59)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11), [RNF25](02-requisitos.md#rnf25)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07), [UC13](03-casos-de-uso.md#uc13), [UC17](03-casos-de-uso.md#uc17)

## RN58

Missões concluídas não podem ter seus dados ou vínculos alterados ou ser excluídas. Tarefas vinculadas não podem ser reabertas, excluídas ou modificadas de modo a alterar os dados preservados da missão. O registro da recompensa aceita é permitido exclusivamente pelo fluxo de resgate único, sem modificar a conquista.

**Requisitos funcionais:** [RF08](02-requisitos.md#rf08), [RF09](02-requisitos.md#rf09), [RF10](02-requisitos.md#rf10), [RF28](02-requisitos.md#rf28), [RF50](02-requisitos.md#rf50), [RF57](02-requisitos.md#rf57), [RF58](02-requisitos.md#rf58), [RF59](02-requisitos.md#rf59)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07), [RNF09](02-requisitos.md#rnf09), [RNF25](02-requisitos.md#rnf25)  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC17](03-casos-de-uso.md#uc17)

## RN59

A exclusão de tarefa não concluída remove seus vínculos com missões em andamento e recalcula seus progressos. A operação é bloqueada se deixar uma missão sem tarefas ou afetar missão concluída. Após reabertura, a exclusão não desconta novamente o peso já retirado.

**Requisitos funcionais:** [RF09](02-requisitos.md#rf09), [RF50](02-requisitos.md#rf50), [RF59](02-requisitos.md#rf59)  
**Requisitos não funcionais específicos:** [RNF09](02-requisitos.md#rnf09), [RNF25](02-requisitos.md#rnf25)  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC17](03-casos-de-uso.md#uc17)


## RN60

Administradores e Membros acessam a área Família (Minha família), que apresenta diretamente a carga e o progresso coletivo por dia ou semana e a lista de membros. Selecionar um membro abre o detalhe com as tarefas daquela pessoa por dia ou semana. A consulta abre no dia atual; o período segue RN49 e RN61. O detalhe herda o período da origem, mantém o filtro por membro e, ao voltar, restaura o contexto anterior de Família. A consulta complementar de todas as tarefas, inclusive sem responsável, continua disponível.

O progresso familiar é a quantidade de tarefas concluídas dentre as tarefas previstas para o período dividida pelo total de tarefas previstas para esse período. Cada tarefa conta uma vez, independentemente do peso ou dos responsáveis, incluindo as sem responsável no total. Pendentes e Aguardando confirmação não entram no numerador. Sem tarefas, apresentar “Sem tarefas”, sem divisão por zero. Alterações válidas atualizam o indicador.

Gerar relatório semanal em PDF fica na própria tela Família para adultos. Adicionar membro também fica nessa tela, exclusivamente para Administradores. Editar perfil e gerar/reenviar convite ficam no detalhe do membro, exclusivamente para Administradores e conforme as restrições do perfil; não permitem editar apelido de terceiros. Reenvio usa convite ainda disponível; recuperação ou convite consumido exige novo link e senha de uso único para o mesmo perfil ativo. O Criador retorna por Apple. Confirmações Kids permanecem exclusivas dos Administradores. Kids não acessam esta área.

**Requisitos funcionais:** [RF60](02-requisitos.md#rf60), [RF66](02-requisitos.md#rf66)  
**Requisitos não funcionais específicos:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF09](02-requisitos.md#rnf09)  
**Casos de uso relacionados:** [UC11](03-casos-de-uso.md#uc11), [UC13](03-casos-de-uso.md#uc13)

## RN61

**Tema:** Períodos e métricas

Minhas tarefas (todos os perfis), os indicadores integrados de Minha família e as tarefas no detalhe do membro (adultos) oferecem alternância Dia/Semana. A semana contém a data selecionada e vai de segunda a domingo. O intervalo de consulta de tarefas continua da criação da família até o último dia do mês corrente; nas semanas de borda, informar os dias efetivamente disponíveis. O progresso pessoal conta tarefas próprias concluídas sobre o total próprio previsto para o período; o familiar usa RN60. O progresso semanal é calculado sobre os totais da semana, nunca pela média simples dos percentuais diários.

A carga/sobrecarga usa a data da conclusão válida, enquanto o progresso usa as tarefas previstas para o período e seu estado atual. Uma tarefa atrasada pode contribuir para a carga de hoje e para o progresso do dia em que estava prevista. A carga indica participação creditada, sem limiar de diagnóstico de sobrecarga definido. Seleção, gráficos e rótulos devem explicitar período e métrica. Sem tarefas ou carga, informar ausência de dados; não simular 100%.

**Requisitos funcionais:** [RF18](02-requisitos.md#rf18), [RF49](02-requisitos.md#rf49), [RF60](02-requisitos.md#rf60), [RF66](02-requisitos.md#rf66)  
**Requisitos não funcionais específicos:** [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10)  
**Casos de uso relacionados:** [UC11](03-casos-de-uso.md#uc11), [UC13](03-casos-de-uso.md#uc13)

## RN62

**Tema:** Relatório semanal em PDF

Administradores e Membros podem gerar um relatório familiar em PDF para uma semana selecionada de segunda a domingo. O documento identifica família, período e momento de geração, inclui gráficos da distribuição de carga semanal por membro e do progresso total da família, além do peso total creditado e número de tarefas realizadas por membro. O gráfico de progresso usa concluídas/total de tarefas previstas para a semana (RN60); peso e quantidade realizada por membro usam conclusões válidas naquela semana (RN30).

Uma tarefa compartilhada conta uma vez para cada responsável no número individual e credita o peso integral a cada um; o total familiar de tarefas realizadas conta tarefas distintas, sem somar contagens individuais. O relatório explica essa diferença. Semana atual é identificada como parcial até o momento da geração; semanas futuras não geram relatório. Na semana de criação, indicar ausência de registros anteriores à criação, mantendo o cabeçalho segunda–domingo. Semana sem dados pode gerar relatório com zeros e indicação “Sem tarefas” onde aplicável. O PDF reflete os dados no momento de geração; reabrir uma tarefa exige gerar novo arquivo para obter valores atualizados. Não incluir fotos de validação, credenciais ou configuração privada de perfil.

**Requisitos funcionais:** [RF61](02-requisitos.md#rf61)  
**Requisitos não funcionais específicos:** [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF10](02-requisitos.md#rnf10), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF26](02-requisitos.md#rnf26), [RNF27](02-requisitos.md#rnf27)  
**Casos de uso relacionados:** [UC18](03-casos-de-uso.md#uc18)

## RN63

**Tema:** Foto e etiqueta/apelido do perfil

Todos os perfis, inclusive Kids, podem adicionar, substituir ou remover a própria foto, que é opcional. Sem foto, exibir identificação padrão. Todos podem configurar a própria etiqueta/apelido; outras pessoas, inclusive Administradores, não acessam sua configuração nem podem alterá-la. O nome de identificação permanece separado do apelido.

O apelido é visível à família, com edição exclusiva do titular. A forma de escolher a foto de perfil permanece para design e não herda obrigatoriamente a câmera direta da validação Kids. Kids acessam Meu perfil pelo avatar/cabeçalho, sem terceira aba no tab bar.

**Requisitos funcionais:** [RF48](02-requisitos.md#rf48), [RF65](02-requisitos.md#rf65)  
**Requisitos não funcionais específicos:** [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF12](02-requisitos.md#rnf12), [RNF24](02-requisitos.md#rnf24), [RNF27](02-requisitos.md#rnf27)  
**Casos de uso relacionados:** [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC14](03-casos-de-uso.md#uc14)

## RN64

**Tema:** Badges coletivos no perfil

Badge e selo designam a mesma conquista. Concluir uma missão que tenha selo atribui coletivamente esse badge aos perfis da família, independentemente de responsabilidade individual nas tarefas. Ele aparece no perfil de cada pessoa e nas conquistas da missão, sem depender do resgate da recompensa. Missão sem selo não cria badge. A concessão não pode duplicar o mesmo badge da mesma missão para uma pessoa.

Premissa de detalhamento: recebem o badge os perfis ativos no momento da conclusão e a conquista permanece em seu histórico. A política para concessão retroativa a novos membros permanece pendente.

**Requisitos funcionais:** [RF32](02-requisitos.md#rf32), [RF62](02-requisitos.md#rf62)  
**Requisitos não funcionais específicos:** [RNF06](02-requisitos.md#rnf06), [RNF09](02-requisitos.md#rnf09), [RNF11](02-requisitos.md#rnf11), [RNF25](02-requisitos.md#rnf25)  
**Casos de uso relacionados:** [UC10](03-casos-de-uso.md#uc10), [UC14](03-casos-de-uso.md#uc14), [UC05](03-casos-de-uso.md#uc05)

## RN65

**Tema:** Reconhecimento semanal e compartilhamento

Na virada da semana, na segunda-feira, o sistema apura automaticamente o primeiro lugar em pontos da semana anterior encerrada (segunda a domingo), sem depender de o aplicativo estar aberto. Pontos são a soma dos pesos de conclusões válidas creditadas aos responsáveis finais. Quantidade de tarefas é informação complementar, não o critério principal. Kids só recebem crédito após confirmação ou conclusão manual válida por adulto. Não há perda de pontos por tarefas pendentes.

A pessoa reconhecida é notificada e pode abrir uma visualização dentro do aplicativo com período, pontos, tarefas realizadas e convite para compartilhar via WhatsApp: “Mande para sua família e sugira algo para vocês fazerem juntos.” O envio depende da ação da pessoa, que escolhe o destinatário e confirma no WhatsApp. Cancelar ou não ter WhatsApp não perde o reconhecimento; oferecer copiar mensagem. O resultado permanece acessível dentro do app mesmo sem permissão de notificação externa.

Em caso de empate, todos os empatados no primeiro lugar são reconhecidos. Premissas para revisão: todos os perfis ativos, inclusive Kids, são elegíveis; semana sem pontuação positiva não gera vencedor. Registrar um resultado por família/semana e uma notificação por pessoa reconhecida, evitando duplicidade em retentativas. O fuso/horário exato e a política de revisão de resultado após reabertura tardia são decisões pendentes; devem ser resolvidos antes da implementação da apuração.

**Requisitos funcionais:** [RF63](02-requisitos.md#rf63), [RF64](02-requisitos.md#rf64)  
**Requisitos não funcionais específicos:** [RNF04](02-requisitos.md#rnf04), [RNF06](02-requisitos.md#rnf06), [RNF10](02-requisitos.md#rnf10), [RNF12](02-requisitos.md#rnf12), [RNF26](02-requisitos.md#rnf26), [RNF27](02-requisitos.md#rnf27)  
**Casos de uso relacionados:** [UC19](03-casos-de-uso.md#uc19)

## Histórico de versões

| Versão | Data | Alteração |
|---|---|---|
| 1.4 | 2026-10-02 | Família concentra indicadores, lista, inclusão de membros e PDF; detalhe do membro reúne tarefas Dia/Semana, edição e reenvio quando permitidos. RN60–61, RF60–61/RF66 e UC02/11/13/18 revisados. |
| 1.3 | 2026-10-02 | Duas abas Kids, câmera direta, foto/apelido e badges, progresso/carga Dia/Semana, PDF semanal e reconhecimento com WhatsApp; RN61–65, RF61–66, RNF26–27 e UC18–19. Empates e visibilidade do apelido confirmados. |
| 1.2 | 2026-10-01 | Área Família na navegação adulta, progresso coletivo diário e consulta por carrossel: RN60, RF60 e UC11. Design em elaboração na versão 1.0. |
| 1.1 | 2026-10-01 | Recuperação do mesmo perfil por novo convite e renovação sem expiração temporal, com revogação preservada: RN47, RF41, RF46, RF54, RNF22, UC02 e UC09. |
| 1.0 | 2026-10-01 | Primeira versão consolidada, incluindo todas as decisões registradas até esta publicação e links para a visão e a apresentação do projeto. |
