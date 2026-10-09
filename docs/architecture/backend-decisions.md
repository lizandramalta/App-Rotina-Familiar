# Decisões da arquitetura backend

**Versão:** 1.4 · **Base funcional:** 1.5\
**Data:** 2026-10-09 · **Situação:** fundação técnica da Sprint 0 implementada; referência para entregas incrementais

[Arquitetura](backend-architecture.md) · [Contratos](backend-contracts.md) · [Decisões mobile](mobile-decisions.md) · [Índice](../DOCUMENTACAO.md)

## 1. Como interpretar

“Confirmada” identifica instrução do usuário ou decisão funcional já consolidada. “Proposta técnica adotada no desenho” identifica recomendação feita nesta documentação para tornar a arquitetura concreta. Não exige reabrir pendências funcionais nem sugere que o usuário já escolheu bibliotecas que não mencionou.

Node.js passa a ser a plataforma backend definida pelo usuário. Hospedagem, distribuição, retenção de fotos vinculadas e volumes de teste permanecem fora desta etapa. Todas as convenções técnicas futuras usam inglês, mantendo a explicação documental em português.

## 2. Decisões técnicas

| ID | Estado | Decisão e motivo |
|---|---|---|
| BA-01 | Confirmada | Backend único com Clean Architecture e Node.js, PostgreSQL no Supabase e fotos no R2 |
| BA-02 | Proposta técnica adotada no desenho | TypeScript estrito/ESM e Node.js em LTS suportada; referência Node.js 24 nesta data, patch fixado ao implementar |
| BA-03 | Proposta técnica adotada no desenho | Monólito modular, API e worker do mesmo código/release; separar processamento sem dividir o domínio em microserviços |
| BA-04 | Proposta técnica adotada no desenho | Fastify na borda HTTP com schemas; Domain/Application independentes do framework |
| BA-05 | Proposta técnica adotada no desenho | `pg` com SQL parametrizado, migrations explícitas e transação numa conexão; evita esconder locks e queries agregadas atrás de CRUD genérico |
| BA-06 | Proposta técnica adotada no desenho | PostgreSQL para jobs, leases e outbox; sem broker/cache adicional obrigatório no MVP |
| BA-07 | Confirmada; mecanismo detalhado | Edições por última gravação válida; sem versão esperada nem idempotência geral. Consulta após resposta perdida, sem reenvio automático |
| BA-08 | Proposta técnica adotada no desenho | Escritas curtas serializadas por família, constraints e revalidação no lock; snapshots agregados com leitura consistente |
| BA-09 | Confirmada; mecanismo detalhado | Convite de uso único sem prazo; emissão nova revoga convites/sessão anteriores. Segredos persistidos por verificadores |
| BA-10 | Confirmada; mecanismo detalhado | Um aparelho por perfil, access 15 minutos, refresh estável sem prazo e revogação em cada chamada. Tokens opacos e prova secreta de instalação são mecanismo proposto |
| BA-11 | Confirmada; mecanismo detalhado | Recuperação de ingresso por dez minutos, prova da tentativa/instalação, sem segundo consumo; envelope criptografado temporário é mecanismo proposto |
| BA-12 | Confirmada | Datas livres de cadastro, frequências 1/7/14/21/28, horizonte fim do mês seguinte e recuperação em lotes, sem truncar passado |
| BA-13 | Confirmada; mecanismo detalhado | Fuso IANA, Admin altera agora/próximo ciclo; limites persistidos, apuração à meia-noite local e resultados finalizados preservados |
| BA-14 | Confirmada | Missão conta participação dos creditados em ao menos uma tarefa; marcos cumulativos 5/10/25/50, sem retroatividade ou selo configurável |
| BA-15 | Confirmada | PDF e sorteio/animação locais; backend entrega snapshot e persiste somente o aceite da recompensa |
| BA-16 | Confirmada; mecanismo detalhado | Backend grava foto R2 e URL privada estável no banco; leitura pelo backend, com finalidade/titularidade; limpeza de uploads nunca vinculados após 24h |
| BA-17 | Confirmada; mecanismo detalhado | Intenção de notificação persistente com resultado; distinguir aceitação APNs de entrega/leitura |
| BA-18 | Confirmada | Apenas desenvolvimento e produção; sem rotina própria de backup do banco |
| BA-19 | Proposta técnica adotada no desenho | Supabase só como PostgreSQL gerenciado; sessão própria, schema privado/Data API desabilitada, sem dependência de Auth/Storage/Realtime/Edge Functions |
| BA-20 | Proposta técnica adotada no desenho | API `/v1`, schemas em inglês, DTO por permissão e erros estáveis; contrato HTTP separado das entidades |
| BA-21 | Confirmada (`SPEC-001`) | `creationGrant` emitido por `SignInWithApple` quando a identidade não tem família expira em 10 minutos; grant expirado exige nova autenticação Apple |

## 3. Alternativas consideradas

| Tema | Escolha do desenho | Alternativa e consequência |
|---|---|---|
| Framework | Fastify com composição explícita | NestJS também suportaria Clean Architecture, mas exigiria manter decorators/DI fora do domínio. Express exigiria compor validação/serialização separadamente |
| Banco | `pg` e SQL encapsulado | ORM pode ser adotado como adaptador se preservar transações, índices parciais, locks e queries consistentes; não muda Domain/Application |
| Sessão | Própria, revogada no servidor | Supabase Auth exigiria validar sua aderência às regras de refresh estável, convite próprio e um aparelho; não é pressuposto desta arquitetura |
| Jobs | Fila/outbox PostgreSQL | Broker externo adicionaria operação e coordenação; avaliar somente diante de volume/isolamento medidos |
| Concorrência | Lock por família em comandos curtos | Locks por agregado podem aumentar paralelismo depois, exigindo ordem rigorosa entre tarefa, missão, membro e apuração |
| Mídia | Upload/download pelo backend | Upload direto e URLs assinadas mudariam o fluxo aceito e o comportamento de revogação; não adotados |
| Estado do cliente | Consulta após falha | Replay geral por idempotency key e rejeição por versão foram substituídos pelas decisões anteriores; não reintroduzir |
| Deploy | Uma aplicação com API/worker | Microserviços não são necessários para as fronteiras do domínio; fornecedor de hospedagem será definido separadamente |

## 4. Detalhamentos de implementação derivados

Estas definições tornam os fluxos implementáveis sem acrescentar novas jornadas:

- O Criador autenticado sem família usa grant temporário restrito; não recebe sessão de um perfil ainda inexistente.
- Vários access tokens ainda válidos podem pertencer à mesma sessão; renovar não cria outro aparelho e revogar a sessão invalida todos.
- Troca confirmada pode encerrar a sessão local anterior no commit do ingresso, preservando seu perfil/família; falha antes do commit não toca esse acesso.
- `signalId` vincula decisão à sinalização correta; decisão antiga não confirma uma tentativa Kids nova.
- Correção de concluída mantém o instante original e atualiza crédito vigente com auditoria. Apuração finalizada e PDF já exportado são snapshots.
- “Futuras” na remoção automática de membro significa data posterior a hoje no fuso familiar; passado e dia atual não ganham regra de limpeza. Responsáveis padrão de rotina também são ajustados para novas ocorrências.
- Materialização grande tem cursor/versão e estado de preparação consultável; não oculta trabalho incompleto em totais apresentados como finais.
- Marcação de origem/tombstones impede regenerar ocorrência movida ou excluída. Reconfigurar rotina é distinto de simplesmente materializar o horizonte.
- Mudanças programadas de fuso são substituíveis pela última solicitação válida, com auditoria. Job atrasado registra a finalização real e nunca reapura resultado final.
- Detalhe do marco mantém as primeiras N participações que o fundamentaram, em ordem determinística, em vez de passar a listar indefinidamente novas missões.
- Upload é reservado antes de gravar R2, só fica utilizável após confirmação e só é vinculado por comando autorizado. Fotos historicamente vinculadas não são tratadas como uploads abandonados.

Esses detalhes são decisões técnicas da arquitetura. Os IDs funcionais permanecem os mesmos; o catálogo liga cada contrato ao UC correspondente.

## 4.1. Decisões de implementação da SPEC-004 (emissão de convite)

Escolhas técnicas tomadas ao implementar o SCRUM-30, aprovadas em chat em 2026-10-09. Nenhuma altera comportamento, permissão ou estado da base funcional.

| # | Decisão | Por quê |
|---|---|---|
| BA-22 | Senha do convite com **6 caracteres** de um alfabeto de 32 símbolos sem ambíguos (sem `0/O/1/I`), sorteados com `crypto.randomInt`. Persistida só como verificador **scrypt** com sal próprio (`scrypt$v1$N$r$p$salt$hash`, N=2^15, r=8, p=1). | O tamanho foi escolhido pelo usuário para facilitar a digitação por quem recebe. São apenas 30 bits de entropia, então a proteção não vem da senha: vem do verificador lento (contra vazamento do banco) e do limite de tentativas no ingresso (BA-23). O link carrega 256 bits independentes; conhecer um não revela o outro. Os parâmetros são versionados no próprio verificador para permitir evolução sem migration. |
| BA-23 | `429 RATE_LIMITED` **não** é implementado em `IssueMemberInvite` neste card. | A SPEC lista o código, mas não fixa limites e o backend não tem mecanismo de rate limit. Inventar valores seria decidir contrato por conta própria. A emissão já exige sessão de Administrador e serializa por família. **Pendência:** o limite de tentativas de senha é obrigatório no ingresso (SPEC-005/SCRUM-32), pois é ele que compensa a senha curta de BA-22; a emissão deve ser coberta por um card transversal. |
| BA-24 | O link é `<INVITE_LINK_BASE_URL>/invite/<token>`. A variável tem como padrão o domínio reservado `https://example.invalid` e é **recusada em produção** se terminar em `.invalid`. | O domínio real (universal link) ainda não existe. O padrão `.invalid` (RFC 2606) nunca resolve, então não vaza para um endereço real em dev/test, e a validação no boot impede subir produção emitindo convites inúteis. |
| BA-25 | Perfil removido: **sem tratamento neste card**. Não foi criada coluna de remoção em `app.members`. | A remoção pertence ao recorte de SPEC-003 ainda sem card. Antecipar a coluna decidiria o modelo de remoção fora do seu escopo. O `404` para removido (SPEC-004 CA-04) deve ser entregue junto com a remoção, que precisa filtrar o alvo em `findTarget`. |
| BA-26 | Emitir convite para **o próprio ator** responde `409 INVITE_NOT_ISSUABLE`. | A SPEC fala em emitir para "outro perfil" e a emissão revoga a sessão do alvo; se o alvo fosse o ator, o Administrador encerraria a própria sessão. O Criador já é inelegível, então a regra só alcança Administradores não-Criadores. |
| BA-27 | Eventos `member_invite_issued`, `member_invite_issue_denied` e `member_invite_issue_uncertain` são **logs estruturados**, sem tabela de auditoria. | Não existe infraestrutura de auditoria e a SPEC define só os campos permitidos. Logs cobrem a necessidade sem criar um modelo de dados novo. Token, senha, link e verificadores nunca são registrados. |
| BA-28 | O hash scrypt é calculado **antes** de adquirir o lock da família; a transação revalida ator, sessão e alvo depois dele. | O scrypt consome CPU e memória por dezenas de milissegundos. Segurar o lock durante o cálculo serializaria todas as escritas da família (backend-architecture.md §7). |

## 4.2. Decisões de implementação da SPEC-005 (ingresso por convite)

Escolhas técnicas tomadas ao implementar o SCRUM-32, aprovadas em chat em 2026-10-09. Nenhuma altera comportamento, permissão ou estado da base funcional; os valores de limite são configuração validada, não regra de produto.

| # | Decisão | Por quê |
|---|---|---|
| BA-29 | Limite de tentativas em **PostgreSQL** (`app.invite_attempt_log`), sem Redis: por convite, **5 tentativas de ingresso por 15 min**; por origem, **30 requisições por 15 min** somando inspeção, ingresso e recuperação. Valores em `INVITE_ATTEMPT_LIMIT`, `INVITE_ORIGIN_ATTEMPT_LIMIT` e `INVITE_ATTEMPT_WINDOW_MINUTES`. O registro e a contagem ocorrem sob lock consultivo por sujeito, fora da transação do ingresso. | A senha de BA-22 tem 30 bits; este limite é o que a protege (pendência de BA-23). A SPEC exige `429` sem fixar números, e os valores são propostas desta implementação. O lock consultivo impede que uma rajada simultânea leia a mesma contagem e passe inteira. Fora da transação, a tentativa recusada continua contada mesmo com rollback. O identificador é um hash; token e IP nunca são gravados em claro. |
| BA-30 | `TRUST_PROXY` (padrão `false`) controla o `trustProxy` do Fastify; a origem do limite é `request.ip`. | Sem proxy confiável, `X-Forwarded-For` é forjável e contornaria o limite por origem. Hospedagem segue fora da etapa; atrás de proxy, o operador liga a variável. O limite por convite não depende de IP e permanece a defesa principal. |
| BA-31 | Ingresso: senha conferida (scrypt) **antes** do lock; dentro de `forFamily` o convite é relido `FOR UPDATE`, com perfil e flag de Criador, e o commit único consome o convite, revoga sessões do perfil, abre a sessão, grava o envelope e, na troca confirmada, encerra a sessão anterior, seus access tokens e dispositivos push. | Mesmo critério de BA-28 (scrypt custoso não segura lock). A revalidação sob lock é o que faz a segunda tentativa concorrente receber `INVITE_UNAVAILABLE` (CA-05); o índice parcial de uma sessão ativa por perfil é a defesa final. |
| BA-32 | Envelope de recuperação em `app.invite_join_recoveries`: AES-256-GCM com chave derivada de `INVITE_ENVELOPE_KEY`, `attemptId` como dado autenticado, validade de 10 min desde o commit conferida a cada recuperação. Guarda só hashes do segredo da tentativa e da prova de instalação. O envelope expirado é removido na própria tentativa de recuperação **e** a cada ingresso confirmado (varredura dos vencidos no mesmo commit), de modo que credenciais cifradas não sobrevivam à janela mesmo sem recuperação; o job `CleanExpiredAccessArtifacts` fica para depois. | BA-11 pede criptografia autenticada com chave fora do banco. O `attemptId` como AAD impede copiar um envelope para outra tentativa. A senha do convite nunca entra no envelope. |
| BA-33 | Falha de dependência no ingresso responde `JOIN_RESULT_UNCERTAIN` somente depois de iniciado o commit; antes dele, `DEPENDENCY_UNAVAILABLE`. Inspeção e recuperação usam `DEPENDENCY_UNAVAILABLE`. `429` envia `Retry-After` com a janela inteira. Credencial anterior malformada ou inválida responde `401 SESSION_INVALID` em vez de ser ignorada. | Distingue "nada foi gravado" de "pode ter sido gravado" sem afirmar rollback. Ignorar um Bearer malformado trocaria o acesso sem a pessoa saber. |
| BA-34 | **Perfil removido: sem tratamento neste card** (continuidade de BA-25). Hoje, remover o membro apaga a linha e o convite cai por `ON DELETE CASCADE`, resultando em `INVITE_UNAVAILABLE`. | A remoção com preservação de histórico pertence à SPEC-003 e ainda não existe. Quando houver coluna de remoção, ela deve invalidar convites e `lockInviteForJoin` deve filtrá-la. |

## 5. Limites e continuidade

A Sprint 0 criou o servidor Fastify, a configuração validada, o schema privado `app`, migrations e as verificações de CI. Ela não cria recursos Supabase/R2 gerenciados, credenciais, publicação, endpoints de produto, sessões ou jobs de domínio; esses itens continuam orientados por esta documentação e pelas SPECs aprovadas.

Hospedagem/domínio, patches exatos de bibliotecas, parâmetros operacionais de pool/retry, retenção de fotos vinculadas, distribuição e volumes de testes não bloqueiam a arquitetura. Valores operacionais serão configuração validada, sem alterar os comportamentos de produto. Escolhas de implementação que alterem permissões, datas livres, refresh sem prazo, retenção, sorteio local ou snapshot de destaque exigem revisar explicitamente a base funcional.

Sequência sugerida: composição e persistência → Apple/bootstrap/sessões/convites → família/perfis → tarefas/rotinas/indicadores → Kids/mídia → missões/badges/resgate → relatório/ciclos/APNs. Entregar cada conjunto com autorização e integridade, não adiar esses aspectos para uma camada posterior.

## Histórico

| Versão | Data | Alteração |
|---|---|---|
| 1.4 | 2026-10-09 | BA-29–BA-34: decisões de implementação do ingresso por convite (SPEC-005 Fase 1), com limites de tentativas, envelope de recuperação e tratamento de falhas. Sem mudança funcional. |
| 1.3 | 2026-10-09 | BA-22–BA-28: decisões de implementação da emissão de convite (SPEC-004 Fase 1), com justificativas. Sem mudança funcional. |
| 1.2 | 2026-10-08 | Registra a fundação backend da Sprint 0 sem alterar decisões funcionais ou introduzir capacidades de produto. |
| 1.1 | 2026-10-06 | BA-21: confirma em 10 minutos o prazo técnico do `creationGrant` proposto em `backend-architecture.md` §8, decidido na aprovação de `SPEC-001`. |
| 1.0 | 2026-10-05 | BA-01–BA-20, distinção entre decisões confirmadas e propostas técnicas, alternativas e detalhes derivados. |
