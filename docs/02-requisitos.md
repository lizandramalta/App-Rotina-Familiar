# Requisitos funcionais e não funcionais

**Projeto:** App de Organização Familiar — MVP  
**Versão:** 1.25\
**Data:** 2026-10-28\
**Situação:** base documental consolidada

[Projeto](../README.md) · [Visão do produto](00-visao-do-produto.md) · [Índice e versões](DOCUMENTACAO.md) · [Regras de negócio](01-regras-de-negocio.md) · [Requisitos](02-requisitos.md) · [Casos de uso](03-casos-de-uso.md) · [Diagramas UML](04-diagramas-de-caso-de-uso.md) · [Screen map](design/screen-map.md) · [Diagrama de classes](06-diagrama-de-classes.md)

RF descreve o comportamento que o sistema deve oferecer. RNF define condições de qualidade, segurança e integridade. As regras de negócio ficam no documento próprio; não é necessário consultar versões anteriores para interpretar esta base.

**Conteúdo:** 70 requisitos funcionais e 27 requisitos não funcionais.

## Índice

- [Requisitos funcionais](#requisitos-funcionais)
- [Requisitos não funcionais](#requisitos-nao-funcionais)

## Requisitos funcionais

### RF01

O sistema deve criar a família e atribuir ao criador o perfil Administrador e a identificação de Criador. Antes da criação, o futuro Criador informa nome administrativo obrigatório, com a mesma validação de nome de RF02, pode configurar foto e etiqueta/apelido opcionais conforme RF48 e pode preparar zero ou mais membros com nome e papel. O nome da família é obrigatório e, após remover espaços nas extremidades, deve ter de 1 a 60 caracteres Unicode visíveis, sem caracteres de controle. A criação deve persistir família, Criador e membros iniciais em uma única operação; se qualquer parte falhar, nenhum deles deve ficar parcialmente criado. Deve manter o vínculo único por usuário e redirecionar o Criador para a família existente quando já houver associação. Voltar da etapa de convites aos dados da família já criada não deve executar nova criação: sem mudanças, não há nova gravação; com mudanças, salvar somente alterações autorizadas da família existente.

**Regras de negócio:** [RN01](01-regras-de-negocio.md#rn01), [RN09](01-regras-de-negocio.md#rn09), [RN63](01-regras-de-negocio.md#rn63)\
**Casos de uso:** [UC01](03-casos-de-uso.md#uc01)

### RF02

O sistema deve permitir somente a Administradores adicionar membros à família, criando os perfis que serão utilizados para o ingresso por convite. Antes da criação, o futuro Criador pode preparar zero ou mais membros no formulário da família; esses dados permanecem em rascunho e os perfis são criados atomicamente com a família, sem convite automático. Depois da criação, novas inclusões e alterações seguem as permissões administrativas normais. O nome administrativo é obrigatório e, após remover espaços nas extremidades, deve ter de 1 a 60 caracteres Unicode visíveis, sem caracteres de controle.

**Regras de negócio:** [RN01](01-regras-de-negocio.md#rn01), [RN07](01-regras-de-negocio.md#rn07)\
**Casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02)

### RF03

O sistema deve permitir somente a Administradores alterar papel e Modo Kids de outros membros, respeitando as condições de promoção e rebaixamento. Apenas o nome administrativo de perfis Kids pode ser corrigido pelo Administrador, em Configurações da família ou no detalhe Kids, com a validação de RF02. Adultos alteram o próprio nome por RF48. No retorno da etapa de convites ao formulário da família já criada, alterações em membros persistidos seguem essas mesmas restrições; sem alteração, não há nova gravação.

**Regras de negócio:** [RN02](01-regras-de-negocio.md#rn02), [RN03](01-regras-de-negocio.md#rn03), [RN07](01-regras-de-negocio.md#rn07), [RN08](01-regras-de-negocio.md#rn08)  
**Casos de uso:** [UC02](03-casos-de-uso.md#uc02)

### RF04

O sistema deve permitir somente a Administradores remover membros, exceto o Criador. Revogar o acesso e retirar somente o removido dos responsáveis de tarefas futuras não concluídas/não protegidas, preservando os demais. Não alterar automaticamente pendências antigas nem tarefas concluídas/protegidas; preservar histórico, conforme RN10.

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

O sistema deve permitir a adultos criar tarefas com título, peso e data prevista, responsáveis opcionais, observação opcional e repetição opcional. A data começa hoje no fuso da família; DatePicker permite qualquer data passada ou futura, inclusive antes da criação da família e fora do mês atual. O título é obrigatório e deve ter de 1 a 60 caracteres Unicode visíveis após trim, sem caracteres de controle.

**Regras de negócio:** [RN11](01-regras-de-negocio.md#rn11), [RN19](01-regras-de-negocio.md#rn19), [RN20](01-regras-de-negocio.md#rn20), [RN67](01-regras-de-negocio.md#rn67)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07)

### RF08

O sistema deve permitir a adultos editar tarefa individual ou rotina no alcance autorizado. Concluída sem proteção de missão concluída admite título, peso, data prevista e responsáveis, com atualização do crédito/progresso e auditoria conforme RN17. Edição futura de rotina preserva passado e ocorrências concluídas/protegidas. A última gravação válida no servidor prevalece sem controle de versão otimista.

**Regras de negócio:** [RN17](01-regras-de-negocio.md#rn17), [RN19](01-regras-de-negocio.md#rn19), [RN20](01-regras-de-negocio.md#rn20), [RN58](01-regras-de-negocio.md#rn58)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07)

### RF09

O sistema deve permitir excluir tarefas não concluídas e, em rotinas, selecionar somente a tarefa ou ela e as futuras, preservando ocorrências concluídas. Deve impedir exclusão direta de tarefa concluída e informar a possibilidade ou o impedimento de reabertura pelo [UC17](03-casos-de-uso.md#uc17). Deve respeitar os vínculos e as proteções das missões.

**Regras de negócio:** [RN18](01-regras-de-negocio.md#rn18), [RN19](01-regras-de-negocio.md#rn19), [RN20](01-regras-de-negocio.md#rn20), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07)

### RF10

O sistema permite a adultos atribuir, reatribuir ou remover responsáveis. Em concluída não protegida, atualizar créditos vigentes conforme RN17, preservando auditoria; sem responsáveis, não há crédito individual. Bloquear alterações em conquistas preservadas.

**Regras de negócio:** [RN11](01-regras-de-negocio.md#rn11), [RN12](01-regras-de-negocio.md#rn12), [RN20](01-regras-de-negocio.md#rn20), [RN58](01-regras-de-negocio.md#rn58)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07)

### RF11

O sistema deve permitir consultar tarefas pelo carrossel, da criação da família até o último dia do mês corrente, respeitando o perfil, e bloquear datas fora desse intervalo. A lista pessoal do adulto inclui apenas tarefas em que ele é responsável ou corresponsável. Se uma tarefa compartilhada com Kids estiver Aguardando confirmação, essa lista a apresenta como Pendente, sem alterar o estado efetivo, o progresso ou as permissões de ação.

**Regras de negócio:** [RN23](01-regras-de-negocio.md#rn23), [RN27](01-regras-de-negocio.md#rn27), [RN49](01-regras-de-negocio.md#rn49), [RN55](01-regras-de-negocio.md#rn55)\
**Casos de uso:** [UC11](03-casos-de-uso.md#uc11)

### RF12

O sistema deve permitir a Administradores e Membros concluir tarefas Pendentes ou Aguardando confirmação sem responsável Kids, mesmo atribuídas a outras pessoas. Tarefas com ao menos um responsável Kids só podem ser concluídas manualmente por Administrador. A conclusão deve ocorrer diretamente, sem alerta: mantém os responsáveis existentes ou atribui o adulto que conclui quando não houver responsável. A conclusão deve valer para todos os responsáveis finais da tarefa individual.

**Regras de negócio:** [RN21](01-regras-de-negocio.md#rn21), [RN22](01-regras-de-negocio.md#rn22), [RN48](01-regras-de-negocio.md#rn48), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56)  
**Casos de uso:** [UC12](03-casos-de-uso.md#uc12)

### RF13

O sistema deve configurar início por DatePicker sem limites de produto, frequência da rotina e observação opcional de até 250 caracteres, sem exigir data final. Deve gerar ocorrências independentes sem duplicação. Materializar até o fim do mês seguinte, repor diariamente e completar em consulta se necessário; início além do horizonte permanece programado. Concluir uma ocorrência não altera outras. A alteração “selecionada e futuras” inclui a ocorrência de origem, preservando passado e ocorrências concluídas ou protegidas; altera somente título, peso, responsáveis e observação, sem mudar data inicial, frequência ou a data prevista já gravada em cada ocorrência, mesmo após edição individual, e substitui edições individuais anteriores dos campos permitidos nas futuras abrangidas.

**Regras de negócio:** [RN11](01-regras-de-negocio.md#rn11), [RN14](01-regras-de-negocio.md#rn14), [RN16](01-regras-de-negocio.md#rn16), [RN17](01-regras-de-negocio.md#rn17), [RN67](01-regras-de-negocio.md#rn67)
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

O sistema deve calcular a carga por dia ou semana (segunda a domingo), somando, para cada membro, os pesos integrais das tarefas com conclusão válida no período em que ele figure como responsável da conclusão. Crédito válido de membro removido deve permanecer no período histórico, identificado como “Membro removido”. Deve ajustar o dia e a semana originais quando uma conclusão for desfeita por reabertura autorizada.

**Regras de negócio:** [RN28](01-regras-de-negocio.md#rn28), [RN30](01-regras-de-negocio.md#rn30), [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57), [RN61](01-regras-de-negocio.md#rn61)  
**Casos de uso:** [UC13](03-casos-de-uso.md#uc13)

### RF19

O sistema deve excluir da carga tarefas Pendentes ou Aguardando confirmação e contabilizá-las somente após conclusão válida. Uma reabertura autorizada deve desfazer o crédito anterior para todos os responsáveis.

**Regras de negócio:** [RN26](01-regras-de-negocio.md#rn26), [RN30](01-regras-de-negocio.md#rn30), [RN57](01-regras-de-negocio.md#rn57)  
**Casos de uso:** [UC13](03-casos-de-uso.md#uc13)

### RF20

O sistema deve apresentar a Administradores e Membros a carga de todos e a participação de cada um na soma das cargas individuais, incluindo linha histórica “Membro removido” quando aplicável, sem ranking e sem divisão por zero.

**Regras de negócio:** [RN30](01-regras-de-negocio.md#rn30), [RN31](01-regras-de-negocio.md#rn31), [RN33](01-regras-de-negocio.md#rn33), [RN34](01-regras-de-negocio.md#rn34)  
**Casos de uso:** [UC13](03-casos-de-uso.md#uc13)

### RF21

O sistema deve apresentar a distribuição da carga de forma que Administradores e Membros possam perceber sua concentração e o equilíbrio entre os membros. Essa apresentação não deve estabelecer competição nem classificar quem fez mais.

**Regras de negócio:** [RN31](01-regras-de-negocio.md#rn31), [RN34](01-regras-de-negocio.md#rn34)  
**Casos de uso:** [UC13](03-casos-de-uso.md#uc13)

### RF22

O sistema deve permitir a Kids consultar suas próprias tarefas por dia, da criação da família até o último dia do mês corrente, bloqueando datas fora desse intervalo. A tarefa sinalizada por Kids deve aparecer como Aguardando confirmação nessa consulta até uma decisão válida, inclusive quando houver adulto corresponsável.

**Regras de negócio:** [RN23](01-regras-de-negocio.md#rn23), [RN27](01-regras-de-negocio.md#rn27), [RN49](01-regras-de-negocio.md#rn49), [RN55](01-regras-de-negocio.md#rn55)\
**Casos de uso:** [UC11](03-casos-de-uso.md#uc11)

### RF23

O sistema deve permitir a Kids sinalizar a realização de tarefa sob sua responsabilidade, com foto opcional, sem produzir conclusão parcial ou imediata.

**Regras de negócio:** [RN21](01-regras-de-negocio.md#rn21), [RN23](01-regras-de-negocio.md#rn23), [RN54](01-regras-de-negocio.md#rn54), [RN55](01-regras-de-negocio.md#rn55)  
**Casos de uso:** [UC15](03-casos-de-uso.md#uc15)

### RF24

O sistema deve alterar de Pendente para Aguardando confirmação a tarefa sinalizada por Kids. Esse estado deve permanecer até confirmação, recusa ou conclusão manual válida por Administrador; a apresentação da lista pessoal do adulto corresponsável segue RF11 sem converter o estado efetivo em Pendente.

**Regras de negócio:** [RN22](01-regras-de-negocio.md#rn22), [RN23](01-regras-de-negocio.md#rn23), [RN24](01-regras-de-negocio.md#rn24)  
**Casos de uso:** [UC15](03-casos-de-uso.md#uc15)

### RF25

O sistema deve permitir a Administradores visualizar a sinalização e a foto opcional, confirmar ou recusar, registrar quem confirmou e impedir decisões duplicadas sobre o mesmo estado. Confirmação conclui para todos; recusa retorna a Pendente; conclusão manual encerra a pendência de validação.

**Regras de negócio:** [RN24](01-regras-de-negocio.md#rn24), [RN25](01-regras-de-negocio.md#rn25), [RN54](01-regras-de-negocio.md#rn54), [RN55](01-regras-de-negocio.md#rn55)  
**Casos de uso:** [UC03](03-casos-de-uso.md#uc03)

### RF26

O sistema deve considerar a tarefa de Kids concluída após confirmação ou conclusão manual por Administrador. Antes disso, não deve gerar carga nem progresso concluído. A conclusão manual encerra a pendência e preserva sinalização/foto opcional para auditoria de Administradores.

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

Ao concluir uma missão, o sistema deve registrar uma participação por responsável creditado em pelo menos uma tarefa vinculada e conceder badges cumulativos nos marcos 5/10/25/50, conforme RN64. Não oferecer selo opcional por missão e não conceder a todos os membros indistintamente.

**Regras de negócio:** [RN36](01-regras-de-negocio.md#rn36), [RN38](01-regras-de-negocio.md#rn38), [RN64](01-regras-de-negocio.md#rn64)  
**Casos de uso:** [UC05](03-casos-de-uso.md#uc05)

### RF33

O sistema deve disponibilizar recompensas de caráter coletivo, vinculadas às conquistas da família e destinadas a beneficiar seus membros em conjunto.

**Regras de negócio:** [RN41](01-regras-de-negocio.md#rn41)  
**Casos de uso:** [UC06](03-casos-de-uso.md#uc06)

### RF34

O sistema deve oferecer para a roleta os seis itens predefinidos definidos em RN42 e permitir somente a Administradores adicionar itens personalizados que passarão a participar dos sorteios. O título personalizado é obrigatório, sem caracteres de controle e limitado a 60 caracteres não-espaço após `trim`; a descrição é opcional e limitada a 255 caracteres, contando espaços. Títulos personalizados devem ser únicos na família após `trim`, sem distinção entre maiúsculas e minúsculas. Adicionar um item não deve atribuí-lo automaticamente a uma missão.

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

Após autenticação Apple, o sistema deve encaminhar a pessoa sem vínculo ao onboarding: configurar o rascunho do próprio perfil, preparar zero ou mais membros no formulário da família e então criar a família junto com todos esses perfis. A criação atribui ao Criador o papel de Administrador e sua identificação de Criador. Havendo membros, o sistema oferece convites explícitos após a criação; sem membros, abre diretamente a área principal. O Criador pode adiar os convites. Voltar da etapa de convites reabre os dados já persistidos para edição autorizada, sem repetir a criação. Havendo vínculo na autenticação, deve redirecioná-lo à família existente.

**Regras de negócio:** [RN01](01-regras-de-negocio.md#rn01), [RN07](01-regras-de-negocio.md#rn07), [RN09](01-regras-de-negocio.md#rn09), [RN44](01-regras-de-negocio.md#rn44), [RN63](01-regras-de-negocio.md#rn63)\
**Casos de uso:** [UC01](03-casos-de-uso.md#uc01)

### RF39

O sistema deve vincular a família ao identificador Apple do Criador obtido no fluxo de autenticação, permitindo reconhecer a associação entre esse usuário e sua família.

**Regras de negócio:** [RN44](01-regras-de-negocio.md#rn44)  
**Casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC04](03-casos-de-uso.md#uc04)

### RF40

O sistema deve permitir criar os perfis dos demais membros antes do ingresso no aplicativo, nos papéis Administrador, Membro ou Kids: na criação inicial da família, a partir do rascunho informado pelo futuro Criador e persistido na mesma operação; depois, somente por Administradores da família já criada. Cada perfil criado pode ser usado na geração explícita do convite correspondente.

**Regras de negócio:** [RN01](01-regras-de-negocio.md#rn01), [RN07](01-regras-de-negocio.md#rn07), [RN45](01-regras-de-negocio.md#rn45)\
**Casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02)

### RF41

O Administrador pode gerar ou reenviar convite para perfil ativo existente, inclusive para membro criado com a família no onboarding. Cada emissão gera novo link e senha, invalida convites anteriores e revoga a sessão anterior atomicamente. A emissão é sempre uma ação explícita, não automática. A primeira emissão gera as credenciais e abre diretamente o compartilhamento, sem confirmação intermediária; a reemissão deve mostrar seus efeitos e exigir confirmação antes de gerar novas credenciais. Em todos os casos, perfil, histórico e vínculos são preservados, e link e senha são disponibilizados para envio conjunto.

**Regras de negócio:** [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46), [RN47](01-regras-de-negocio.md#rn47)  
**Casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02)

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

O sistema deve manter uma sessão ativa por perfil/aparelho, renovável por refresh token sem expiração temporal e revogável. Token de acesso dura 15 minutos e operações verificam a sessão ativa. Novo convite revoga a sessão anterior; recuperação preserva o mesmo perfil. Resposta perdida no ingresso admite recuperação comprovada da mesma tentativa por dez minutos, sem novo consumo; depois, novo convite.

**Regras de negócio:** [RN46](01-regras-de-negocio.md#rn46), [RN47](01-regras-de-negocio.md#rn47)  
**Casos de uso:** [UC09](03-casos-de-uso.md#uc09)

### RF47

Ao concluir tarefa sem responsável, o sistema deve atribuí-la ao adulto que conclui. Ao optar por assumir uma tarefa atribuída a outros, deve substituir todos os responsáveis por esse usuário. Deve limitar a mudança à tarefa individual.

**Regras de negócio:** [RN48](01-regras-de-negocio.md#rn48), [RN56](01-regras-de-negocio.md#rn56)  
**Casos de uso:** [UC12](03-casos-de-uso.md#uc12)

### RF48

O sistema deve permitir a Administradores, Membros e Kids editar os dados permitidos do próprio perfil, adicionar, substituir ou remover foto opcional por câmera ou galeria e configurar etiqueta/apelido. Para o futuro Criador, esses dados são oferecidos no rascunho inicial antes da criação da família. A foto escolhida deve ser enviada nessa etapa, sem criar perfil ou conceder acesso familiar; somente mídia protegida do próprio futuro Criador pode ser vinculada após a criação confirmada. Falha do envio deve permitir nova tentativa ou continuação sem foto, sem bloquear a criação; foto e etiqueta podem ser omitidas. O apelido é opcional, com até 20 caracteres não-espaço após remover espaços nas extremidades, sem caracteres de controle; vazio ou nulo remove a configuração vigente. Administradores e Membros também podem editar o próprio nome de identificação por esse fluxo, com a validação do nome administrativo (RF02: de 1 a 60 caracteres visíveis após remover espaços nas extremidades, sem caracteres de controle); Kids não alteram o nome. Deve impedir acesso de terceiros à configuração de apelido, inclusive por operação administrativa. A edição não altera papel, família nem modo Kids. A consulta do próprio perfil retorna também o nome da família, para compor a identificação exibida.

**Regras de negócio:** [RN01](01-regras-de-negocio.md#rn01), [RN63](01-regras-de-negocio.md#rn63).\
**Casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC10](03-casos-de-uso.md#uc10)

### RF49

O sistema deve apresentar a todos os perfis o progresso pessoal diário conforme RN61, contando tarefas próprias concluídas sobre o total próprio previsto no dia, sem contar sinalizações aguardando confirmação. Kids não consultam a carga familiar.

**Regras de negócio:** [RN26](01-regras-de-negocio.md#rn26), [RN33](01-regras-de-negocio.md#rn33), [RN61](01-regras-de-negocio.md#rn61)  
**Casos de uso:** [UC11](03-casos-de-uso.md#uc11)

### RF50

O sistema deve permitir selecionar cada tarefa individual da missão separadamente, exigir ao menos uma tarefa vinculada e impedir remoção ou exclusão da última sem substituição. Deve bloquear mudanças de vínculo em missões concluídas.

**Regras de negócio:** [RN16](01-regras-de-negocio.md#rn16), [RN35](01-regras-de-negocio.md#rn35), [RN36](01-regras-de-negocio.md#rn36), [RN50](01-regras-de-negocio.md#rn50), [RN51](01-regras-de-negocio.md#rn51), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Casos de uso:** [UC05](03-casos-de-uso.md#uc05)

### RF51

O sistema deve permitir somente a Administradores abrir a roleta de missão concluída sem resgate, obter catálogo elegível e sortear/animar no aplicativo. Servidor valida e registra apenas a recompensa aceita, respeitando resgate único.

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

A emissão, inclusive reenvio, deve gerar novo link e senha sem expiração temporal, revogar convites e sessão anteriores e exigir a nova senha no ingresso único. Exibir credenciais somente para compartilhamento explícito, sem recuperação de senha a partir de hash. A senha não é login permanente.

**Regras de negócio:** [RN45](01-regras-de-negocio.md#rn45), [RN46](01-regras-de-negocio.md#rn46), [RN47](01-regras-de-negocio.md#rn47)  
**Casos de uso:** [UC02](03-casos-de-uso.md#uc02), [UC09](03-casos-de-uso.md#uc09)

### RF55

Ao escolher adicionar foto à sinalização, o sistema deve abrir diretamente a câmera, solicitar permissão quando necessária e permitir revisar, refazer ou descartar a captura antes do envio. Deve permitir ao Administrador visualizar a foto na validação. Negativa de permissão, câmera indisponível, cancelamento ou falha de envio não impedem seguir sem foto; informar a falha e oferecer nova tentativa quando possível.

**Regras de negócio:** [RN54](01-regras-de-negocio.md#rn54)  
**Casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC15](03-casos-de-uso.md#uc15)

### RF56

O sistema deve aplicar um único estado a todos os responsáveis, creditar o peso integral a cada responsável final e contar a tarefa uma única vez por missão. Deve distinguir quem executou a ação de quem recebeu o crédito.

**Regras de negócio:** [RN30](01-regras-de-negocio.md#rn30), [RN35](01-regras-de-negocio.md#rn35), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56)  
**Casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC15](03-casos-de-uso.md#uc15)

### RF57

O sistema deve permitir a Administradores e Membros retornar para Pendente uma tarefa acessível da família e a Kids retornar uma tarefa própria. Deve solicitar confirmação quando a tarefa estiver vinculada a missão concluída e/ou com recompensa aceita, manter os responsáveis e desfazer o crédito anterior na carga e no progresso das missões vinculadas. A confirmação deve retornar missões concluídas para Em andamento e remover recompensa, participações e badges derivados.

**Regras de negócio:** [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58)  
**Casos de uso:** [UC13](03-casos-de-uso.md#uc13), [UC17](03-casos-de-uso.md#uc17)

### RF58

O sistema deve impedir edição, exclusão ou mudança de vínculos da missão concluída. A reabertura confirmada de tarefa vinculada é a única operação que pode retornar a missão para Em andamento, removendo recompensa, participações e badges derivados sem preservar histórico. Deve permitir o registro da recompensa somente pelo resgate único enquanto a missão estiver concluída.

**Regras de negócio:** [RN38](01-regras-de-negocio.md#rn38), [RN53](01-regras-de-negocio.md#rn53), [RN58](01-regras-de-negocio.md#rn58)  
**Casos de uso:** [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC14](03-casos-de-uso.md#uc14), [UC17](03-casos-de-uso.md#uc17)

### RF59

Ao excluir uma tarefa não concluída, o sistema deve remover seus vínculos de missões em andamento e recalcular o progresso. Deve impedir a operação quando afetar missão concluída ou deixar missão sem tarefas. A exclusão após reabertura não deve retirar carga novamente. Se, após remover o vínculo, restarem apenas tarefas concluídas, o sistema deve concluir a missão na mesma transação, conforme RN38.

**Regras de negócio:** [RN50](01-regras-de-negocio.md#rn50), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59)  
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07), [UC17](03-casos-de-uso.md#uc17)

### RF60

O sistema deve oferecer a Administradores e Membros a área Família (Minha família) na navegação principal, apresentando progresso total no intervalo selecionado e uma lista de membros. A seleção inicial é a semana corrente; Início/Fim permite qualquer intervalo válido dentro de RN49. Cada item abre o detalhe inicialmente no dia atual, com abas Dia e Semana (domingo a sábado no fuso da família, dentro de RN49); voltar restaura o intervalo e os filtros da origem. Outros intervalos são consultados por Tarefas da família. Tarefas da família mantém o intervalo e apresenta todas as tarefas, inclusive sem responsável. A carga de UC13 terá apresentação própria em entrega posterior, fora da TEL-050 atual.

O progresso deve mostrar concluídas/total e percentual, contar cada tarefa uma vez e apresentar “Sem tarefas” quando o total for zero. Carga e progresso seguem RN60–61 e são atualizados após alterações válidas.

Na Família, o sistema deve destacar membros que concluíram todas as tarefas atribuídas no dia atual e, quando há ao menos dois membros ativos e tarefas atribuídas no intervalo selecionado, todos os empatados na maior quantidade. Apenas Administradores podem acionar Parabenizar para outro membro ativo, inclusive Kids; repetições são permitidas. Cada ação confirmada deve registrar mensagem para o destinatário e intenção de push sem depender da entrega externa. Minhas tarefas deve apresentar a mensagem recebida e permitir fechá-la, ocultando-a da interface.

Gerar relatório semanal PDF fica no menu de Tarefas da família para ambos os perfis adultos. Adicionar membro fica em Configurações da família, somente para Administradores. Alterar papel, remover membro e gerar/reenviar convite ficam no detalhe do membro, somente para Administradores quando permitido; a correção do nome de Kids fica em Configurações da família e no topo do detalhe Kids para Administrador autorizado. Adultos editam o próprio nome em Meu perfil, respeitando o acesso Apple do Criador e a edição exclusiva do próprio apelido. Confirmações Kids permanecem exclusivas dos Administradores. Kids não acessam a área Família.

**Regras de negócio:** [RN60](01-regras-de-negocio.md#rn60), [RN61](01-regras-de-negocio.md#rn61)  
**Casos de uso:** [UC11](03-casos-de-uso.md#uc11)

### RF61

O sistema deve oferecer Gerar relatório PDF no menu de Tarefas da família e permitir selecionar uma semana, gerar, visualizar e salvar ou compartilhar o PDF de RN62, com gráficos de carga e progresso familiar e tabela com peso creditado e tarefas realizadas por membro. Se o intervalo consultado tocar mais de uma semana, deve pedir a escolha antes de gerar; com uma única semana, usa-a diretamente. Deve mostrar geração em andamento, falha com nova tentativa e semana atual parcial. O filtro livre da consulta não transforma o PDF em relatório de intervalo arbitrário.

**Regras de negócio:** [RN62](01-regras-de-negocio.md#rn62)  
**Casos de uso:** [UC18](03-casos-de-uso.md#uc18)

### RF62

O sistema deve exibir badges cumulativos bronze/prata/ouro/diamante e total de missões com participação no perfil, inclusive Kids. Selecionar um marco abre suas missões contribuintes e permite abrir o detalhe de cada missão. Sem participação ou badges, mostrar estado apropriado. Não há concessão retroativa a novos membros.

**Regras de negócio:** [RN64](01-regras-de-negocio.md#rn64)  
**Casos de uso:** [UC10](03-casos-de-uso.md#uc10), [UC14](03-casos-de-uso.md#uc14)

### RF63

O servidor deve apurar a semana encerrada às 00:00 de segunda-feira no fuso da família, conforme seus ciclos, sem depender do app. Todos os perfis ativos, inclusive Kids, são elegíveis; empate reconhece todos e ausência de pontos positivos não tem vencedor. Processamento é recuperável e não duplica resultado/intenção de notificação. Resultado final não é revisado por edições ou reaberturas tardias.

**Regras de negócio:** [RN28](01-regras-de-negocio.md#rn28), [RN30](01-regras-de-negocio.md#rn30), [RN65](01-regras-de-negocio.md#rn65)  
**Casos de uso:** [UC19](03-casos-de-uso.md#uc19)

### RF64

O sistema deve oferecer ao reconhecido compartilhar o destaque pelo WhatsApp com mensagem editável de celebração e sugestão de atividade em família. Deve abrir o compartilhamento somente após ação explícita, permitir cancelamento e oferecer copiar mensagem se WhatsApp estiver indisponível. Abrir o WhatsApp não confirma envio.

**Regras de negócio:** [RN65](01-regras-de-negocio.md#rn65)  
**Casos de uso:** [UC19](03-casos-de-uso.md#uc19)

### RF65

O sistema deve oferecer ao perfil Kids exatamente duas abas independentes: “Minhas tarefas” e “Missões e conquistas”. Minhas tarefas é a inicial. Missões não depende de entrar por Minhas tarefas. O avatar/cabeçalho das abas permite abrir o próprio perfil, mantendo apenas duas abas.

**Regras de negócio:** [RN33](01-regras-de-negocio.md#rn33), [RN63](01-regras-de-negocio.md#rn63)  
**Casos de uso:** [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC14](03-casos-de-uso.md#uc14)

### RF66

O sistema deve oferecer filtro Início/Fim livre nos indicadores de progresso familiar em Minha família e em Tarefas da família, inclusive ao filtrar por membro nessa lista. Minhas tarefas é diária para todos os perfis. O detalhe do membro inicia no dia atual, permite alternar para a semana visual de domingo a sábado no fuso da família, respeita RN49 e, ao voltar, preserva o intervalo da Família. A semana visual não altera a semana familiar de segunda a domingo de RN28. Deve informar as datas e aplicar as fórmulas e limites de RN61. O intervalo familiar não altera o período livre de prazo das missões.

**Regras de negócio:** [RN28](01-regras-de-negocio.md#rn28), [RN33](01-regras-de-negocio.md#rn33), [RN60](01-regras-de-negocio.md#rn60), [RN61](01-regras-de-negocio.md#rn61)  
**Casos de uso:** [UC11](03-casos-de-uso.md#uc11), [UC13](03-casos-de-uso.md#uc13)

### RF67

O sistema deve oferecer seleção do fuso na criação da família, com padrão `America/Sao_Paulo`, e Configurações da família para Administradores. Ao voltar da etapa de convites ao formulário da família já criada, mudar o fuso deve seguir o fluxo de Configurações da família, não a criação inicial nem a gravação simples das demais alterações. Ao alterar, informar efeitos e escolher aplicação imediata ou no próximo ciclo; cancelar não salva. Mostrar fuso vigente e alteração programada. Consultas, relatório e apuração compartilham os limites de RN28.

**Regras de negócio:** [RN28](01-regras-de-negocio.md#rn28), [RN65](01-regras-de-negocio.md#rn65).\
**Casos de uso:** [UC01](03-casos-de-uso.md#uc01).

### RF68

Ao abrir convite com sessão ativa, o sistema deve solicitar confirmação da troca de acesso; cancelar mantém a sessão. Só substituir o acesso após validar o novo ingresso, limpando os dados locais anteriores. Não migrar histórico nem remover o perfil da família anterior. Sem app instalado, direcionar à loja e orientar reabrir o link após instalar.

**Regras de negócio:** [RN09](01-regras-de-negocio.md#rn09), [RN46](01-regras-de-negocio.md#rn46), [RN47](01-regras-de-negocio.md#rn47).\
**Casos de uso:** [UC09](03-casos-de-uso.md#uc09).

### RF69

Ao editar uma tarefa em Aguardando confirmação, o sistema deve exigir a escolha entre retornar a Pendente, descartando a sinalização corrente, ou manter Aguardando confirmação com os dados atualizados e a sinalização corrente intacta. A exclusão de uma tarefa em Aguardando confirmação deve remover sua sinalização corrente sem registrar confirmação ou recusa.

**Regras de negócio:** [RN66](01-regras-de-negocio.md#rn66).\
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07), [UC03](03-casos-de-uso.md#uc03).

### RF70

O sistema deve permitir informar e editar uma observação opcional de até 250 caracteres, contando espaços, na tarefa única ou na configuração de rotina, sujeita às mesmas regras de edição e proteção dos demais campos.

**Regras de negócio:** [RN67](01-regras-de-negocio.md#rn67).\
**Casos de uso:** [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08).

### RF71

O sistema deve permitir informar e editar uma observação opcional de até 250 caracteres, contando espaços, na missão, sujeita às mesmas regras de edição e proteção dos demais dados da missão.

**Regras de negócio:** [RN68](01-regras-de-negocio.md#rn68).\
**Casos de uso:** [UC05](03-casos-de-uso.md#uc05).

<a id="requisitos-nao-funcionais"></a>

## Requisitos não funcionais

Os requisitos transversais aplicam-se conforme a operação: por exemplo, persistência quando há gravação e proteção de sessão quando há acesso autenticado. RNF14 é uma restrição arquitetural para a implementação de todos os fluxos.

### RNF01

**Categoria:** Usabilidade

A interface deve apresentar as ações e informações necessárias às atividades de organização familiar com linguagem simples e navegação compreensível, evitando complexidade desnecessária para executar as tarefas previstas.

**Regras relacionadas:** [RN60](01-regras-de-negocio.md#rn60)\
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17), [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19)

### RNF02

**Categoria:** Usabilidade

A interface deve apresentar de forma clara o título, o peso, o responsável quando houver e o status da tarefa, além de sua origem em uma rotina quando aplicável, permitindo compreender o que deve ser realizado e acompanhar sua situação.

**Regras relacionadas:** [RN11](01-regras-de-negocio.md#rn11), [RN13](01-regras-de-negocio.md#rn13), [RN22](01-regras-de-negocio.md#rn22), [RN55](01-regras-de-negocio.md#rn55)  
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC15](03-casos-de-uso.md#uc15), [UC17](03-casos-de-uso.md#uc17)

### RNF03

**Categoria:** Usabilidade

A apresentação da carga deve facilitar a compreensão da distribuição e da participação dos membros, utilizando linguagem e recursos visuais voltados ao equilíbrio familiar, sem ranking completo. O reconhecimento semanal tem mensagem de convivência familiar conforme RN65.

**Regras relacionadas:** [RN30](01-regras-de-negocio.md#rn30), [RN31](01-regras-de-negocio.md#rn31), [RN34](01-regras-de-negocio.md#rn34)  
**Aplicação nos casos de uso:** [UC13](03-casos-de-uso.md#uc13)

### RNF04

**Categoria:** Usabilidade

A interface destinada ao perfil Kids deve usar linguagem e elementos visuais adequados a esse perfil, priorizar suas próprias tarefas e seu progresso diário e respeitar as restrições de acesso às demais funcionalidades.

**Regras relacionadas:** [RN19](01-regras-de-negocio.md#rn19), [RN33](01-regras-de-negocio.md#rn33), [RN65](01-regras-de-negocio.md#rn65)\
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC09](03-casos-de-uso.md#uc09), [UC11](03-casos-de-uso.md#uc11), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15)

### RNF05

**Categoria:** Acessibilidade

A interface não deve depender exclusivamente de cores para comunicar status, mensagens ou ações. Deve complementar as cores com texto, ícones identificáveis ou outro indicador que permita compreender a informação.

**Regras relacionadas:** [RN60](01-regras-de-negocio.md#rn60), [RN61](01-regras-de-negocio.md#rn61), [RN62](01-regras-de-negocio.md#rn62)\
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17), [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19)

### RNF06

**Categoria:** Segurança

O sistema deve restringir o acesso aos dados à família associada ao usuário e às permissões de seu perfil, impedindo a consulta ou alteração de informações de outras famílias e de informações não autorizadas.

**Regras relacionadas:** [RN09](01-regras-de-negocio.md#rn09), [RN10](01-regras-de-negocio.md#rn10), [RN33](01-regras-de-negocio.md#rn33), [RN60](01-regras-de-negocio.md#rn60), [RN61](01-regras-de-negocio.md#rn61), [RN62](01-regras-de-negocio.md#rn62), [RN63](01-regras-de-negocio.md#rn63), [RN64](01-regras-de-negocio.md#rn64), [RN65](01-regras-de-negocio.md#rn65)\
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17), [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19)

### RNF07

**Categoria:** Segurança

O sistema deve validar as permissões de perfil em cada operação protegida, sem depender apenas da visibilidade dos controles da interface. Isso inclui gerenciamento de membros, missões e tarefas, reabertura, adição de itens à roleta, sorteio e aceitação de recompensa.

**Regras relacionadas:** [RN02](01-regras-de-negocio.md#rn02), [RN03](01-regras-de-negocio.md#rn03), [RN04](01-regras-de-negocio.md#rn04), [RN05](01-regras-de-negocio.md#rn05), [RN07](01-regras-de-negocio.md#rn07), [RN08](01-regras-de-negocio.md#rn08), [RN19](01-regras-de-negocio.md#rn19), [RN20](01-regras-de-negocio.md#rn20), [RN21](01-regras-de-negocio.md#rn21), [RN24](01-regras-de-negocio.md#rn24), [RN37](01-regras-de-negocio.md#rn37), [RN42](01-regras-de-negocio.md#rn42), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN63](01-regras-de-negocio.md#rn63)\
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17), [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19)

### RNF08

**Categoria:** Segurança

As comunicações que transportem dados de usuários, famílias, tarefas, missões, recompensas ou credenciais de acesso devem utilizar proteção criptográfica em trânsito para evitar sua exposição durante a transmissão.

**Regras relacionadas:** Requisito transversal de qualidade; sem RN específica.  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17), [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19)

### RNF09

**Categoria:** Integridade de dados

O sistema deve manter consistentes os estados, responsáveis, conclusões e vínculos de cada tarefa individual. Deve preservar o histórico das operações, respeitar os alcances de edição, exclusão e reabertura e impedir alterações nos dados preservados de missões concluídas.

**Regras relacionadas:** [RN10](01-regras-de-negocio.md#rn10), [RN16](01-regras-de-negocio.md#rn16), [RN17](01-regras-de-negocio.md#rn17), [RN18](01-regras-de-negocio.md#rn18), [RN48](01-regras-de-negocio.md#rn48), [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59), [RN60](01-regras-de-negocio.md#rn60), [RN61](01-regras-de-negocio.md#rn61), [RN64](01-regras-de-negocio.md#rn64)\
**Aplicação nos casos de uso:** [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC17](03-casos-de-uso.md#uc17)

### RNF10

**Categoria:** Integridade da carga

O cálculo deve refletir as conclusões válidas, creditando o peso integral a cada responsável da conclusão. Deve distinguir o autor da ação dos beneficiários do crédito, excluir tarefas pendentes ou aguardando confirmação e desfazer o crédito anterior exatamente uma vez em reabertura autorizada.

**Regras relacionadas:** [RN26](01-regras-de-negocio.md#rn26), [RN28](01-regras-de-negocio.md#rn28), [RN30](01-regras-de-negocio.md#rn30), [RN31](01-regras-de-negocio.md#rn31), [RN55](01-regras-de-negocio.md#rn55), [RN56](01-regras-de-negocio.md#rn56), [RN57](01-regras-de-negocio.md#rn57), [RN61](01-regras-de-negocio.md#rn61), [RN62](01-regras-de-negocio.md#rn62), [RN65](01-regras-de-negocio.md#rn65)\
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC07](03-casos-de-uso.md#uc07), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC17](03-casos-de-uso.md#uc17), [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19)

### RNF11

**Categoria:** Consistência da conclusão

Confirmação, recusa, conclusão manual e reabertura devem respeitar o estado corrente e ser consistentes sob concorrência. Não podem gerar conclusões, créditos ou decisões duplicadas. A sinalização Kids, com ou sem foto, não deve gerar conclusão parcial.

**Regras relacionadas:** [RN22](01-regras-de-negocio.md#rn22), [RN23](01-regras-de-negocio.md#rn23), [RN24](01-regras-de-negocio.md#rn24), [RN26](01-regras-de-negocio.md#rn26), [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57), [RN64](01-regras-de-negocio.md#rn64)\
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC12](03-casos-de-uso.md#uc12), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC17](03-casos-de-uso.md#uc17)

### RNF12

**Categoria:** Confiabilidade

O sistema não deve apresentar uma alteração como salva quando sua persistência falhar. Deve informar a falha ao usuário, evitando que a perda de dados ocorra sem indicação perceptível. Em resposta perdida, consultar estado antes de oferecer nova tentativa, sem retentativa automática de gravações nem recuperação geral por chave de operação. Em criação, informar quando não for possível determinar se a tentativa foi salva.

**Regras relacionadas:** [RN62](01-regras-de-negocio.md#rn62), [RN63](01-regras-de-negocio.md#rn63), [RN65](01-regras-de-negocio.md#rn65)\
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17), [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19)

### RNF13

**Categoria:** Responsividade

As operações de rede não devem bloquear a interface. Durante o processamento, a interface deve permanecer responsiva e apresentar o estado da operação para que o usuário compreenda seu andamento ou eventual falha.

**Regras relacionadas:** [RN62](01-regras-de-negocio.md#rn62)\
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17), [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19)

### RNF14

**Categoria:** Arquitetura

A organização do sistema deve manter separadas as responsabilidades dos domínios de família, tarefas e rotinas, carga diária ou semanal, missões, recompensas e acesso, permitindo sua manutenção sem misturar regras de negócio de áreas distintas.

**Regras relacionadas:** Requisito transversal de qualidade; sem RN específica.  
**Aplicação nos casos de uso:** [UC01](03-casos-de-uso.md#uc01), [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC04](03-casos-de-uso.md#uc04), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17), [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19)

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

Credenciais são protegidas e a sessão ativa é conferida em toda operação. Cada perfil possui uma sessão ativa vinculada à instalação; refresh token não expira por tempo, permanece estável durante a sessão e é revogável. Access token dura 15 minutos, sem postergar revogação até seu vencimento. Remoção e emissão/reenvio de convite revogam a sessão anterior. Novo acesso Apple substitui a sessão do Criador. Recuperação de ingresso com resposta perdida exige prova da instalação/tentativa original, jamais apenas um identificador público.

**Regras relacionadas:** [RN10](01-regras-de-negocio.md#rn10), [RN47](01-regras-de-negocio.md#rn47)  
**Aplicação nos casos de uso:** [UC02](03-casos-de-uso.md#uc02), [UC03](03-casos-de-uso.md#uc03), [UC05](03-casos-de-uso.md#uc05), [UC06](03-casos-de-uso.md#uc06), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC09](03-casos-de-uso.md#uc09), [UC10](03-casos-de-uso.md#uc10), [UC11](03-casos-de-uso.md#uc11), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC15](03-casos-de-uso.md#uc15), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17), [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19)

### RNF23

**Categoria:** Integridade de dados

A aceitação da recompensa e o encerramento do resgate devem ser persistidos de forma consistente. Ações simultâneas de Administradores não podem registrar mais de uma recompensa nem permitir um segundo resgate da mesma missão.

**Regras relacionadas:** [RN53](01-regras-de-negocio.md#rn53)  
**Aplicação nos casos de uso:** [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16)

### RNF24

**Categoria:** Privacidade das fotos

O armazenamento e a consulta de fotos devem respeitar a associação à família e as permissões do perfil, impedindo acesso público ou por usuários não autorizados. A remoção de um membro também revoga seu acesso às fotos da família.

**Regras relacionadas:** [RN10](01-regras-de-negocio.md#rn10), [RN54](01-regras-de-negocio.md#rn54), [RN63](01-regras-de-negocio.md#rn63)  
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC15](03-casos-de-uso.md#uc15), [UC10](03-casos-de-uso.md#uc10)

### RNF25

**Categoria:** Integridade de reabertura e conquista

Reabertura, atualização da carga, atualização de progresso e verificação de proteção por missão concluída devem ser processadas de forma consistente, inclusive sob concorrência, sem permitir estados parciais ou alteração de conquista preservada.

**Regras relacionadas:** [RN55](01-regras-de-negocio.md#rn55), [RN57](01-regras-de-negocio.md#rn57), [RN58](01-regras-de-negocio.md#rn58), [RN59](01-regras-de-negocio.md#rn59), [RN64](01-regras-de-negocio.md#rn64)\
**Aplicação nos casos de uso:** [UC03](03-casos-de-uso.md#uc03), [UC05](03-casos-de-uso.md#uc05), [UC07](03-casos-de-uso.md#uc07), [UC08](03-casos-de-uso.md#uc08), [UC12](03-casos-de-uso.md#uc12), [UC13](03-casos-de-uso.md#uc13), [UC14](03-casos-de-uso.md#uc14), [UC16](03-casos-de-uso.md#uc16), [UC17](03-casos-de-uso.md#uc17)


### RNF26

**Categoria:** Integridade de relatórios e reconhecimento

O backend fornece um snapshot consistente para o PDF gerado no aplicativo. Gráficos e tabelas usam esse snapshot. Apuração é recuperável, única por família/ciclo, finalizada antes da publicação e imutável após encerramento; alterações posteriores não reapuram o destaque. Uma fila persistente registra uma intenção de notificar por reconhecido; distinguir tentativa, aceitação pelo APNs e abertura, sem prometer entrega/leitura. Transições de fuso não podem duplicar ou deixar lacunas entre períodos de apuração.

**Regras relacionadas:** [RN62](01-regras-de-negocio.md#rn62), [RN65](01-regras-de-negocio.md#rn65).  
**Aplicação nos casos de uso:** [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19).

### RNF27

**Categoria:** Privacidade do perfil e exportação

A configuração de apelido deve ser protegida por titularidade no backend, inclusive contra Administradores. Fotos de perfil seguem as permissões da família. PDF exige permissão adulta e compartilhamento externo depende de ação explícita. Mensagens do destaque não devem incluir fotos de validação ou dados de outros membros sem necessidade.

**Regras relacionadas:** [RN62](01-regras-de-negocio.md#rn62), [RN63](01-regras-de-negocio.md#rn63), [RN65](01-regras-de-negocio.md#rn65).  
**Aplicação nos casos de uso:** [UC10](03-casos-de-uso.md#uc10), [UC18](03-casos-de-uso.md#uc18), [UC19](03-casos-de-uso.md#uc19).

## Histórico de versões

| Versão | Data | Alteração |
|---|---|---|
| 1.25 | 2026-10-28 | RF03/RF60/RF66: detalhe do membro com Dia/Semana domingo–sábado; nome Kids editável também no detalhe; Parabenizar permanece na Família. |
| 1.24 | 2026-10-28 | RF03/RF60: nome administrativo de adultos é editado pelo titular; somente o nome de Kids pode ser corrigido por Administrador em Configurações. TEL-032 mantém papel, convite e remoção. |
| 1.23 | 2026-10-28 | RF60/RF66: TEL-032 passa a mostrar o dia atual e horário de conclusão válida, com retorno ao intervalo da Família; TEL-011 mantém o filtro livre. |
| 1.22 | 2026-10-27 | RF60: incentivos na Família, Parabenizar por Administrador e mensagem recebida em Minhas tarefas. |
| 1.21 | 2026-10-27 | RF11, RF22, RF24, RF60–61 e RF66: intervalo livre, projeção de Pendentes para Membro, menu do PDF em TEL-011 e configurações em TEL-057. |
| 1.20 | 2026-10-27 | RF13: explicita a preservação da data prevista já gravada, inclusive após edição individual, no alcance “selecionada e futuras”. Para SPEC-008 Fase 2 / SCRUM-45. |
| 1.19 | 2026-10-27 | RF13: alcance “selecionada e futuras” limitado a título, peso, responsáveis e observação, sem alterar data inicial, frequência ou data prevista, e substituindo edições individuais anteriores das futuras abrangidas. Para SPEC-008 Fase 2. |
| 1.18 | 2026-10-22 | RF48: titular adulto edita o próprio nome de identificação (RF02), Kids não; consulta do próprio perfil inclui o nome da família. Para SPEC-006 (SCRUM-52). |
| 1.17 | 2026-10-19 | RF59: exclusão que deixa apenas tarefas concluídas conclui a missão na mesma transação (RN38; SPEC-014/SPEC-007). RF01–03/RF38/RF40/RF48/RF67: foto antecipada, membros no rascunho, criação atômica e edição da família existente. RF11/RF22/RF24: apresentação por perfil sem alterar estado. RF41: emissão inicial direta e confirmação de reemissão. |
| 1.16 | 2026-10-10 | RF18 e RF20 preservam e identificam carga histórica de membro removido. Para SPEC-018. |
| 1.15 | 2026-10-10 | RF34 passa a detalhar título, descrição, unicidade e catálogo inicial dos itens de recompensa coletiva. Para SPEC-015. |
| 1.14 | 2026-10-07 | RF01, RF02, RF38, RF41 e RF48 passam a cobrir o onboarding do Criador: rascunho de perfil, criação da família, adição opcional de membros e emissão explícita de convite antes da área principal. |
| 1.13 | 2026-10-07 | RF48 passa a definir o limite do apelido: até 20 caracteres não-espaço após trim, sem caracteres de controle; vazio/nulo remove a configuração. Para SPEC-006. |
| 1.12 | 2026-10-07 | RF71 (novo) define observação opcional de até 250 caracteres na missão, espelhando RF70. Para SPEC-014. |
| 1.11 | 2026-10-07 | Conclusão direta mantém responsáveis existentes ou atribui o adulto sem responsável; reabertura por todos os perfis no alcance de consulta pode reabrir missão concluída e reverte recompensa, participações e badges. |
| 1.10 | 2026-10-06 | RF12 e RF26 restringem conclusão manual de tarefa com responsável Kids ao Administrador e preservam a evidência pendente para auditoria. Para SPEC-010. |
| 1.9 | 2026-10-06 | RF22 e RF49 definem consulta e progresso próprios diários, inclusive para Kids. Para SPEC-009. |
| 1.8 | 2026-10-06 | RF13 passa a incluir observação opcional, ausência de data final obrigatória e alcance inclusivo da ocorrência selecionada; RF70 passa a cobrir a configuração de rotina. Para SPEC-008. |
| 1.7 | 2026-10-06 | RF02, RF03 e RF40 passam a definir o nome administrativo de membro e os papéis permitidos na criação, para elaboração de SPEC-003. RF07 passa a exigir título de 1–60 caracteress e aceitar observação opcional; RF69 (novo) define a escolha entre Pendente e Aguardando confirmação ao editar tarefa sinalizada, e a remoção da sinalização ao excluir; RF70 (novo) define a observação opcional de até 250 caracteres. Para SPEC-007. |
| 1.6 | 2026-10-06 | RF01 passa a definir o nome obrigatório da família: 1–60 caracteres Unicode visíveis após trim, sem caracteres de controle; decisão registrada na aprovação de SPEC-002. |
| 1.5 | 2026-10-05 | Pendências consolidadas: fuso, datas livres, edição de concluídas, participações/badges, convites e sessão única; RF67/68; arquitetura, modelo e design 1.1. |
| 1.4 | 2026-10-02 | Família concentra indicadores, lista, inclusão de membros e PDF; detalhe do membro reúne tarefas Dia/Semana, edição e reenvio quando permitidos. RN60–61, RF60–61/RF66 e UC02/11/13/18 revisados. |
| 1.3 | 2026-10-02 | Duas abas Kids, câmera direta, foto/apelido e badges, progresso/carga Dia/Semana, PDF semanal e reconhecimento com WhatsApp; RN61–65, RF61–66, RNF26–27 e UC18–19. Empates e visibilidade do apelido confirmados. |
| 1.2 | 2026-10-01 | Área Família na navegação adulta, progresso coletivo diário e consulta por carrossel: RN60, RF60 e UC11. Design em elaboração na versão 1.0. |
| 1.1 | 2026-10-01 | Recuperação do mesmo perfil por novo convite e renovação sem expiração temporal, com revogação preservada: RN47, RF41, RF46, RF54, RNF22, UC02 e UC09. |
| 1.0 | 2026-10-01 | Primeira versão consolidada, incluindo todas as decisões registradas até esta publicação e links para a visão e a apresentação do projeto. |
