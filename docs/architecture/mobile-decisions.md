# Decisões consolidadas da arquitetura mobile

**Versão:** 1.2 · **Base funcional:** 1.5\
**Data:** 2026-10-05 · **Situação:** decisões do usuário incorporadas; sem implementação

[Arquitetura](mobile-architecture.md) · [Catálogo](mobile-feature-catalog.md) · [Índice](../DOCUMENTACAO.md)

## 1. Como interpretar

Este registro substitui as propostas e pendências da arquitetura 1.0 pelas decisões discutidas com o usuário. IDs MA/P são preservados para rastreabilidade; P agora identifica resolução, não bloqueio. O escopo é mobile e alinhamento das docs funcionais/design/modelagem. Aspectos explicitamente adiados não são tratados como perguntas obrigatórias.

## 2. Registro de decisões

| ID | Estado | Decisão vigente |
|---|---|---|
| MA-01 | Confirmada | Swift + SwiftUI, View + ViewModel e Clean Architecture |
| MA-02 | Confirmada | Código, arquivos, recursos e identificadores em inglês; texto explicativo/UI em português e localizável |
| MA-03 | Consolidada | Organização por feature com Presentation/Application/Domain/Data e composição em App |
| MA-04 | Consolidada | Um target do app inicialmente, com fronteiras lógicas; testes em targets próprios e packages somente quando necessários |
| MA-05 | Confirmada | iPhone/iPad, iOS/iPadOS 26 mínimo, layout adaptativo; Swift 6, Observation e MainActor |
| MA-06 | Consolidada | Injeção por inicializador e factories, sem service locator |
| MA-07 | Consolidada | Verdade remota; sem banco local de negócio ou gravações offline |
| MA-08 | Confirmada; substitui proposta | Última edição válida persistida vence; sem exigência de versão esperada nem idempotência geral por operationID. Resposta perdida leva à consulta de estado, sem repetição automática de comandos. Invariantes transacionais permanecem |
| MA-09 | Consolidada | NavigationStack por aba, rotas tipadas e contexto preservado |
| MA-10 | Confirmada | Uma sessão ativa por perfil/instalação; acesso 15 minutos, refresh estável sem expiração temporal, ambos sujeitos à sessão revogável; Keychain |
| MA-11 | Consolidada | DTOs separados de domínio e projeções por perfil |
| MA-12 | Confirmada | PDF no aplicativo com snapshot consistente do backend |
| MA-13 | Confirmada | Apuração remota às 00:00 de segunda-feira no fuso da família, APNs e consulta interna; resultado final preservado |
| MA-14 | Confirmada; substitui proposta | Sorteio e animação no app; servidor valida e persiste recompensa aceita; não grava resultados recusados |
| MA-15 | Consolidada | Atualizar ao abrir/retomar, manualmente e após alterações; sem dependência de tempo real |
| MA-16 | Confirmada | Backend único com banco PostgreSQL no Supabase; backend salva fotos no R2 e URL estável no Supabase; acesso privado autenticado |
| MA-17 | Confirmada | Somente desenvolvimento e produção; sem rotina própria de backup do banco; distribuição adiada |

## 3. Resolução das pendências

<a id="p-01"></a>
### P-01 — Fuso e apuração: resolvida

Padrão `America/Sao_Paulo` na criação, podendo escolher outro. Somente Administradores editam em Configurações da família. Informativo permite aplicar imediatamente ou no próximo ciclo. Cancelar não grava. Registrar transição e limites contíguos dos ciclos, identificando duração excepcional sem duplicar apuração. Datas civis das tarefas não são deslocadas. Apuração é elegível às 00:00 de segunda-feira local, com recuperação de falhas independente do app. Resultado já finalizado permanece igual.

<a id="p-02"></a>
### P-02 — Reconhecimento e badges: resolvida

Destaque final é preservado após edição/reabertura, sem nova notificação. Todos os perfis ativos, inclusive Kids, são elegíveis; sem pontos positivos, não há vencedor. Empates reconhecem todos os primeiros.

Participa de uma missão quem foi responsável creditado em uma ou mais tarefas vinculadas quando ela encerrou. Uma participação por pessoa/missão, sem retroatividade para novos membros. Badges cumulativos: bronze 5, prata 10, ouro 25 e diamante 50 missões com participação. Não há selo opcional/administrável por missão. Detalhe do marco lista missões contribuintes. Participação não depende de quem tocou em concluir nem do resgate.

<a id="p-03"></a>
### P-03 — Convites: resolvida

Gerar ou reenviar sempre cria novo link e senha, invalida os anteriores e revoga a sessão anterior no ato da emissão, preservando perfil e histórico. Mostrar efeitos antes de confirmar. Convite não expira por tempo, mas deixa de valer por consumo ou revogação/substituição. Exibir credenciais transitoriamente; guardar verificadores, sem reconstrução de senha a partir de hash.

<a id="p-04"></a>
### P-04 — Datas, rotinas e concluídas: resolvida

DatePicker começa hoje e aceita qualquer data passada/futura, inclusive antes da criação da família e fora do mês corrente. Cadastro/edição e início da rotina não usam limites do carrossel. Consulta permanece da criação da família ao fim do mês atual. Rotina oferece diário ou 1/2/3/4 semanas; backend gera até fim do mês seguinte, repõe diariamente e completa consultas. Início além do horizonte fica programado; início passado é processado sem truncamento silencioso.

Concluída não protegida pode mudar título, peso, data prevista e responsáveis. Crédito/progresso vigentes se ajustam, com auditoria preservada e sem alterar instante original de conclusão. Sem responsáveis, continua concluída e sem crédito individual. Destaques finalizados e PDFs exportados não mudam. Última edição válida do servidor prevalece.

<a id="p-05"></a>
### P-05 — Remoção de membro: resolvida

Retirar só a pessoa removida de tarefas futuras não concluídas/não protegidas; manter os demais. Não aplicar alteração automática a pendências antigas ou a futuras concluídas/protegidas. Preservar histórico e participações, revogando acesso, sessão e fotos.

<a id="p-06"></a>
### P-06 — Perfil, badges e mídia: resolvida nesta etapa

Perfil permite câmera/galeria para todos, inclusive Kids. Sinalização Kids mantém câmera direta. Badges seguem P-02, sem catálogo editável de selos. Backend grava mídia privada no R2 e URL estável no Supabase; app lê pela API autorizada. Não persistir URLs assinadas temporárias como localização permanente. JPEG até lado maior 1.600 pixels/5 MB; uploads abandonados após 24 horas. Retenção das fotos vinculadas foi explicitamente retirada do escopo desta etapa.

<a id="p-07"></a>
### P-07 — Acesso e falhas: resolvida

Uma sessão ativa por perfil, vínculo à instalação comprovado por credencial e não só por ID. Novo acesso Apple substitui sessão anterior. Refresh estável/revogável sem expiração temporal; access token 15 minutos com checagem de sessão em cada operação. Falha de rede não revoga credencial.

Consulta de estado atual substitui a proposta de chave geral de idempotência. Em criação sem resultado identificável, informar incerteza e não reenviar automaticamente. Recuperação do ingresso perdido é específica, por dez minutos e mediante prova da tentativa/instalação original; não é segundo consumo nem recuperação pública por ID.

Convite com sessão ativa pede confirmação; cancelar/falhar mantém o acesso local anterior, sucesso limpa e substitui o contexto. Não remove o membro antigo nem migra histórico. Sem app, direcionar à loja e orientar tocar no link novamente após instalar. Domínio/AASA são configuração de implantação, sem exigir decisão de produto nesta etapa.

<a id="p-08"></a>
### P-08 — Notificação: resolvida

Fila persistente registra intenção única por reconhecimento/destinatário e worker recupera falhas de envio. Estados distinguem aguardando, aceitação pelo APNs e falha; abertura é evento separado. Aceitação não prova entrega/leitura. Sem push o resultado permanece acessível. Não há garantia de entrega externa exatamente uma vez.

<a id="p-09"></a>
### P-09 — Plataforma e qualidade: resolvida nesta etapa

Mínimo 26, iPhone/iPad com layout adaptativo. Fixar toolchain estável ao implementar e usá-lo na CI. Meta inicial aceita: 95% das consultas comuns do servidor até um segundo, a aferir posteriormente. Volumes de teste e distribuição ficam fora desta etapa; não são bloqueios para esta revisão.

## 4. Ajustes de modelagem aplicados

- `CompletionSource` passa a listar `manual`/`kidsConfirmation`; `Completion` consolida autor, beneficiários/peso vigentes, data prevista, instante de conclusão e desfazimento.
- Auditoria de correções preserva valores anteriores; DER distingue conclusão vigente e histórico.
- `MissionParticipation` substitui concessão indistinta por missão. `BadgeAward` é único por membro/marco, sem selo opcional na missão.
- `AppleAuthenticating` retorna prova de autorização, não apenas Apple ID.
- Mídia tem URL estável privada e leitura autorizada, sem acesso público implícito.
- Família possui fuso vigente/programado e ciclos; sessão possui vínculo à instalação; notificações possuem registro de dispositivo e fila.
- Tela Família agrega consultas, com casos de uso separados. Novos destinos detalham configurações e marcos.

## 5. Continuidade com o backend e temas fora do escopo

A plataforma Node.js e a arquitetura backend passam a ser definidas em [backend-architecture.md](backend-architecture.md). Hospedagem do backend, retenção das fotos vinculadas, volumes de teste e distribuição foram explicitamente adiados. O projeto não implementará rotina própria de backup; backups do provedor, se houver, são independentes. Não existe etapa de homologação separada: ambientes são desenvolvimento e produção.

As propostas substituídas (iOS 17, sorteio remoto, controle de versão otimista, operationID geral, badge coletivo por selo e reenvio do mesmo segredo) não devem orientar a implementação.

## Histórico

| Versão | Data | Alteração |
|---|---|---|
| 1.2 | 2026-10-05 | Integração com arquitetura backend 1.0 em Node.js, contratos `/v1`, bootstrap, preparação de rotinas e referências; base funcional 1.5 preservada. |
| 1.1 | 2026-10-05 | Consolidação das respostas do usuário, fechamento de P-01–P-09 e registro de MA-16/17; propostas anteriores substituídas. |
| 1.0 | 2026-10-05 | Propostas e pendências iniciais, anteriores às decisões desta revisão. |
