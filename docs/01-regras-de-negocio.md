# Regras de negócio

**Projeto:** App de Organização Familiar — MVP  
**Versão:** 1.17\
**Data:** 2026-10-10\
**Situação:** base documental consolidada

[Projeto](../README.md) · [Visão do produto](00-visao-do-produto.md) · [Índice e versões](DOCUMENTACAO.md) · [Regras de negócio](01-regras-de-negocio.md) · [Requisitos](02-requisitos.md) · [Casos de uso](03-casos-de-uso.md) · [Diagramas UML](04-diagramas-de-caso-de-uso.md) · [Screen map](design/screen-map.md) · [Diagrama de classes](06-diagrama-de-classes.md)

Este documento contém todas as regras vigentes da versão 1.15. Os requisitos concretizam essas regras, e os casos de uso descrevem os fluxos em que são aplicadas. As referências de UC nesta página são derivadas dos requisitos relacionados.

**Identificadores preservados:** RN15, RN29 e RN32 não estavam definidos na base recebida e permanecem não utilizados. Não representam conteúdo faltante desta versão.

## Índice de regras

[RN01](#rn01) · [RN02](#rn02) · [RN03](#rn03) · [RN04](#rn04) · [RN05](#rn05) · [RN06](#rn06) · [RN07](#rn07) · [RN08](#rn08) · [RN09](#rn09) · [RN10](#rn10) · [RN11](#rn11) · [RN12](#rn12) · [RN13](#rn13) · [RN14](#rn14) · [RN16](#rn16) · [RN17](#rn17) · [RN18](#rn18) · [RN19](#rn19) · [RN20](#rn20) · [RN21](#rn21) · [RN22](#rn22) · [RN23](#rn23) · [RN24](#rn24) · [RN25](#rn25) · [RN26](#rn26) · [RN27](#rn27) · [RN28](#rn28) · [RN30](#rn30) · [RN31](#rn31) · [RN33](#rn33) · [RN34](#rn34) · [RN35](#rn35) · [RN36](#rn36) · [RN37](#rn37) · [RN38](#rn38) · [RN39](#rn39) · [RN40](#rn40) · [RN41](#rn41) · [RN42](#rn42) · [RN43](#rn43) · [RN44](#rn44) · [RN45](#rn45) · [RN46](#rn46) · [RN47](#rn47) · [RN48](#rn48) · [RN49](#rn49) · [RN50](#rn50) · [RN51](#rn51) · [RN52](#rn52) · [RN53](#rn53) · [RN54](#rn54) · [RN55](#rn55) · [RN56](#rn56) · [RN57](#rn57) · [RN58](#rn58) · [RN59](#rn59) · [RN60](#rn60) · [RN61](#rn61) · [RN62](#rn62) · [RN63](#rn63) · [RN64](#rn64) · [RN65](#rn65) · [RN66](#rn66) · [RN67](#rn67)

## RN01

Quem cria a família se torna automaticamente Administrador e Criador da Família, identificado pela flag isFamilyCreator. A família pode ter mais de um Administrador, todos com as mesmas permissões, exceto as proteções exclusivas do Criador.

Quando a identidade Apple ainda não possui família, a pessoa primeiro configura o rascunho do próprio perfil: nome administrativo obrigatório, etiqueta/apelido opcional e foto opcional. Esse rascunho não constitui perfil persistido nem concede acesso; seus dados passam a compor o perfil do Criador somente na criação confirmada da família. Depois de criada a família e a sessão do Criador, o onboarding permite adicionar zero ou mais membros antes da entrada na área principal.

**Requisitos funcionais:** [RF01](02-requisitos.md#rf01), [RF05](02-requisitos.md#rf05), [RF38](02-requisitos.md#rf38), [RF48](02-requisitos.md#rf48)\
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
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
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02)

## RN07

Apenas Administradores podem adicionar, editar e remover membros administrativamente. A edição do próprio perfil é permitida a todos conforme RN63; a configuração de etiqueta/apelido pertence exclusivamente ao titular, inclusive quando o titular é Kids. No onboarding de uma família recém-criada, o Criador já autenticado atua como Administrador e pode repetir a adição normal de membros ou avançar sem adicionar nenhum.

**Requisitos funcionais:** [RF02](02-requisitos.md#rf02), [RF03](02-requisitos.md#rf03), [RF04](02-requisitos.md#rf04), [RF40](02-requisitos.md#rf40)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02)

## RN08

Apenas Administradores podem ativar ou desativar o Modo Kids de um perfil. Um Administrador não pode estar em Modo Kids.

**Requisitos funcionais:** [RF03](02-requisitos.md#rf03), [RF06](02-requisitos.md#rf06)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02)

## RN09

Cada perfil pertence a uma única família. Ao autenticar-se, o Criador que já possui família vinculada é redirecionado para ela; sem vínculo, inicia o onboarding de perfil, família e membros. Abrir convite com sessão ativa permite confirmar a troca de acesso para o perfil indicado; não transfere o perfil ou histórico nem remove o membro da família anterior. A sessão local só é substituída após ingresso válido. A proteção do Criador em sua família permanece.

**Requisitos funcionais:** [RF01](02-requisitos.md#rf01), [RF38](02-requisitos.md#rf38), [RF68](02-requisitos.md#rf68)\
**Requisitos não funcionais específicos:** [RNF06](02-requisitos.md#rnf06)  
**Casos de uso relacionados:** [UC01](03-casos-de-uso.md#uc01), [UC09](03-casos-de-uso.md#uc09)

## RN10

A remoção de um membro revoga seu acesso, inclusive por sessão existente, renovação e fotos. Nas tarefas futuras ainda não concluídas e não protegidas, retirar somente esse membro da lista de responsáveis; preservar os demais e deixar sem responsável apenas se a lista ficar vazia. Não há alteração automática das tarefas antigas pendentes, das futuras já concluídas ou das protegidas por conquistas. Preservar histórico, créditos e participações já registrados.

**Requisitos funcionais:** [RF04](02-requisitos.md#rf04), [RF43](02-requisitos.md#rf43)  
**Requisitos não funcionais específicos:** [RNF06](02-requisitos.md#rnf06), [RNF09](02-requisitos.md#rnf09), [RNF18](02-requisitos.md#rnf18), [RNF22](02-requisitos.md#rnf22), [RNF24](02-requisitos.md#rnf24)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

## RN11

Toda tarefa tem título, peso e data prevista. Responsáveis são opcionais. A data começa no dia atual do fuso da família e pode ser alterada para qualquer data passada ou futura, inclusive antes da criação da família e em outros meses, sem limites de produto no DatePicker. A mesma liberdade aplica-se à data inicial da rotina. Os limites de consulta do carrossel em RN49 não limitam o cadastro ou a edição de datas. O título tem de 1 a 60 caracteres Unicode visíveis após trim, sem caracteres de controle, no mesmo padrão aplicado ao nome da família (RF01).

**Requisitos funcionais:** [RF07](02-requisitos.md#rf07), [RF10](02-requisitos.md#rf10), [RF13](02-requisitos.md#rf13), [RF15](02-requisitos.md#rf15)  
**Requisitos não funcionais específicos:** [RNF02](02-requisitos.md#rnf02)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08)

## RN12

Tarefas podem ter mais de um responsável.

**Requisitos funcionais:** [RF10](02-requisitos.md#rf10)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08)

## RN13

O peso é obrigatório e vai de 1 a 3: 1 = pouco esforço, 2 = médio esforço e 3 = alto esforço.

**Requisitos funcionais:** [RF15](02-requisitos.md#rf15), [RF16](02-requisitos.md#rf16)  
**Requisitos não funcionais específicos:** [RNF02](02-requisitos.md#rnf02)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07)

## RN14

A criação oferece tarefa única ou rotina, com data inicial escolhida em DatePicker e frequência diária ou a cada 7, 14, 21 ou 28 dias (1, 2, 3 ou 4 semanas). A rotina pode transportar a observação opcional da tarefa, nos limites de RN67. Não existe frequência mensal nem data final obrigatória. O backend materializa ocorrências até o fim do mês seguinte ao atual no fuso da família, repõe o horizonte diariamente e completa a geração em consultas quando necessário. Rotina que começa depois do horizonte fica salva e gera ocorrências quando alcançada; início passado é respeitado, com processamento em lotes se necessário, sem truncar silenciosamente o período. Retentativas não duplicam ocorrências.

**Requisitos funcionais:** [RF13](02-requisitos.md#rf13), [RF14](02-requisitos.md#rf14), [RF70](02-requisitos.md#rf70)
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC08](03-casos-de-uso.md#uc08)

## RN16

Cada tarefa, inclusive a gerada por uma rotina, possui identificação e status próprios. Concluir uma tarefa não altera as demais tarefas da mesma rotina.

**Requisitos funcionais:** [RF13](02-requisitos.md#rf13), [RF17](02-requisitos.md#rf17), [RF50](02-requisitos.md#rf50)  
**Requisitos não funcionais específicos:** [RNF09](02-requisitos.md#rnf09)  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC08](03-casos-de-uso.md#uc08), [UC11](03-casos-de-uso.md#uc11)

## RN17

A edição individual altera apenas a tarefa escolhida. Edições da rotina no alcance “selecionada e futuras” incluem a ocorrência selecionada e afetam somente as futuras abrangidas, preservando passado e ocorrências concluídas/protegidas. Uma tarefa concluída pode ser editada individualmente se não estiver protegida por missão concluída: título, peso, data prevista e responsáveis são ajustáveis. Peso e responsáveis atualizam o crédito vigente; data prevista atualiza o progresso, sem alterar o instante original da conclusão. Sem responsáveis, a tarefa continua concluída e conta no progresso familiar, mas não gera crédito individual. Registrar autor, instante e valores anteriores na auditoria. Destaques já apurados e PDFs exportados permanecem preservados. Nas edições válidas, prevalece a última gravação efetivada pelo servidor, sem rejeição por versão antiga; permissões e proteções continuam sendo verificadas.

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

Administradores e Membros podem concluir tarefas da família que não tenham responsável Kids, ainda que não sejam responsáveis. Tarefas com ao menos um responsável Kids só podem ser concluídas manualmente por Administrador. Kids somente sinalizam tarefas sob sua responsabilidade. Ao concluir tarefa atribuída a outras pessoas, o adulto autorizado escolhe manter os responsáveis ou substituí-los por si mesmo, após ser informado dos efeitos sobre o crédito da conclusão.

**Requisitos funcionais:** [RF12](02-requisitos.md#rf12), [RF23](02-requisitos.md#rf23)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC12](03-casos-de-uso.md#uc12), [UC15](03-casos-de-uso.md#uc15)

## RN22

Administradores e Membros podem concluir uma tarefa Pendente ou Aguardando confirmação sem responsável Kids. Tarefa com ao menos um responsável Kids, inclusive Aguardando confirmação, somente pode ser concluída manualmente por Administrador. A conclusão é única e vale para todos os responsáveis finais.

**Requisitos funcionais:** [RF12](02-requisitos.md#rf12), [RF17](02-requisitos.md#rf17), [RF24](02-requisitos.md#rf24), [RF26](02-requisitos.md#rf26)  
**Requisitos não funcionais específicos:** [RNF02](02-requisitos.md#rnf02), [RNF11](02-requisitos.md#rnf11)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC15](03-casos-de-uso.md#uc15)

## RN23

A sinalização de um perfil Kids altera a tarefa de Pendente para Aguardando confirmação, sem gerar conclusão parcial. A confirmação por Administrador ou a conclusão manual por Administrador torna a tarefa Concluída para todos os responsáveis. A conclusão manual encerra a pendência e preserva a sinalização e a foto opcional exclusivamente para auditoria administrativa.

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
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03)

## RN26

Tarefas aguardando confirmação não contam para carga, progresso diário ou semanal concluído ou progresso de missões. Passam a contar após confirmação ou conclusão manual válida por adulto.

**Requisitos funcionais:** [RF19](02-requisitos.md#rf19), [RF26](02-requisitos.md#rf26), [RF30](02-requisitos.md#rf30), [RF49](02-requisitos.md#rf49)  
**Requisitos não funcionais específicos:** [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC11](03-casos-de-uso.md#uc11), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14)

## RN27

Tarefas não realizadas não geram penalidade nem perda de pontos. O checklist abre por padrão no dia atual e permite consultar outras datas conforme [RN49](01-regras-de-negocio.md#rn49). Aguardando confirmação permanece um estado distinto de Pendente até decisão válida.

**Requisitos funcionais:** [RF11](02-requisitos.md#rf11), [RF17](02-requisitos.md#rf17), [RF22](02-requisitos.md#rf22)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC11](03-casos-de-uso.md#uc11)

## RN28

A semana vai de segunda-feira a domingo no fuso IANA da família, cujo padrão na criação é `America/Sao_Paulo`, com possibilidade de escolha. Somente Administradores podem alterar o fuso em Configurações da família. Antes de salvar, mostrar informativo e permitir aplicação imediata ou no próximo ciclo semanal. Cancelar não altera o fuso. Aplicação imediata preserva o início do ciclo aberto e ajusta seu encerramento à próxima segunda-feira local no novo fuso, estritamente após a mudança; a programada preserva o ciclo em curso e entra em vigor no seu encerramento. Registrar fuso, início/fim e transição de cada ciclo para evitar lacunas, sobreposição e nova apuração de período já encerrado. A semana de transição pode ter duração diferente, explicitada na consulta e no relatório. Datas previstas permanecem datas civis, sem deslocamento automático das tarefas. Consultas, PDF e apuração usam os mesmos limites; resultados finalizados não mudam com a troca de fuso. Apuração é elegível às 00:00 de segunda-feira local (primeiro instante válido daquela data), com execução e recuperação no servidor.

**Requisitos funcionais:** [RF18](02-requisitos.md#rf18), [RF63](02-requisitos.md#rf63), [RF66](02-requisitos.md#rf66), [RF67](02-requisitos.md#rf67)\
**Requisitos não funcionais específicos:** [RNF10](02-requisitos.md#rnf10)  
**Casos de uso relacionados:** [UC01](03-casos-de-uso.md#uc01), [UC11](03-casos-de-uso.md#uc11), [UC13](03-casos-de-uso.md#uc13), [UC19](03-casos-de-uso.md#uc19)

## RN30

A carga de um membro é a soma dos pesos integrais das tarefas com conclusão válida no dia ou na semana selecionada nas quais ele consta como responsável da conclusão. Em tarefas compartilhadas, cada responsável recebe o peso integral. Executar a ação de concluir não gera crédito para quem não for responsável. Crédito válido de perfil posteriormente removido permanece nos períodos históricos e é apresentado como “Membro removido”, sem expor dados pessoais além dessa identificação. Pontos do destaque semanal usam essa mesma soma, sem uma segunda moeda de pontuação.

**Requisitos funcionais:** [RF15](02-requisitos.md#rf15), [RF18](02-requisitos.md#rf18), [RF19](02-requisitos.md#rf19), [RF20](02-requisitos.md#rf20), [RF56](02-requisitos.md#rf56), [RF63](02-requisitos.md#rf63)  
**Requisitos não funcionais específicos:** [RNF03](02-requisitos.md#rnf03), [RNF10](02-requisitos.md#rnf10)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC07](03-casos-de-uso.md#uc07), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC15](03-casos-de-uso.md#uc15), [UC19](03-casos-de-uso.md#uc19)

## RN31

A carga total da família é a soma das cargas individuais, inclusive créditos históricos de membro removido. A participação de cada membro é sua carga dividida pela carga total, em percentual. Quando o total for zero, não se realiza divisão por zero.

**Requisitos funcionais:** [RF20](02-requisitos.md#rf20), [RF21](02-requisitos.md#rf21)  
**Requisitos não funcionais específicos:** [RNF03](02-requisitos.md#rnf03), [RNF10](02-requisitos.md#rnf10)  
**Casos de uso relacionados:** [UC13](03-casos-de-uso.md#uc13)

## RN33

Todos os perfis visualizam seu próprio progresso diário. Administradores e Membros também visualizam o progresso familiar e a distribuição da carga/sobrecarga por dia ou semana. Kids não acessam a distribuição de carga, a área Família nem o relatório familiar. Podem receber seu próprio reconhecimento semanal conforme RN65.

**Requisitos funcionais:** [RF20](02-requisitos.md#rf20), [RF49](02-requisitos.md#rf49), [RF65](02-requisitos.md#rf65), [RF66](02-requisitos.md#rf66)  
**Requisitos não funcionais específicos:** [RNF04](02-requisitos.md#rnf04), [RNF06](02-requisitos.md#rnf06)  
**Casos de uso relacionados:** [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14)

## RN34

A visualização de carga apresenta distribuição e equilíbrio. O destaque de primeiro lugar semanal é uma funcionalidade específica prevista em RN65, com convite a uma atividade em família. Não há ranking completo, competição entre famílias ou penalidade para os demais membros.

**Requisitos funcionais:** [RF20](02-requisitos.md#rf20), [RF21](02-requisitos.md#rf21)  
**Requisitos não funcionais específicos:** [RNF03](02-requisitos.md#rnf03)  
**Casos de uso relacionados:** [UC13](03-casos-de-uso.md#uc13)

## RN35

Missões são coletivas. O progresso corresponde à quantidade de tarefas individuais vinculadas concluídas dividida pelo total de tarefas vinculadas, em percentual. Cada tarefa conta uma vez, independentemente de quantos responsáveis possua.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF30](02-requisitos.md#rf30), [RF50](02-requisitos.md#rf50), [RF56](02-requisitos.md#rf56)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC05](03-casos-de-uso.md#uc05), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15)

## RN36

Uma missão possui ao menos uma tarefa individual vinculada e não tem prazo. Seu objetivo é concluir todas as tarefas vinculadas. Não há selo configurável por missão: badges seguem os marcos de participação em RN64. A recompensa coletiva é definida por sorteio no aplicativo e aceitação registrada no servidor após a conclusão.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF31](02-requisitos.md#rf31), [RF32](02-requisitos.md#rf32), [RF35](02-requisitos.md#rf35), [RF50](02-requisitos.md#rf50)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16)

## RN37

Apenas Administradores criam missões, de forma personalizada.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05)

## RN38

Quando todas as tarefas vinculadas estiverem concluídas, o servidor conclui a missão, registra uma participação por membro elegível conforme RN64, concede os badges cujos marcos forem atingidos e habilita o resgate. Participação e badges independem do resgate. Uma reabertura confirmada de tarefa vinculada pode retornar a missão para Em andamento conforme RN57, revertendo suas participações, badges e recompensa aceita na mesma transação.

**Requisitos funcionais:** [RF31](02-requisitos.md#rf31), [RF32](02-requisitos.md#rf32), [RF35](02-requisitos.md#rf35), [RF36](02-requisitos.md#rf36), [RF51](02-requisitos.md#rf51), [RF52](02-requisitos.md#rf52), [RF58](02-requisitos.md#rf58)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)

## RN39

Missões não expiram por tempo. Permanecem em andamento enquanto houver tarefas vinculadas pendentes ou aguardando confirmação, sem penalidade por demora.

**Requisitos funcionais:** [RF31](02-requisitos.md#rf31)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC14](03-casos-de-uso.md#uc14)

## RN40

Não existem missões individuais nem competição entre membros ou entre famílias.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05)

## RN41

Recompensas são coletivas e beneficiam a família inteira.

**Requisitos funcionais:** [RF33](02-requisitos.md#rf33), [RF34](02-requisitos.md#rf34)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC06](03-casos-de-uso.md#uc06)

## RN42

A roleta oferece os itens predefinidos “Escolher o filme da noite”, “Escolher o jantar em família”, “Noite de jogos em família”, “Sobremesa especial”, “Piquenique ou passeio no parque” e “Escolher uma atividade em família”, além de itens personalizados adicionados por Administradores. O título de item personalizado é obrigatório, não pode conter caracteres de controle e admite até 60 caracteres não-espaço após `trim`; sua descrição é opcional e admite até 255 caracteres, contando espaços. Na mesma família, títulos personalizados são únicos após `trim`, sem distinguir maiúsculas de minúsculas. Somente Administradores podem adicionar itens, sortear e aceitar recompensas. Adicionar um item o torna elegível para sorteios, sem vinculá-lo automaticamente a uma missão.

**Requisitos funcionais:** [RF34](02-requisitos.md#rf34), [RF51](02-requisitos.md#rf51), [RF52](02-requisitos.md#rf52)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07)  
**Casos de uso relacionados:** [UC06](03-casos-de-uso.md#uc06), [UC16](03-casos-de-uso.md#uc16)

## RN43

Uma missão concluída sem resgate permite ao Administrador abrir a roleta. O aplicativo obtém o catálogo elegível e realiza sorteio e animação localmente. Resultados recusados não precisam ser persistidos. Ao aceitar, o servidor valida perfil, item e disponibilidade e registra uma única recompensa. O servidor valida o resgate, sem alegar comprovação do sorteio local. Não há limite de novos sorteios antes do aceite. Se a missão retornar para Em andamento por reabertura confirmada de uma tarefa vinculada, a recompensa aceita é removida sem histórico.

**Requisitos funcionais:** [RF35](02-requisitos.md#rf35), [RF36](02-requisitos.md#rf36), [RF51](02-requisitos.md#rf51), [RF52](02-requisitos.md#rf52)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16)

## RN44

Apenas o Criador da Família se autentica via Sign in with Apple, e a família é vinculada ao identificador Apple dele. Uma identidade Apple sem vínculo não recebe acesso a dados familiares: ela segue somente o onboarding que coleta o rascunho do perfil e cria sua primeira família.

**Requisitos funcionais:** [RF37](02-requisitos.md#rf37), [RF38](02-requisitos.md#rf38), [RF39](02-requisitos.md#rf39)  
**Requisitos não funcionais específicos:** [RNF15](02-requisitos.md#rnf15), [RNF16](02-requisitos.md#rnf16)  
**Casos de uso relacionados:** [UC01](03-casos-de-uso.md#uc01), [UC04](03-casos-de-uso.md#uc04)

## RN45

Os demais perfis, inclusive Administradores promovidos e Kids, ingressam pelo link do perfil criado por um Administrador e pela senha de ingresso gerada pelo sistema e enviada junto com esse link.

**Requisitos funcionais:** [RF40](02-requisitos.md#rf40), [RF41](02-requisitos.md#rf41), [RF42](02-requisitos.md#rf42), [RF43](02-requisitos.md#rf43), [RF54](02-requisitos.md#rf54)  
**Requisitos não funcionais específicos:** [RNF17](02-requisitos.md#rnf17), [RNF18](02-requisitos.md#rnf18), [RNF20](02-requisitos.md#rnf20)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

## RN46

Link e senha vinculam uma família e um perfil e admitem um ingresso bem-sucedido, sem expiração temporal. Gerar ou reenviar convite sempre produz novo link e nova senha, invalida os convites anteriores ainda disponíveis e revoga a sessão anterior do perfil, na mesma operação. As credenciais são exibidas transitoriamente para envio conjunto; somente verificadores protegidos são persistidos. Senha incorreta não consome o convite. Consumo, ingresso e sessão são consistentes sob concorrência.

**Requisitos funcionais:** [RF41](02-requisitos.md#rf41), [RF42](02-requisitos.md#rf42), [RF43](02-requisitos.md#rf43), [RF44](02-requisitos.md#rf44), [RF46](02-requisitos.md#rf46), [RF54](02-requisitos.md#rf54), [RF68](02-requisitos.md#rf68)\
**Requisitos não funcionais específicos:** [RNF17](02-requisitos.md#rnf17), [RNF18](02-requisitos.md#rnf18), [RNF19](02-requisitos.md#rnf19), [RNF20](02-requisitos.md#rnf20), [RNF21](02-requisitos.md#rnf21)  
**Casos de uso relacionados:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

## RN47

Cada perfil mantém acesso em um único aparelho, representado por uma sessão ativa vinculada à instalação. Refresh token não expira por tempo e é revogável; token de acesso tem duração de 15 minutos, com verificação de sessão ativa em operações protegidas para revogação imediata no servidor. Recuperação de convidado usa novo convite para o mesmo perfil, sem recriar histórico. Novo convite revoga a sessão anterior já na emissão. Criador retorna por Apple e novo ingresso substitui a sessão anterior. Falha de rede não equivale a revogação. A recuperação específica de ingresso cuja resposta se perdeu exige prova da tentativa e instalação original, em janela de dez minutos, sem segundo consumo; fora dessa janela é necessário novo convite. Troca de acesso por convite com sessão ativa exige confirmação e não remove o perfil anterior da família.

**Requisitos funcionais:** [RF41](02-requisitos.md#rf41), [RF45](02-requisitos.md#rf45), [RF46](02-requisitos.md#rf46), [RF54](02-requisitos.md#rf54), [RF68](02-requisitos.md#rf68)\
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
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC11](03-casos-de-uso.md#uc11)

## RN50

Uma missão só pode ser salva com ao menos uma tarefa vinculada. Em missão em andamento, remover ou excluir sua última tarefa exige vincular outra antes de efetivar a operação. Missões concluídas não admitem alteração dos vínculos.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF50](02-requisitos.md#rf50), [RF59](02-requisitos.md#rf59)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC17](03-casos-de-uso.md#uc17)

## RN51

O vínculo com a missão é feito por tarefa individual. Tarefas geradas pela mesma rotina são selecionadas separadamente. Vincular uma tarefa não vincula sua rotina nem inclui automaticamente outras tarefas já existentes ou geradas posteriormente.

**Requisitos funcionais:** [RF28](02-requisitos.md#rf28), [RF29](02-requisitos.md#rf29), [RF30](02-requisitos.md#rf30), [RF50](02-requisitos.md#rf50)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC14](03-casos-de-uso.md#uc14)

## RN52

Enquanto a recompensa não for aceita, o Administrador pode recusar o resultado e realizar novos sorteios até decidir aceitá-la. Sair da roleta sem aceitar mantém a missão concluída e o resgate disponível.

**Requisitos funcionais:** [RF36](02-requisitos.md#rf36), [RF51](02-requisitos.md#rf51), [RF52](02-requisitos.md#rf52)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
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

Concluir uma tarefa não exibe alerta nem oferece escolha de responsáveis. Se houver responsáveis, eles são mantidos e recebem o crédito; se não houver, o adulto que conclui torna-se o único responsável. A atribuição automática só é efetivada junto com a conclusão confirmada.

**Requisitos funcionais:** [RF12](02-requisitos.md#rf12), [RF47](02-requisitos.md#rf47), [RF56](02-requisitos.md#rf56)  
**Requisitos não funcionais específicos:** [RNF10](02-requisitos.md#rnf10)  
**Casos de uso relacionados:** [UC03](03-casos-de-uso.md#uc03), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC15](03-casos-de-uso.md#uc15)

## RN57

Administradores e Membros podem retornar qualquer tarefa acessível da família para Pendente; Kids podem fazê-lo em tarefas próprias. A reabertura remove a contribuição da conclusão anterior da carga de todos os responsáveis e do progresso das missões vinculadas, inclusive ajustando uma semana passada. Quando atingir missão concluída ou recompensa aceita, exige confirmação explícita: retorna a missão para Em andamento, remove a recompensa aceita sem histórico e recalcula participações e badges derivados daquela missão na mesma transação.

**Requisitos funcionais:** [RF09](02-requisitos.md#rf09), [RF18](02-requisitos.md#rf18), [RF19](02-requisitos.md#rf19), [RF57](02-requisitos.md#rf57), [RF59](02-requisitos.md#rf59)  
**Requisitos não funcionais específicos:** [RNF07](02-requisitos.md#rnf07), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10), [RNF11](02-requisitos.md#rnf11), [RNF25](02-requisitos.md#rnf25)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07), [UC13](03-casos-de-uso.md#uc13), [UC17](03-casos-de-uso.md#uc17)

## RN58

Missões concluídas não podem ter seus dados ou vínculos editados ou ser excluídas. Uma reabertura confirmada de tarefa vinculada é a exceção: ela retorna a missão para Em andamento e remove os dados derivados do encerramento — participações, badges que dependam dela e recompensa aceita — sem preservar histórico. O registro da recompensa aceita continua permitido exclusivamente pelo fluxo de resgate único enquanto a missão estiver concluída.

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

Gerar relatório semanal em PDF fica na própria tela Família para adultos. Adicionar membro também fica nessa tela, exclusivamente para Administradores. Editar perfil e gerar/reenviar convite ficam no detalhe do membro, exclusivamente para Administradores e conforme as restrições do perfil; não permitem editar apelido de terceiros. Gerar ou reenviar emite novo link e senha para o mesmo perfil, invalida convites anteriores e revoga a sessão anterior; informar esses efeitos antes de confirmar. O Criador retorna por Apple. Confirmações Kids permanecem exclusivas dos Administradores. Kids não acessam esta área.

**Requisitos funcionais:** [RF60](02-requisitos.md#rf60), [RF66](02-requisitos.md#rf66)  
**Requisitos não funcionais específicos:** [RNF01](02-requisitos.md#rnf01), [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF09](02-requisitos.md#rnf09)  
**Casos de uso relacionados:** [UC11](03-casos-de-uso.md#uc11), [UC13](03-casos-de-uso.md#uc13)

## RN61

**Tema:** Períodos e métricas

Minhas tarefas (todos os perfis) é uma consulta diária: mostra as tarefas próprias e o progresso da data selecionada, sem alternância Dia/Semana. Os indicadores integrados de Minha família, a consulta complementar de tarefas familiares e as tarefas no detalhe do membro (adultos) oferecem alternância Dia/Semana. A semana contém a data selecionada e vai de segunda a domingo. O intervalo de consulta de tarefas continua da criação da família até o último dia do mês corrente; nas semanas de borda, informar os dias efetivamente disponíveis. O progresso pessoal conta tarefas próprias concluídas sobre o total próprio previsto no dia; o familiar usa RN60. O progresso semanal familiar é calculado sobre os totais da semana, nunca pela média simples dos percentuais diários.

A carga/sobrecarga usa a data da conclusão válida, enquanto o progresso usa as tarefas previstas para o período e seu estado atual. Uma tarefa atrasada pode contribuir para a carga de hoje e para o progresso do dia em que estava prevista. Crédito histórico de perfil removido permanece em linha identificada como “Membro removido”. A carga indica participação creditada, sem limiar de diagnóstico de sobrecarga definido. Seleção, gráficos e rótulos devem explicitar período e métrica. Sem tarefas ou carga, informar ausência de dados; não simular 100%.

**Requisitos funcionais:** [RF18](02-requisitos.md#rf18), [RF49](02-requisitos.md#rf49), [RF60](02-requisitos.md#rf60), [RF66](02-requisitos.md#rf66)  
**Requisitos não funcionais específicos:** [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF09](02-requisitos.md#rnf09), [RNF10](02-requisitos.md#rnf10)  
**Casos de uso relacionados:** [UC11](03-casos-de-uso.md#uc11), [UC13](03-casos-de-uso.md#uc13)

## RN62

**Tema:** Relatório semanal em PDF

O backend fornece um snapshot consistente e o aplicativo gera o arquivo. Administradores e Membros podem gerar um relatório familiar em PDF para uma semana selecionada de segunda a domingo. O documento identifica família, período e momento de geração, inclui gráficos da distribuição de carga semanal por membro e do progresso total da família, além do peso total creditado e número de tarefas realizadas por membro. O gráfico de progresso usa concluídas/total de tarefas previstas para a semana (RN60); peso e quantidade realizada por membro usam conclusões válidas naquela semana (RN30).

Uma tarefa compartilhada conta uma vez para cada responsável no número individual e credita o peso integral a cada um; o total familiar de tarefas realizadas conta tarefas distintas, sem somar contagens individuais. O relatório explica essa diferença. Crédito histórico de perfil removido é identificado como “Membro removido”, sem dado pessoal. A semana é selecionada por data de referência e resolvida de segunda a domingo no fuso da família. Semana atual é identificada como parcial até o momento da geração; semanas futuras não geram relatório. Na semana de criação, manter o intervalo explícito e considerar as tarefas retroativas cadastradas; não presumir ausência de dados apenas por uma data prevista anteceder a criação da família. Semana sem dados pode gerar relatório com zeros e indicação “Sem tarefas” onde aplicável. O PDF reflete os dados no momento de geração; reabrir uma tarefa exige gerar novo arquivo para obter valores atualizados. Não incluir fotos de validação, credenciais ou configuração privada de perfil.

**Requisitos funcionais:** [RF61](02-requisitos.md#rf61)  
**Requisitos não funcionais específicos:** [RNF05](02-requisitos.md#rnf05), [RNF06](02-requisitos.md#rnf06), [RNF10](02-requisitos.md#rnf10), [RNF12](02-requisitos.md#rnf12), [RNF13](02-requisitos.md#rnf13), [RNF26](02-requisitos.md#rnf26), [RNF27](02-requisitos.md#rnf27)  
**Casos de uso relacionados:** [UC18](03-casos-de-uso.md#uc18)

## RN63

**Tema:** Foto e etiqueta/apelido do perfil

Todos os perfis, inclusive Kids, podem adicionar, substituir ou remover a própria foto, que é opcional. Sem foto, exibir identificação padrão. Todos podem configurar a própria etiqueta/apelido; outras pessoas, inclusive Administradores, não acessam sua configuração nem podem alterá-la. O nome de identificação permanece separado do apelido. A pessoa que ainda criará a família informa esses mesmos dados no rascunho inicial; a foto e a etiqueta permanecem opcionais e não impedem a criação.

O apelido é opcional: vazio ou nulo remove a configuração vigente. Admite até 20 caracteres não-espaço após remover espaços nas extremidades; espaços internos não contam para esse limite. Não admite caracteres de controle.

O apelido é visível à família, com edição exclusiva do titular. A foto de perfil pode ser escolhida por câmera ou galeria, inclusive por Kids; isso não altera a câmera direta da sinalização Kids. Kids acessam Meu perfil pelo avatar/cabeçalho, sem terceira aba no tab bar.

**Requisitos funcionais:** [RF01](02-requisitos.md#rf01), [RF38](02-requisitos.md#rf38), [RF48](02-requisitos.md#rf48), [RF65](02-requisitos.md#rf65)\
**Requisitos não funcionais específicos:** [RNF06](02-requisitos.md#rnf06), [RNF07](02-requisitos.md#rnf07), [RNF12](02-requisitos.md#rnf12), [RNF24](02-requisitos.md#rnf24), [RNF27](02-requisitos.md#rnf27)  
**Casos de uso relacionados:** [UC01](03-casos-de-uso.md#uc01), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC14](03-casos-de-uso.md#uc14)

## RN64

**Tema:** Participação em missões e badges por marcos

Ao concluir uma missão, registrar uma participação por membro que figure como responsável creditado em pelo menos uma conclusão válida de tarefa vinculada. Quem apenas executou o clique ou confirmou sinalização, sem receber crédito, não participa por essa ação. Várias tarefas da mesma missão contam uma única missão por pessoa. A participação é registrada no encerramento; se a missão for reaberta, ela e os badges cuja elegibilidade for alterada são recalculados. Não se concede retroativamente a quem entrar depois.

O total de missões com participação concede badges fixos e cumulativos: bronze (`bronze`) em 5, prata (`silver`) em 10, ouro (`gold`) em 25 e diamante (`diamond`) em 50. Concessão é única por membro/marco; os anteriores são mantidos. Não existe seleção ou criação de selo por missão, nem concessão a todos apenas por pertencerem à família. No perfil, o detalhe do marco mostra as missões que contribuíram para ele e permite abrir cada missão. Participação e badges independem do resgate da recompensa.

**Requisitos funcionais:** [RF32](02-requisitos.md#rf32), [RF62](02-requisitos.md#rf62)  
**Requisitos não funcionais específicos:** [RNF06](02-requisitos.md#rnf06), [RNF09](02-requisitos.md#rnf09), [RNF11](02-requisitos.md#rnf11), [RNF25](02-requisitos.md#rnf25)  
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05), [UC10](03-casos-de-uso.md#uc10), [UC14](03-casos-de-uso.md#uc14)

## RN65

**Tema:** Reconhecimento semanal e compartilhamento

Às 00:00 de segunda-feira no fuso configurado da família, o sistema apura automaticamente o primeiro lugar em pontos da semana anterior encerrada (segunda a domingo), sem depender de o aplicativo estar aberto. Pontos são a soma dos pesos de conclusões válidas creditadas aos responsáveis finais. Quantidade de tarefas é informação complementar, não o critério principal. Kids só recebem crédito após confirmação ou conclusão manual válida por adulto. Não há perda de pontos por tarefas pendentes.

A pessoa reconhecida é notificada e pode abrir uma visualização dentro do aplicativo com período, pontos, tarefas realizadas e convite para compartilhar via WhatsApp: “Mande para sua família e sugira algo para vocês fazerem juntos.” O envio depende da ação da pessoa, que escolhe o destinatário e confirma no WhatsApp. Cancelar ou não ter WhatsApp não perde o reconhecimento; oferecer copiar mensagem. O resultado permanece acessível dentro do app mesmo sem permissão de notificação externa.

Em empate, todos os primeiros são reconhecidos. Todos os perfis ativos, inclusive Kids, são elegíveis; sem pontuação positiva, registrar semana sem vencedor. Registrar um resultado final por família/ciclo e uma intenção de notificar por reconhecido. Reabertura ou edição posterior de tarefa não revisa destaque nem gera nova notificação; carga vigente e novos PDFs refletem a correção. O backend recupera processamentos incompletos. Aceitação do envio pelo APNs não comprova entrega ou leitura; o destaque continua acessível no app. Os ciclos e transições de fuso seguem RN28.

**Requisitos funcionais:** [RF63](02-requisitos.md#rf63), [RF64](02-requisitos.md#rf64), [RF67](02-requisitos.md#rf67)\
**Requisitos não funcionais específicos:** [RNF04](02-requisitos.md#rnf04), [RNF06](02-requisitos.md#rnf06), [RNF10](02-requisitos.md#rnf10), [RNF12](02-requisitos.md#rnf12), [RNF26](02-requisitos.md#rnf26), [RNF27](02-requisitos.md#rnf27)  
**Casos de uso relacionados:** [UC01](03-casos-de-uso.md#uc01), [UC19](03-casos-de-uso.md#uc19)

## RN66

Editar uma tarefa Aguardando confirmação exige que o Administrador ou o Membro escolha, no mesmo salvamento, entre retornar a tarefa a Pendente — descartando a sinalização corrente, que a criança pode refazer — ou manter o estado Aguardando confirmação com os dados atualizados e a sinalização corrente intacta para decisão. A escolha é obrigatória em qualquer edição salva nesse estado, independentemente de quais campos foram alterados. Excluir uma tarefa Aguardando confirmação remove a sinalização corrente junto com a tarefa, sem registrar confirmação ou recusa.

**Requisitos funcionais:** [RF08](02-requisitos.md#rf08), [RF09](02-requisitos.md#rf09), [RF69](02-requisitos.md#rf69)  
**Requisitos não funcionais específicos:** [RNF09](02-requisitos.md#rnf09), [RNF11](02-requisitos.md#rnf11)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07), [UC03](03-casos-de-uso.md#uc03), [UC15](03-casos-de-uso.md#uc15)

## RN67

Toda tarefa pode ter uma observação opcional de até 250 caracteres, contando espaços. A observação não participa do cálculo de esforço, crédito ou carga e segue as mesmas regras de edição e proteção dos demais campos da tarefa (RN17, RN58).

**Requisitos funcionais:** [RF13](02-requisitos.md#rf13), [RF70](02-requisitos.md#rf70)
**Requisitos não funcionais específicos:** [RNF02](02-requisitos.md#rnf02)  
**Casos de uso relacionados:** [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08)

## RN68

A missão admite uma observação opcional de até 250 caracteres, contando espaços. A observação não participa do cálculo de progresso, participação ou badges e segue as mesmas regras de edição e proteção da missão (RN50, RN58).

**Requisitos funcionais:** [RF71](02-requisitos.md#rf71)  
**Requisitos não funcionais específicos:** Sem vínculo específico; requisitos transversais se aplicam conforme a operação.\
**Casos de uso relacionados:** [UC05](03-casos-de-uso.md#uc05)

## Histórico de versões

| Versão | Data | Alteração |
|---|---|---|
| 1.17 | 2026-10-10 | RN62 define `referenceDate` para resolver a semana do PDF e identifica crédito histórico como “Membro removido”. Para SPEC-019. |
| 1.16 | 2026-10-10 | RN30, RN31 e RN61 preservam carga histórica de perfil removido em linha “Membro removido”, sem expor dados pessoais. Para SPEC-018. |
| 1.15 | 2026-10-10 | RN42 passa a definir o catálogo predefinido e o cadastro de item personalizado: título obrigatório com até 60 caracteres não-espaço após `trim`, unicidade por família sem distinguir maiúsculas/minúsculas e descrição opcional de até 255 caracteres. Para SPEC-015. |
| 1.14 | 2026-10-07 | Onboarding do Criador passa a coletar rascunho de nome, foto opcional e etiqueta opcional antes da criação da família; após a criação, permite adicionar zero ou mais membros e gerar convite explicitamente antes da área principal. RN01, RN07, RN09, RN44 e RN63 revisadas. |
| 1.12 | 2026-10-07 | RN63 passa a definir o limite do apelido: até 20 caracteres não-espaço após trim, sem caracteres de controle; vazio/nulo remove a configuração. Para SPEC-006. |
| 1.11 | 2026-10-07 | RN68 (novo) permite observação opcional de até 250 caracteres por missão, espelhando RN67. Para SPEC-014. |
| 1.10 | 2026-10-07 | Conclusão direta mantém responsáveis existentes ou atribui o adulto quando não houver; reabertura passa a todos os perfis no alcance de consulta e pode reabrir missão concluída, removendo recompensa, participações e badges derivados. |
| 1.9 | 2026-10-06 | RN21–23 restringem conclusão manual de tarefa com responsável Kids ao Administrador e preservam sinalização/foto pendente para auditoria administrativa. Para SPEC-010. |
| 1.8 | 2026-10-06 | RN33 e RN61 distinguem consulta própria diária da consulta familiar adulta por Dia/Semana. Para SPEC-009. |
| 1.7 | 2026-10-06 | RN14 passa a permitir observação opcional na rotina e explicita que não há data final obrigatória; RN17 define que “selecionada e futuras” inclui a ocorrência de origem; RN67 passa a cobrir UC08. Para SPEC-008. |
| 1.6 | 2026-10-06 | RN11 passa a limitar o título da tarefa a 1–60 caracteres Unicode visíveis após trim. RN66 (novo) define a escolha entre retornar a Pendente ou manter Aguardando confirmação ao editar tarefa com sinalização Kids corrente, e a remoção dessa sinalização ao excluir. RN67 (novo) permite observação opcional de até 250 caracteres por tarefa. Para SPEC-007. |
| 1.5 | 2026-10-05 | Pendências consolidadas: fuso, datas livres, edição de concluídas, participações/badges, convites e sessão única; RF67/68; arquitetura, modelo e design 1.1. |
| 1.4 | 2026-10-02 | Família concentra indicadores, lista, inclusão de membros e PDF; detalhe do membro reúne tarefas Dia/Semana, edição e reenvio quando permitidos. RN60–61, RF60–61/RF66 e UC02/11/13/18 revisados. |
| 1.3 | 2026-10-02 | Duas abas Kids, câmera direta, foto/apelido e badges, progresso/carga Dia/Semana, PDF semanal e reconhecimento com WhatsApp; RN61–65, RF61–66, RNF26–27 e UC18–19. Empates e visibilidade do apelido confirmados. |
| 1.2 | 2026-10-01 | Área Família na navegação adulta, progresso coletivo diário e consulta por carrossel: RN60, RF60 e UC11. Design em elaboração na versão 1.0. |
| 1.1 | 2026-10-01 | Recuperação do mesmo perfil por novo convite e renovação sem expiração temporal, com revogação preservada: RN47, RF41, RF46, RF54, RNF22, UC02 e UC09. |
| 1.0 | 2026-10-01 | Primeira versão consolidada, incluindo todas as decisões registradas até esta publicação e links para a visão e a apresentação do projeto. |
