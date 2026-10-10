# User flows — versão 1.10

**Projeto:** App de Organização Familiar — MVP  
**Versão dos fluxos:** 1.10\
**Base funcional:** 1.15\
**Screen map:** 1.10 — revisão de 2026-10-10\
**Data:** 2026-10-10\
**Situação:** primeira versão para revisão de design

[Projeto](../../README.md) · [Índice documental](../DOCUMENTACAO.md) · [Screen map](screen-map.md) · [Regras](../01-regras-de-negocio.md) · [Requisitos](../02-requisitos.md) · [Casos de uso](../03-casos-de-uso.md) · [Diagrama de classes](../06-diagrama-de-classes.md)

## Como ler

A implementação futura destes percursos é detalhada na [arquitetura mobile](../architecture/mobile-architecture.md), com [rastreabilidade UC–TEL/MOD–UF](../architecture/mobile-feature-catalog.md#4-casos-de-uso-mobile-e-rastreabilidade-funcional), contratos e tratamento de falhas. Os fluxos abaixo continuam como referência da experiência.

Cada fluxo representa um objetivo do usuário e usa as telas `TEL` e os modais `MOD` do screen map. `UF` identifica o fluxo e deve ser preservado nas próximas revisões. Os códigos RN e RF citados remetem à base funcional; os links de UC levam à especificação completa.

Nos diagramas, retângulos representam telas ou ações, losangos representam decisões e formas arredondadas representam resultados ou pontos de entrada/saída. Um nó de ação ou resultado não cria uma tela adicional. As setas mostram a sequência dentro daquele objetivo. A condição escrita na seta determina o caminho.

**Minhas tarefas, Meu perfil, Missões e conquistas e Família são destinos independentes da navegação principal adulta.** Minhas tarefas é o destino inicial após acesso. Os fluxos iniciados em Família, Meu perfil ou Missões não passam por Minhas tarefas. Kids possuem duas abas independentes: Minhas tarefas e Missões e conquistas; Meu perfil é acessado pelo avatar/cabeçalho.

O detalhamento traduz a base 1.5 em caminhos para design; as decisões de 2026-10-05 estão consolidadas nas regras e no registro de arquitetura. Falhas e retornos comuns são definidos abaixo e se aplicam a todos os diagramas, mesmo quando não repetidos em cada desenho.

## Condições comuns

| Situação | Resposta e continuação |
|---|---|
| Operação em andamento | Exibir processamento sem bloquear toda a interface e sem indicar sucesso antes da confirmação. |
| Falha de consulta | Informar que os dados não puderam ser carregados e oferecer nova tentativa na mesma tela; não confundir falha com lista vazia. |
| Falha de gravação | Consultar estado após resposta perdida, sem repetição automática ou chave geral de operação; informar quando não for possível determinar se uma criação foi salva; permanecer na tela de origem da operação e permitir nova tentativa. Não atualizar progresso como se houvesse sucesso. |
| Cancelar formulário ou modal | Retornar à origem sem gravar a alteração cancelada. Fechar um seletor interno retorna ao formulário que o abriu. |
| Voltar após consulta | Retornar à tela que abriu o detalhe, mantendo o contexto de data quando aplicável. |
| Sessão renovável | Renovação transparente; refresh token sem expiração temporal continua sujeito à revogação. |
| Sessão perdida | Entrada TEL-001 e recuperação UF-03; o Criador usa Apple. Perfil removido não recupera acesso por convite nem renovação. |
| Permissão ou estado mudou | Revalidar antes da operação, informar a indisponibilidade e apresentar o estado atual sem concluir a ação proibida. |
| Ações simultâneas | Última edição válida persistida prevalece, com risco de sobrescrita aceito; não duplicar conclusão, crédito, ingresso ou resgate. |

Referências transversais: RNF01, RNF05–13 e RNF17–25, conforme a operação. Textos e ícones complementam as cores. Controles não visíveis não substituem verificação de permissão.

## Índice e cobertura

| Fluxo | Objetivo | Perfis | Casos de uso |
|---|---|---|---|
| [UF-01](#uf-01) | Criar família ou retornar como Criador | Criador | UC01, UC04 |
| [UF-02](#uf-02) | Convidar e ingressar | Administrador e pessoa convidada | UC02, UC09 |
| [UF-03](#uf-03) | Recuperar acesso ao perfil | Usuário sem sessão e Administrador | UC02, UC04, UC09 |
| [UF-04](#uf-04) | Consultar tarefas e progresso pessoal diário ou familiar Dia/Semana | Todos; área Família somente adultos | UC11 |
| [UF-05](#uf-05) | Criar ou editar tarefa e rotina | Administrador, Membro | UC07, UC08 |
| [UF-06](#uf-06) | Concluir tarefa mantendo ou assumindo responsáveis | Administrador, Membro | UC12 |
| [UF-07](#uf-07) | Sinalizar e validar tarefa Kids | Kids e Administrador | UC15, UC03 |
| [UF-08](#uf-08) | Reabrir e excluir tarefa | Administrador; exclusão também Membro | UC17, UC07 |
| [UF-09](#uf-09) | Consultar carga diária ou semanal | Administrador, Membro | UC13 |
| [UF-10](#uf-10) | Criar, editar e acompanhar missão | Gestão: Administrador; consulta: todos | UC05, UC14 |
| [UF-11](#uf-11) | Cadastrar item e resgatar recompensa | Administrador | UC06, UC16 |
| [UF-12](#uf-12) | Gerenciar membros e permissões | Administrador | UC02 |
| [UF-13](#uf-13) | Editar o próprio perfil e consultar badges | Todos | UC10 |
| [UF-14](#uf-14) | Gerar relatório semanal PDF | Administrador, Membro | UC18 |
| [UF-15](#uf-15) | Receber e compartilhar destaque semanal | Sistema e reconhecido, inclusive Kids | UC19 |
| [UF-16](#uf-16) | Configurar fuso da família | Administrador | UC01 |

<a id="uf-01"></a>

## UF-01 — Criar família ou retornar como Criador

**Objetivo:** acessar a família do Criador, criando-a somente quando ainda não existir.  
**Entrada:** TEL-001, sem sessão válida.  
**Referências:** [UC01](../03-casos-de-uso.md#uc01), [UC04](../03-casos-de-uso.md#uc04); RN28, RN44; RF01, RF37–39, RF67.

```mermaid
flowchart TD
    A["TEL-001 · Entrada"] --> B["Autenticar com Apple"]
    B --> C{"Autenticação válida?"}
    C -->|Cancelada ou falhou| A
    C -->|Sim| D{"Família já vinculada?"}
    D -->|Sim| H["TEL-010 · Minhas tarefas"]
    D -->|Não| E["TEL-055 · Perfil: nome obrigatório, foto e etiqueta opcionais"]
    E --> F{"Dados válidos?"}
    F -->|Não · corrigir| E
    F -->|Sim| G["TEL-002 · Nome e fuso / padrão America/Sao_Paulo"]
    G --> I{"Criação confirmada?"}
    I -->|Não · informar falha| G
    I -->|Sim| J["TEL-056 · Adicionar membros iniciais"]
    J -->|Adicionar membro| K["TEL-033 · Criar membro"]
    K -->|Salvar| L{"Gerar convite agora?"}
    L -->|Sim| M["TEL-034 · Confirmar e compartilhar convite"]
    M --> J
    L -->|Não| J
    J -->|Avançar, inclusive sem membro| H
```

**Resultado:** família acessível ao Criador, com perfil Administrador e identificação protegida. O rascunho de perfil não existe antes da criação; a foto é opcional e pode ser enviada depois que a sessão for aberta, sem impedir a entrada. Retorno a uma família existente não cria outra. Cancelar antes da criação encerra o onboarding sem salvar; depois da criação, a pessoa pode avançar de TEL-056 sem adicionar membro.

<a id="uf-02"></a>

## UF-02 — Convidar e ingressar

**Objetivo:** criar o perfil e permitir um único ingresso pelo convite correspondente.  
**Entrada:** Administrador acessa Família diretamente pela navegação principal.  
**Referências:** [UC02](../03-casos-de-uso.md#uc02), [UC09](../03-casos-de-uso.md#uc09); RN09, RN45–47; RF40–46, RF54, RF68.

```mermaid
flowchart TD
    subgraph Admin["Administrador"]
      A["TEL-050 · Família"] -->|Adicionar membro| C["TEL-033 · Adicionar membro e definir perfil"]
      C --> D{"Dados e perfil válidos?"}
      D -->|Não · corrigir| C
      D -->|Sim · salvar| E["TEL-032 · Perfil salvo"]
      E --> F["Confirmar emissão: revogar convites e sessão anteriores"]
      F --> G["TEL-034 · Link e senha disponíveis"]
      G --> H["Compartilhar link e senha juntos"]
    end
    subgraph Convidado["Pessoa convidada"]
      H --> I["Abrir link"]
      I --> ACTIVE{"Sessão ativa?"}
      ACTIVE -->|Não| J
      ACTIVE -->|Sim| SWITCH["MOD-013 · Confirmar troca"]
      SWITCH -->|Cancelar| KEEP(["Manter acesso atual"])
      SWITCH -->|Confirmar| J{"Convite disponível e perfil ativo?"}
      J -->|Não| K["Informar impedimento · TEL-004"]
      J -->|Sim| L["Informar senha"]
      L --> M{"Senha válida?"}
      M -->|Não · corrigir| L
      M -->|Sim| N["Validar, consumir uma vez e substituir acesso local após sucesso"]
      N --> O{"Ingresso confirmado?"}
      O -->|Não| P["Informar falha ou convite já consumido"]
      O -->|Sim| Q{"Perfil Kids?"}
      Q -->|Sim| R["TEL-040 · Minhas tarefas Kids"]
      Q -->|Não| S["TEL-010 · Minhas tarefas"]
    end
```

**Exceções e retornos:** falha ao salvar perfil permanece em TEL-033; falha ao gerar convite retorna à ação em TEL-032 sem exibir credenciais fictícias. Perfil já salvo não é recriado para tentar gerar o convite novamente. Cancelar o compartilhamento mantém o perfil criado. Senha incorreta não consome o convite; controles de tentativas abusivas continuam aplicáveis. Convite consumido não permite outro ingresso; recuperação segue UF-03. Falha de rede no ingresso exige conferir o estado corrente antes de repetir.

**Resultado:** acesso ao perfil correto em sessão única e convite consumido uma vez. Troca não remove o perfil da família anterior nem migra histórico. Sem app, direcionar à loja e reabrir convite depois de instalar. Resposta perdida no ingresso tem recuperação específica comprovada por dez minutos; depois exige novo convite. Compartilhar o convite, sozinho, não significa que o convidado ingressou.

<a id="uf-03"></a>

## UF-03 — Recuperar acesso ao mesmo perfil

**Objetivo:** retornar sem duplicar membro, tarefas ou histórico.  
**Entrada:** perda real da sessão; uma sessão renovável permanece no aplicativo.  
**Referências:** [UC02](../03-casos-de-uso.md#uc02), [UC04](../03-casos-de-uso.md#uc04), [UC09](../03-casos-de-uso.md#uc09); RN47; RF41, RF46, RF54; RNF22.

```mermaid
flowchart TD
    A["TEL-001 · Entrada"] --> B["TEL-004 · Orientação para recuperar acesso"]
    B --> C{"É o Criador?"}
    C -->|Sim| D(["UF-01 · Retornar com Apple"])
    C -->|Não| E["Solicitar novo convite a um Administrador fora do app"]
    E --> F["Admin: TEL-050 → selecionar membro → TEL-032"]
    F --> G{"Mesmo perfil ainda ativo?"}
    G -->|Não| H(["Recuperação indisponível para perfil removido"])
    G -->|Sim| I["Confirmar novo convite · revogar convites e sessão anteriores · TEL-034"]
    I --> J["Compartilhar novo link e senha"]
    J --> K(["UF-02 · Retomar a partir de TEL-003"])
```

**Resultado:** ingresso com um novo convite de uso único recupera o perfil existente e seus vínculos. Não há mensagem automática ao Administrador, formulário de pedido de recuperação ou senha permanente. Sem novo convite, o usuário permanece fora da área protegida; não se cria um perfil substituto como parte da recuperação.

<a id="uf-04"></a>

## UF-04 — Consultar tarefas e progresso pessoal diário ou familiar Dia/Semana

**Objetivo:** consultar o período pessoal ou o período da família e abrir uma tarefa permitida.  
**Entrada:** Minhas tarefas ou Família, escolhidas independentemente.  
**Referências:** [UC11](../03-casos-de-uso.md#uc11); RN26, RN49, RN60–61; RF11, RF17, RF22, RF49, RF60, RF66.

```mermaid
flowchart TD
    A(["Escolher visão e data de referência"]) --> B{"Qual visão?"}
    B -->|Pessoal adulto| C["TEL-010 · Minhas tarefas"]
    B -->|Pessoal Kids| D["TEL-040 · Minhas tarefas Kids"]
    B -->|Familiar adulto| E["TEL-050 · Família"]
    C --> F["Escolher data diária"]
    D --> F
    E -->|Consultar totais da família| FF["Escolher Dia ou Semana mantendo a data de referência"]
    E -->|Selecionar membro da lista| PM["TEL-032 · Tarefas daquele membro · Dia/Semana"]
    PM --> FF
    F --> G{"Data no intervalo permitido?"}
    FF --> G
    G -->|Não| H["Impedir seleção e manter data válida"]
    H --> F
    G -->|Sim| I{"Há tarefas nessa visão e período?"}
    I -->|Não| J(["Mostrar Sem tarefas"])
    I -->|Sim| K["Mostrar tarefas ou resumo e progresso da visão escolhida"]
    K --> L{"Abrir uma tarefa?"}
    L -->|Não| M(["Permanecer na consulta"])
    L -->|Pessoal adulto| N["TEL-012 · Detalhe da tarefa"]
    L -->|Pessoal Kids| O["TEL-041 · Detalhe da minha tarefa"]
    L -->|Membro selecionado| N
    L -->|Todas as tarefas da família| P["TEL-011 · Preservar período e selecionar tarefa"]
    P --> N
```

Em Minhas tarefas, todos os perfis consultam somente o dia de referência e seu progresso diário. Dia/Semana mantém a data de referência nas superfícies familiares adultas. A semana vai de segunda a domingo; semanas de borda indicam os dias disponíveis. Progresso semanal familiar usa concluídas/total da semana, não a média dos percentuais diários. O intervalo vai da criação da família ao último dia do mês corrente, incluindo dias futuros desse mês. Na visão familiar, cada tarefa prevista no período conta uma vez no total e, se concluída, uma vez no numerador; peso e quantidade de responsáveis não multiplicam o progresso. Tarefas sem responsável entram no total. Aguardando confirmação não conta como concluída.

TEL-032 mantém o membro selecionado ao alternar Dia/Semana e abre TEL-012 para uma tarefa. Herdar o período da Família não liga os seletores: voltar restaura a seleção anterior de TEL-050. Membro sem tarefas mostra estado vazio; falha de consulta não é apresentada como ausência de tarefas. A carga não integra TEL-050 nesta entrega e fica para SPEC-018. Ações administrativas no detalhe seguem UF-12.

**Continuação:** adultos podem seguir UF-05, UF-06 ou UF-08 a partir das telas permitidas; Kids seguem UF-07 somente para tarefa própria pendente. Voltar do detalhe restaura a origem, que pode ser uma lista pessoal, familiar ou missão. Consultar outra data não altera tarefas. Ao abrir o checklist em um novo dia, o padrão volta a ser o dia atual.

<a id="uf-05"></a>

## UF-05 — Criar ou editar tarefa e rotina

**Objetivo:** salvar tarefa única ou rotina com esforço e responsáveis opcionais.  
**Entrada:** TEL-010/TEL-011 para criar; TEL-012 para editar. Adultos apenas.  
**Referências:** [UC07](../03-casos-de-uso.md#uc07), [UC08](../03-casos-de-uso.md#uc08); RF07–10, RF13–16, RF58, RF69, RF70.

```mermaid
flowchart TD
    A(["Criar ou editar tarefa"]) --> B["TEL-013 · Título (1–60 car.), peso 1 a 3, data livre / padrão hoje e observação opcional (até 250 car.)"]
    B --> C["MOD-001 · Definir nenhum, um ou vários responsáveis"]
    C --> D["MOD-002 · DatePicker inicial livre e frequência"]
    D --> E{"Editando tarefa de rotina?"}
    E -->|Sim| F["MOD-003 · Escolher edição individual ou rotina futura"]
    E -->|Não| G2{"Editando tarefa Aguardando confirmação?"}
    F --> G2
    G2 -->|Sim| F2["MOD-014 · Retornar a Pendente ou manter Aguardando confirmação"]
    G2 -->|Não| G["Conferir e salvar"]
    F2 --> G
    G --> H{"Dados, alcance e proteção válidos?"}
    H -->|Não| I["Explicar campos ou registros impedidos"]
    I --> B
    H -->|Sim| J["Persistir tarefa ou configuração de rotina"]
    J --> K{"Gravação confirmada?"}
    K -->|Não · informar falha| B
    K -->|Sim| L(["Retornar à origem com dados atualizados"])
```

Responsáveis e repetição são escolhas do formulário; não é obrigatório abrir os seletores quando a configuração desejada já estiver definida. Repetição oferece sem repetição, diária ou a cada 7, 14, 21 ou 28 dias. Não há mensal nem data final obrigatória. Datas de cadastro/início são livres, inclusive antes da criação da família e em meses futuros. Backend mantém geração até fim do mês seguinte, com reposição diária e complemento em consulta. Cada ocorrência possui estado próprio; escolher uma tarefa não altera automaticamente outras ocorrências.

**Proteções:** edição individual afeta somente a selecionada; alteração de rotina no alcance “selecionada e futuras” inclui a ocorrência aberta e alcança somente futuras elegíveis, preservando passado e conquistas concluídas. O limite de consulta do carrossel não interrompe a geração futura. Concluída não protegida pode ser editada individualmente: peso/responsáveis ajustam crédito, data prevista ajusta progresso, sem mudar instante de conclusão ou destaque já finalizado; manter auditoria. Sem responsáveis, não há crédito individual. Última edição válida persistida vence. Cancelar antes de salvar não grava as mudanças e retorna à lista ou ao detalhe de origem. Editar tarefa Aguardando confirmação exige MOD-014 antes de salvar, mesmo que só a observação tenha mudado: retornar a Pendente descarta a sinalização corrente da criança, e manter Aguardando confirmação preserva a sinalização para decisão com os dados atualizados (RN66, RF69).

<a id="uf-06"></a>

## UF-06 — Concluir tarefa mantendo ou assumindo responsáveis

**Objetivo:** concluir a tarefa inteira diretamente, com crédito previsível.
**Entrada:** TEL-012, tarefa Pendente ou Aguardando confirmação; Administrador ou Membro apenas quando não houver responsável Kids.
**Referências:** [UC12](../03-casos-de-uso.md#uc12); RN48, RN55–56; RF12, RF47, RF56.

```mermaid
flowchart TD
    A["TEL-012 · Acionar concluir"] --> AK{"Há responsável Kids?"}
    AK -->|Sim e Membro| J(["TEL-012 · Ação não disponível"])
    AK -->|Não ou Administrador| B{"Há responsáveis?"}
    B -->|Não| C["Atribuir automaticamente ao adulto que conclui"]
    B -->|Sim| D["Manter responsáveis atuais"]
    C --> K["Revalidar estado e salvar conclusão e responsáveis juntos"]
    D --> K
    K --> L{"Operação confirmada?"}
    L -->|Sim| M(["TEL-012 · Concluída para todos os responsáveis finais"])
    L -->|Já concluída| M
    L -->|Falha| N["Informar falha e consultar estado atual"]
```

Concluir não exibe alerta. Cada responsável final recebe o peso integral; quem apenas executou a ação não recebe crédito se não for responsável. A tarefa conta uma vez no progresso de cada missão e no progresso coletivo diário ou semanal. Tarefa com responsável Kids só é concluída manualmente por Administrador; a pendência e foto são preservadas para auditoria administrativa. Se outra conclusão já foi confirmada, a interface atualiza silenciosamente para Concluída. Outras ocorrências da rotina não mudam.

<a id="uf-07"></a>

## UF-07 — Sinalizar e validar tarefa Kids

**Objetivo:** a criança informa a realização e um Administrador decide sobre a tarefa.  
**Entrada:** Kids em TEL-040; Administrador acessa Família independentemente.  
**Referências:** [UC15](../03-casos-de-uso.md#uc15), [UC03](../03-casos-de-uso.md#uc03); RN22–26, RN54–55; RF23–26, RF55–56.

```mermaid
flowchart TD
    subgraph Crianca["Kids"]
      A["TEL-040 · Selecionar tarefa"] --> B["TEL-041 · Detalhe"]
      B --> C{"Própria tarefa pendente?"}
      C -->|Não| D(["Consultar estado sem nova sinalização"])
      C -->|Sim| E["MOD-011 · Preparar sinalização"]
      E --> CF{"Adicionar foto?"}
      CF -->|Não · enviar sem foto| G
      CF -->|Sim| CAM[["Abrir câmera / solicitar permissão"]]
      CAM --> CP{"Câmera disponível e autorizada?"}
      CP -->|Não ou cancelou| E
      CP -->|Sim| CAP["Capturar e revisar foto"]
      CAP -->|Refazer| CAM
      CAP -->|Descartar| E
      CAP -->|Usar e enviar| F
      F{"Foto anexada foi enviada?"}
      F -->|Sim| G["Salvar sinalização"]
      F -->|Falhou| H{"Tentar de novo ou seguir sem foto?"}
      H -->|Tentar de novo| E
      H -->|Sem foto| G
      G --> I(["TEL-041 · Aguardando confirmação"])
    end
    subgraph Admin["Administrador · acesso independente"]
      J["TEL-050 · Família"] --> K["TEL-015 · Confirmações Kids"]
      K --> L{"Há sinalizações?"}
      L -->|Não| M(["Fila vazia"])
      L -->|Sim · selecionar| N["TEL-016 · Avaliar tarefa e foto opcional"]
      N --> O{"Confirmar ou recusar?"}
      O -->|Confirmar| P["Revalidar e concluir para todos"]
      O -->|Recusar| Q["Revalidar e retornar a Pendente para todos"]
      P --> R(["Retornar à fila atualizada"])
      Q --> R
    end
    I -.->|Sinalização disponível na fila| K
```

Permissão negada ou câmera indisponível exibe orientação e permite continuar sem foto; não abre galeria automaticamente. Revisar captura não envia a sinalização por si só.

A seta tracejada liga os registros entre os dois usuários; não representa navegação da criança para a área administrativa. Sinalização e decisão só mudam a tela após gravação confirmada. Cancelar MOD-011 mantém a tarefa como estava. Voltar de TEL-016 sem decidir mantém a sinalização na fila.

**Resultados:** sinalizar não credita peso nem progresso parcial. A ausência de foto não impede sinalizar ou confirmar. Recusar volta a Pendente; a criança pode sinalizar novamente. Confirmar conclui para todos. Se outro adulto já concluiu manualmente por UF-06, atualizar o estado e impedir nova decisão. Não há conclusão parcial por responsável nem nova sinalização enquanto aguarda confirmação.

<a id="uf-08"></a>

## UF-08 — Reabrir e excluir tarefa

**Objetivo:** aplicar a alteração permitida sem corromper conquistas ou descontar carga duas vezes.  
**Entrada:** TEL-012. Reabertura por Administrador/Membro em tarefa acessível e por Kids em tarefa própria; exclusão por Administrador ou Membro.
**Referências:** [UC17](../03-casos-de-uso.md#uc17), [UC07](../03-casos-de-uso.md#uc07); RN50, RN57–59, RN66; RF09, RF57–59, RF69.

```mermaid
flowchart TD
    A["TEL-012 · Solicitar reabertura ou exclusão"] --> B{"Tarefa concluída?"}
    B -->|Sim| C{"Missão concluída ou recompensa aceita?"}
    C -->|Não| F["Pendente · retirar crédito anterior e recalcular progresso"]
    C -->|Sim| E["MOD-006 · Avisar que a missão será reaberta e confirmar"]
    E -->|Cancelar| D(["TEL-012 · Manter concluída"])
    E -->|Confirmar e salvar| F
    F --> G{"Deseja excluir depois?"}
    G -->|Não| H(["TEL-012 · Pendente"])
    G -->|Sim| I{"É ocorrência de rotina?"}
    B -->|Não · excluir| I
    I -->|Sim| J["MOD-003 · Selecionada ou selecionada e futuras"]
    I -->|Não| K["Verificar vínculos e proteções"]
    J --> K
    K --> L{"Afeta conquista ou deixa missão sem tarefas?"}
    L -->|Sim| D
    L -->|Não| M["MOD-005 · Conferir alcance e confirmar exclusão"]
    M -->|Cancelar| N(["Voltar sem excluir"])
    M -->|Confirmar e salvar| O(["Retornar à lista de origem atualizada"])
```

Não existe exclusão direta de tarefa concluída. Reabrir uma tarefa vinculada a missão concluída e/ou com recompensa aceita exige MOD-006: confirmar retorna a missão para Em andamento e remove recompensa, participações e badges derivados, sem histórico. Em exclusão de rotina, preservar ocorrências concluídas e informar os registros que não podem ser excluídos. A última tarefa de uma missão exige vincular outra antes de tentar excluí-la. Não se contorna a proteção de missão concluída pela mudança de alcance. Excluir uma tarefa Aguardando confirmação remove a sinalização corrente da criança junto com a tarefa, sem pedir confirmação adicional sobre a sinalização (RN66).

A reabertura é uma operação independente: retira o crédito do dia e da semana da conclusão anterior para todos os responsáveis, mantém responsáveis e atualiza progresso. Se a exclusão posterior falhar ou for cancelada, a reabertura já salva permanece. A exclusão não desconta o peso novamente. Cada gravação segue as condições comuns de falha e concorrência.

<a id="uf-09"></a>

## UF-09 — Consultar carga diária ou semanal

**Objetivo:** entender a distribuição da participação creditada no período.  
**Entrada:** Família, por Administrador ou Membro.  
**Referências:** [UC13](../03-casos-de-uso.md#uc13); RN28, RN30–34, RN61; RF18–21, RF56–57, RF66.

```mermaid
flowchart TD
    A["TEL-050 · Minha família · carga e progresso integrados"] --> C["Escolher Dia ou Semana e data de referência"]
    C --> D{"Há conclusões válidas no período?"}
    D -->|Não| E["Informar ausência de carga"]
    D -->|Sim| F["Mostrar peso por membro e participação no total"]
    E --> G{"Próxima ação"}
    F --> G
    G -->|Outro período| C
    G -->|Gerar PDF semanal| H(["UF-14 · TEL-051"])
    G -->|Voltar| A
```

Cada responsável recebe o peso integral; o total soma cargas individuais. Pendentes e Aguardando confirmação não entram. Reaberturas ajustam o dia e a semana originais. Crédito histórico de perfil removido aparece como “Membro removido”, sem dado pessoal. Sem carga, não dividir por zero. A semana vai de segunda a domingo; a consulta ocorre na própria TEL-050 e mantém a referência selecionada. Kids não acessam esta tela. O destaque semanal é consultado separadamente em UF-15.

<a id="uf-10"></a>

## UF-10 — Criar, editar e acompanhar missão

**Objetivo:** organizar uma conquista coletiva sem prazo e acompanhar seu progresso.  
**Entrada:** Missões e conquistas, diretamente na navegação adulta; Kids diretamente na aba Missões e conquistas.  
**Referências:** [UC05](../03-casos-de-uso.md#uc05), [UC14](../03-casos-de-uso.md#uc14); RN35–40, RN50–51, RN58; RF28–32, RF36, RF50, RF58.

```mermaid
flowchart TD
    A["TEL-020 · Missões e conquistas"] --> B{"Ação permitida escolhida"}
    B -->|Criar · Admin| C["TEL-022 · Dados da missão"]
    B -->|Consultar| D["TEL-021 · Detalhe da missão"]
    D --> E{"Editar · Admin e missão em andamento?"}
    E -->|Sim| C
    E -->|Não| F(["Consultar progresso, tarefas, participações e recompensa"])
    C --> G["MOD-007 · Selecionar tarefas individuais"]
    G -->|"+ Nova tarefa"| G1["Fluxo padrão de criação de tarefa (TEL-013/MOD-001)"]
    G1 --> G["Retorna com a tarefa pré-selecionada"]
    G --> H{"Ao menos uma tarefa selecionada?"}
    H -->|Não · bloqueado localmente, sem chamar o servidor| G
    H -->|Sim| I["Salvar missão e vínculos"]
    I --> J{"Todas as tarefas vinculadas concluídas?"}
    J -->|Não| K["Missão em andamento"]
    J -->|Sim| L["Missão concluída · participações e marcos · habilitar resgate"]
    K --> R{"Origem do formulário?"}
    L --> R
    R -->|Criação| A
    R -->|Edição| D
    F --> M{"Resgatar · Admin e concluída sem recompensa?"}
    M -->|Sim| N(["UF-11 · Roleta"])
    M -->|Não| O(["Permanecer na consulta ou voltar à lista"])
```

Salvar retorna à origem que abriu o formulário: à lista em criação e ao detalhe em edição. Missão encerrada conta uma vez para cada responsável creditado em uma ou mais tarefas vinculadas; marcos 5/10/25/50 concedem badges cumulativos. Sem missões, TEL-020 mostra o estado vazio; somente Administradores têm ação de criação. Sem tarefas disponíveis, o Administrador cria uma tarefa diretamente em MOD-007 (atalho para UF-05) ou navega a UF-05 antes de salvar uma missão; o botão Salvar permanece desabilitado enquanto não houver ao menos uma tarefa selecionada, sem chamar o servidor nesse estado.

Cada tarefa vinculada conta uma vez, sem incluir a rotina inteira implicitamente. Remover vínculos de missão em andamento pode concluí-la se todas as restantes estiverem concluídas; desmarcar a última tarefa restante sem substituição é bloqueado no próprio MOD-007, com mensagem explicando que uma missão precisa de ao menos uma tarefa. Progresso também é recalculado por conclusões e reaberturas autorizadas fora deste fluxo. Missão concluída não aceita edição; a única exceção é a reabertura confirmada de tarefa vinculada, que remove os dados derivados do encerramento. Não existe expiração por tempo.

**Consulta de tarefas:** adultos podem abrir TEL-012 a partir do detalhe da missão. Kids podem abrir TEL-041 somente para tarefas próprias; acompanhar as demais tarefas da missão não concede ações operacionais. Kids consultam título, observação, tarefas vinculadas, status e recompensa aceita em TEL-020/021 numa apresentação simplificada, sem ações de gestão, participações ou resgate. Voltar retorna a TEL-021.

<a id="uf-11"></a>

## UF-11 — Cadastrar item e resgatar recompensa

**Objetivo:** manter opções coletivas e aceitar uma única recompensa por missão.  
**Entrada:** TEL-020 para itens; TEL-021 para resgatar. Administrador apenas.  
**Referências:** [UC06](../03-casos-de-uso.md#uc06), [UC16](../03-casos-de-uso.md#uc16); RN41–43, RN52–53; RF33–35, RF51–53.

```mermaid
flowchart TD
    A["TEL-020 · Abrir itens de recompensa"] --> B["TEL-023 · Predefinidos e personalizados"]
    B --> C["MOD-008 · Adicionar item"]
    C --> D{"Dados válidos?"}
    D -->|Não · corrigir| C
    D -->|Sim · salvar| B
    E["TEL-021 · Resgatar recompensa"] --> F{"Missão concluída e sem recompensa aceita?"}
    F -->|Não| G(["Mostrar situação atual sem novo resgate"])
    F -->|Sim| H["TEL-024 · Roleta da missão"]
    H -->|Consultar itens| B
    B -->|Voltar à roleta quando for a origem| H
    H --> I["Sortear e animar no app / resultado ainda não salvo"]
    I --> J{"Decisão do Administrador"}
    J -->|Sortear novamente| I
    J -->|Sair sem aceitar| K(["TEL-021 · Resgate continua disponível"])
    J -->|Aceitar| L["Servidor valida item/disponibilidade e registra aceite único"]
    L --> M{"Aceitação confirmada?"}
    M -->|Sim| N(["TEL-021 · Recompensa aceita e resgate encerrado"])
    M -->|Outro Admin já aceitou| G
    M -->|Falha de gravação| O["Informar falha sem indicar aceitação"]
    O --> H
```

Cadastrar um item é opcional e independente: a roleta já dispõe dos itens predefinidos. No MOD-008, o título é obrigatório, sem caracteres de controle, tem até 60 caracteres não-espaço após `trim` e deve ser único na família sem distinguir maiúsculas/minúsculas; a descrição é opcional e tem até 255 caracteres contando espaços. Salvar um item o inclui em próximos sorteios, sem vinculá-lo a missão. Cancelar MOD-008 volta a TEL-023 sem adicionar. A origem de TEL-023 determina o retorno: lista de missões ou roleta.

**Resultado:** aceitação salva encerra o resgate para toda a família e acrescenta a recompensa à conquista sem alterar suas tarefas, progresso ou participações. Consultar itens, sortear ou sair sem aceitar não consome o resgate. Após falha ou concorrência, consultar a situação corrente antes de tentar aceitar novamente.

<a id="uf-12"></a>

## UF-12 — Gerenciar membros e permissões

**Objetivo:** ajustar perfil, modo Kids e papel, ou remover membro com efeitos claros.  
**Entrada:** selecionar um item da lista de membros na própria Família → Detalhe do membro; Administrador para gestão.  
**Referências:** [UC02](../03-casos-de-uso.md#uc02); RN01–10; RF02–06, RF40–41.

```mermaid
flowchart TD
    A["TEL-050 · Família · lista de membros"] -->|Selecionar membro| C["TEL-032 · Detalhe e tarefas do membro"]
    C --> D{"Ação"}
    D -->|Editar| E["TEL-033 · Alterar dados ou configuração"]
    E --> F{"Mudança permitida?"}
    F -->|Não| G["Explicar restrição e corrigir"]
    G --> E
    F -->|Sim · dados comuns| H["Salvar alteração"]
    F -->|Sim · papel ou modo| I["MOD-010 · Confirmar alteração"]
    I -->|Confirmar| H
    I -->|Cancelar| C
    H --> J(["TEL-032 · Perfil atualizado"])
    D -->|Remover| K{"É o Criador?"}
    K -->|Sim| L(["Remoção impedida"])
    K -->|Não| M["MOD-010 · Explicar efeitos e confirmar remoção"]
    M -->|Cancelar| C
    M -->|Confirmar e salvar| N(["TEL-050 · Lista atualizada após remoção"])
    D -->|Gerar ou reenviar convite| O(["TEL-034 · UF-02 ou UF-03"])
```

Administradores e Membros podem consultar as tarefas em TEL-032; somente Administradores acessam ações de gestão quando permitidas. Reenviar abre TEL-034 para confirmar emissão de novo link e senha, invalidando convites anteriores e revogando a sessão anterior do mesmo perfil. Cancelar volta ao detalhe preservando membro/período; falha não cria membro duplicado. O Criador recupera acesso por Apple.

**Restrições:** o Criador não pode ser removido, rebaixado nem sair. Um Administrador não pode permanecer em modo Kids; Kids devem sair desse modo antes da promoção. Alterações obedecem à permissão corrente de quem executa.

A remoção revoga também sessões e renovação de acesso, retira somente o removido das tarefas futuras não concluídas/não protegidas e preserva histórico concluído. Falha não deve apresentar o membro como removido. Um Administrador que não é Criador também pode deixar seu próprio papel por TEL-030 → MOD-010; após salvar, seus acessos passam a seguir o papel atual. Não é um fluxo de saída da família.

<a id="uf-13"></a>

## UF-13 — Editar o próprio perfil

**Objetivo:** alterar os dados pessoais permitidos, sem modificar permissões.  
**Entrada:** Meu perfil na navegação adulta ou pelo avatar/cabeçalho Kids; todos os perfis.  
**Referências:** [UC10](../03-casos-de-uso.md#uc10); RF48, RF62, RF65; RN63–64.

```mermaid
flowchart TD
    A["TEL-030 · Meu perfil"] --> B["MOD-009 · Editar foto opcional por câmera/galeria e apelido próprios"]
    B -->|Cancelar| A
    B -->|Salvar| C{"Dados válidos e permitidos?"}
    C -->|Não · corrigir| B
    C -->|Sim| D["Persistir alterações"]
    D --> E{"Gravação confirmada?"}
    E -->|Não · informar falha| B
    E -->|Sim| F(["TEL-030 · Dados atualizados"])
    A -->|Consultar marco| G["TEL-054 · Missões contribuintes"]
    G -->|Abrir missão| M["TEL-021 · Missão"]
    M -->|Voltar| G
    G -->|Voltar| A
```

O formulário permite adicionar/substituir/remover foto opcional e configurar etiqueta/apelido. Só o titular acessa a configuração de apelido, inclusive para Kids; a gestão administrativa de UF-12 não concede esse acesso. Cancelar ou falhar mantém os dados salvos anteriores. Foto ausente usa identificação padrão. Meu perfil também lista badges por participação e abre TEL-054 com as missões contribuintes, de onde se acessa TEL-021; sem badges, mostra total de participações e próximo marco. Não altera papel, família ou modo Kids. O apelido é visível à família; badges seguem os marcos cumulativos de RN64, sem concessão retroativa.

<a id="uf-14"></a>

## UF-14 — Gerar relatório semanal em PDF

**Objetivo:** obter a visão semanal da família em arquivo.  
**Entrada:** botão Gerar relatório PDF na própria Minha família (TEL-050), por adulto.  
**Referências:** [UC18](../03-casos-de-uso.md#uc18); RN62; RF61; RNF26–27.

```mermaid
flowchart TD
    A["TEL-050 · Gerar relatório PDF"] --> B["TEL-051 · Selecionar semana segunda–domingo"]
    B --> C{"Semana atual ou passada válida?"}
    C -->|Não| B
    C -->|Sim| D["Backend fornece snapshot / app gera PDF · atual parcial"]
    D --> E{"Arquivo gerado?"}
    E -->|Falha · informar e tentar novamente| B
    E -->|Sim| F["Visualizar gráficos, progresso e tabela por membro"]
    F --> G{"Ação"}
    G -->|Salvar ou compartilhar| H[["Interface do dispositivo"]]
    H -->|Concluir ou cancelar| F
    G -->|Outra semana| B
    G -->|Voltar| I(["Retornar à origem preservando período"])
```

O PDF contém gráficos de carga semanal e progresso total da família e, por membro, peso creditado e número de tarefas realizadas. Identifica período, geração e métricas de RN62; compartilhadas não duplicam o total familiar de tarefas. Ausência de dados permite PDF com indicação apropriada. Falha de geração não disponibiliza arquivo incompleto. Abrir compartilhamento não comprova envio. Kids não têm acesso.

<a id="uf-15"></a>

## UF-15 — Receber e compartilhar destaque semanal

**Objetivo:** reconhecer o primeiro lugar em pontos e incentivar uma atividade em família.  
**Entrada:** apuração automática na segunda-feira; consulta pela notificação ou destaque em Minhas tarefas.  
**Referências:** [UC19](../03-casos-de-uso.md#uc19); RN65; RF63–64; RNF26–27.

```mermaid
flowchart TD
    A["Sistema · segunda-feira 00:00 no fuso da família"] --> B["Apurar pontos da semana anterior encerrada"]
    B --> C{"Pontuação positiva?"}
    C -->|Não| D(["Registrar semana sem vencedor · RN65"])
    C -->|Sim| E["Registrar primeiro lugar sem duplicar · empate conforme RN65"]
    E --> F["Enfileirar notificação e disponibilizar destaque no app"]
    F --> G["Pessoa abre notificação ou Minhas tarefas"]
    G --> H{"Sessão válida e pessoa autorizada?"}
    H -->|Não| I["Acesso/recuperação ou informar acesso negado"]
    I -->|Acesso recuperado · revalidar| H
    H -->|Sim| J["TEL-052 · Semana, pontos e tarefas realizadas"]
    J --> K{"Compartilhar?"}
    K -->|Não| L(["Fechar · voltar à origem"])
    K -->|Sim| M{"WhatsApp disponível?"}
    M -->|Não| N["Oferecer copiar mensagem"]
    M -->|Sim| O[["WhatsApp · revisar texto, escolher destinatário e enviar"]]
    N --> J
    O -->|Retornar ou cancelar| J
```

Texto do convite: “Mande para sua família e sugira algo para vocês fazerem juntos.” Sugestão editável: “Fiquei em primeiro em pontos nas tarefas desta semana! Que tal fazermos algo juntos para celebrar? Minha sugestão é: ____.” Em empate, adaptar para “Fiquei entre os primeiros…”. Nada é enviado automaticamente. Sem notificação externa, o resultado continua disponível no app. Kids reconhecidos usam a mesma tela em variante adequada, sem acesso à carga familiar. Falha de apuração exige retentativa idempotente, sem publicar resultado parcial. Empate reconhece todos os primeiros colocados; todos os perfis ativos são elegíveis e sem pontos positivos não há vencedor; a apuração ocorre às 00:00 de segunda-feira no fuso vigente; resultados finalizados permanecem preservados após correções.

<a id="uf-16"></a>

## UF-16 — Configurar fuso da família

**Objetivo:** alterar o calendário comum com efeito imediato ou no próximo ciclo.\
**Entrada:** Família → Configurações da família (TEL-053), somente Administrador.\
**Referências:** [UC01](../03-casos-de-uso.md#uc01); RF67; RN28/RN65.

```mermaid
flowchart TD
    A["TEL-050 · Família"] --> B["TEL-053 · Fuso vigente e alteração programada"]
    B --> C["Selecionar novo fuso"]
    C --> D["MOD-012 · Informativo dos efeitos"]
    D -->|Cancelar| B
    D -->|Aplicar imediatamente| E["Confirmar efeito imediato"]
    D -->|Próximo ciclo| F["Confirmar programação"]
    E --> G["Salvar configuração no servidor"]
    F --> G
    G --> H{"Confirmado?"}
    H -->|Sim| B
    H -->|Falha ou resposta perdida| I["Consultar configuração atual / informar resultado"]
    I --> B
```

Padrão inicial é `America/Sao_Paulo`, selecionável em TEL-002. Mudança imediata afeta limites do ciclo aberto; programada mantém o atual até encerrar. Mostrar data de vigência, fuso e identificação de período de transição, sem deslocar datas civis das tarefas. Apurações finalizadas não mudam; ciclos não podem sobrepor-se ou deixar lacunas. Falha não é mostrada como alteração salva.

## Critérios de revisão

- Cada fluxo pode ser percorrido desde sua entrada até resultado, cancelamento ou impedimento explicado.
- Operações administrativas respeitam perfil, estado atual e proteção do Criador e das conquistas.
- As quatro telas principais adultas são entradas independentes; Minhas tarefas continua como inicial.
- Fluxos Kids não concedem carga, relatório familiar, gestão ou conclusão direta. Perfil próprio e reconhecimento recebido são permitidos.
- Toda alteração só é apresentada como concluída após confirmação da gravação.
- TEL/MOD preservam o screen map 1.10; UF-01–UF-16 cobrem UC01–UC19, incluindo TEL-051/052/053/054/055/056 e MOD-012/013.

## Histórico

| Versão dos fluxos | Base funcional | Screen map | Data | Alteração |
|---|---|---|---|---|
| 1.11 | 1.16 | 1.11 | 2026-10-10 | UF-09 integra carga Dia/Semana e preserva crédito histórico de removido sem ranking. Para SPEC-018. |
| 1.10 | 1.15 | 1.10 | 2026-10-10 | UF-10 alinha Kids a RF36: recompensa aceita é consultável; participações e resgate seguem indisponíveis. Para SPEC-016. |
| 1.9 | 1.15 | 1.9 | 2026-10-10 | UF-11 detalha título, descrição, limites e unicidade do item personalizado. Para SPEC-015. |
| 1.8 | 1.14 | 1.8 | 2026-10-07 | UF-01 passa a configurar o perfil do Criador, criar a família e permitir zero ou mais membros com convite explícito antes da área principal. |
| 1.7 | 1.12 | 1.7 | 2026-10-07 | UF-10 ganha atalho "+ Nova tarefa" em MOD-007, bloqueio local de salvar sem tarefas e consulta explícita por todos os perfis, inclusive Kids. Para SPEC-014. |
| 1.6 | 1.11 | 1.6 | 2026-10-07 | UF-06 conclui diretamente sem modal; UF-08 permite reabrir missão concluída com confirmação e reversão de recompensa, participações e badges. |
| 1.5 | 1.10 | 1.5 | 2026-10-06 | UF-06 restringe conclusão manual de tarefa com responsável Kids ao Administrador e reconcilia silenciosamente conclusão concorrente. Para SPEC-010. |
| 1.4 | 1.9 | 1.4 | 2026-10-06 | UF-04 distingue consulta própria diária da familiar adulta por Dia/Semana e adia carga para SPEC-018. Para SPEC-009. |
| 1.3 | 1.8 | 1.3 | 2026-10-06 | UF-05 explicita que rotina não exige data final e que o alcance “selecionada e futuras” inclui a ocorrência aberta. Para SPEC-008. |
| 1.2 | 1.7 | 1.2 | 2026-10-06 | UF-05 ganha o ramo MOD-014 (resolver sinalização pendente ao editar) e o campo de observação; UF-08 registra a remoção da sinalização ao excluir. Para SPEC-007. |
| 1.1 | 1.5 | 1.1 | 2026-10-05 | 16 fluxos; UF-16 configura fuso; demais fluxos incorporam decisões de acesso, datas, badges, PDF e sorteio local. |
| 1.0 | 1.4 | 1.0 | 2026-10-02 | UF-02/03/04/09/12/14 alinhados à lista integrada em Família e ao detalhe com tarefas do membro; mantido Dia/Semana. |
| 1.0 | 1.3 | 1.0 | 2026-10-02 | Revisão dos fluxos Kids, câmera, perfil, períodos e badges; novos UF-14/15 para PDF e destaque semanal. |
| 1.0 | 1.2 | 1.0 | 2026-10-01 | Primeira elaboração: 13 fluxos com Mermaid, decisões, alternativas, retornos e cobertura dos 17 casos de uso. |
