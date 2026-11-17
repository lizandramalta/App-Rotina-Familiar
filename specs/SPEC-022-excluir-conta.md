# Spec 022: Excluir conta

**Status:** em implementação (fases 1–3: backend concluído; mobile em andamento)\
**Autor:** Claude | **Criada em:** 2026-11-16 | **Aprovada por:** Pessoa usuária | **Em:** 2026-11-17\
**Base funcional:** RN 1.28 / RF 1.27 / UC 1.27\
**UX-spec:** [UX-022-excluir-conta.md](UX-022-excluir-conta.md)\
**Projetos envolvidos:** ambos\
**Tema do backlog:** Tema 1 - Acesso, família e perfis

## 1. Contexto e objetivo

- **Problema / necessidade:** o aplicativo será enviado à App Store. A diretriz 5.1.1(v) exige que todo app que permite criar conta também permita iniciar a exclusão dessa conta dentro do próprio app, e apps que usam Sign in with Apple devem revogar os tokens da Apple ao excluir a conta do usuário. A base funcional não previa exclusão de conta e protegia o Criador contra saída da família (RN05). A falta dessa capacidade bloqueia a publicação pública, mas não o TestFlight.
- **Objetivo da entrega:** permitir que cada perfil exclua a própria conta pelo Meu perfil, que o Criador exclua a conta e a família inteira com revogação dos tokens Apple e que um Administrador exclua a conta de um perfil Kids, apagando os dados pessoais de forma imediata e irreversível e preservando o histórico familiar sem identificação pessoal.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Casos de uso | UC20 (principal), UC02, UC04, UC10 |
| Regras de negócio | RN05, RN07, RN10, RN30, RN31, RN44, RN47, RN61, RN62, RN69, RN70 |
| Requisitos funcionais | RF04, RF37, RF39, RF72, RF73, RF74 |
| Requisitos não funcionais | RNF06, RNF07, RNF09, RNF12, RNF13, RNF15, RNF16, RNF22, RNF24, RNF28 |
| Telas e fluxos de navegação | TEL-001, TEL-030, TEL-032, TEL-058, MOD-015, UF-17 |
| Decisões arquiteturais aplicáveis | BA-01, BA-04, BA-07, BA-08, BA-09, BA-40, MA-08, MA-22 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/design/screen-map.md`, `docs/architecture/backend-contracts.md`, `docs/architecture/backend-decisions.md`, `backend/docs/apple-integration-setup.md`, `specs/SPEC-001-autenticar-com-apple.md`, `specs/SPEC-003-gerenciar-membros.md`.
- **Depende de (specs pré-requisito):** SPEC-001 Fase 4 (login Apple passa a guardar o refresh token — ver E-05 e SPEC-001 CA-12 a CA-15), SPEC-003 (remoção lógica e seus efeitos, RN10), SPEC-006 (TEL-030), SPEC-012/SPEC-013 (fotos de sinalização Kids).
- **Dependências externas e infraestrutura:** Sign in with Apple (troca de `authorizationCode` e `POST https://appleid.apple.com/auth/revoke`), Cloudflare R2 (apagamento de objetos), Supabase/PostgreSQL.

## 3. Escopo da entrega

### 3.1. Dentro do escopo

- Exclusão da própria conta por Administrador não-Criador, Membro e Kids, iniciada em TEL-030 (RN69, RF72).
- Exclusão da conta do Criador, que exclui a família inteira: todos os perfis, tarefas, rotinas, missões, recompensas, conquistas, destaques, mensagens, convites, sessões e mídias da família, além da identidade Apple (RN70, RF73).
- Guarda do refresh token Apple, cifrado, a cada login Apple bem-sucedido do Criador, e revogação desse token na exclusão; sem token guardado, nova autenticação Apple no momento da exclusão (RN44, RF37, RF39, RF73).
- Exclusão da conta de um perfil Kids por Administrador da mesma família, em TEL-032 (RN07, RF74).
- Anonimização do perfil excluído (não-Criador): nome, apelido e foto apagados; conclusões, créditos, participações, badges, destaques e parabéns preservados e apresentados como "Membro removido" (RN10, RN30, RN31, RN61, RN62).
- Apagamento dos arquivos de foto de perfil e de sinalização Kids do titular no R2; a sinalização permanece registrada sem foto.
- Mensagem neutra de acesso encerrado quando uma sessão revogada leva o app de volta à entrada (UX-022).

### 3.2. Fora do escopo

- Transferência do papel de Criador para outro Administrador: exigiria rever RN44/RF37/RF39, porque o novo Criador não teria identidade Apple vinculada.
- Exportação dos dados antes da exclusão.
- Período de carência, restauração ou desfazer.
- Exclusão por site, e-mail ou suporte fora do aplicativo.
- Política de privacidade e sua URL no App Store Connect: necessárias para a publicação, mas tratadas em outra entrega; devem refletir a seção 8 desta spec.
- Exclusão de identidade Apple sem família (onboarding abandonado): não há sessão familiar que permita a ação; o `creationGrant` e a mídia de onboarding seguem a limpeza já existente.

### 3.3. Fora de questão

- Não há exclusão parcial: a conta excluída perde perfil, acesso e dados pessoais na mesma operação.
- Não recalcular cargas, progresso, missões concluídas, participações, badges, relatórios ou destaques já registrados por causa da exclusão de um perfil não-Criador.
- Não enviar push nem mensagem interna aos demais membros sobre a exclusão.
- A autoexclusão nunca aceita `memberId`, `familyId` ou papel vindos do cliente; o alvo é sempre o titular da sessão.
- Administrador não exclui a conta de outro adulto; ele continua podendo removê-lo por RN10.
- Perfil excluído não é recuperável por convite; voltar à família exige um novo perfil criado por Administrador.
- A falha da revogação na Apple não impede nem desfaz a exclusão.
- O servidor não recebe nem valida o nome da família digitado na confirmação do Criador; essa verificação é exclusiva da interface (UX-022).

## 4. Perfis, atores e regras de autorização

| Perfil / situação | Pode | Não pode | Reação a tentativa não autorizada |
|---|---|---|---|
| Administrador não-Criador | Excluir a própria conta; excluir a conta de um Kids da própria família | Excluir a conta de outro adulto; excluir a família | `403 ACTION_NOT_ALLOWED`; ação oculta |
| Criador | Excluir a própria conta, o que exclui a família inteira; excluir a conta de um Kids | Excluir a própria conta sem token Apple guardado e sem prova Apple nova | `422 APPLE_PROOF_REQUIRED` |
| Membro | Excluir a própria conta | Excluir a conta de qualquer outro perfil | `403 ACTION_NOT_ALLOWED`; ação oculta |
| Kids | Excluir a própria conta | Excluir a conta de qualquer outro perfil | `403 ACTION_NOT_ALLOWED`; sem entrada visual |
| Recurso de outra família | — | Ser excluído | `404 RESOURCE_NOT_FOUND`, sem revelar existência |

- **Isolamento familiar (RNF06):** a família e o titular derivam da sessão ativa. No caminho administrativo, `memberId` é resolvido no escopo da família do ator; alvo de outra família, inexistente, removido ou já excluído é indistinguível e responde `404 RESOURCE_NOT_FOUND`.
- **Autorização (RNF07):** o backend valida sessão ativa, perfil ativo, papel e alvo antes da escrita e novamente após obter o lock.
- **Revogação (RN47, RNF22):** a exclusão revoga, no mesmo commit, todas as sessões, tokens de acesso, refresh tokens, dispositivos de push e convites disponíveis dos perfis afetados.

## 5. Contrato de dados, interface e validações

### 5.1. Dicionário de campos

| Campo JSON | Tipo | Obrigatório | Validação | Erro |
|---|---|---:|---|---|
| `apple.identityToken` | string (JWT) | Somente para o Criador sem token Apple guardado | Mesma validação de `POST /v1/access/apple` (assinatura, emissor, audiência, validade); `sub` deve corresponder à identidade Apple da família | `401 APPLE_PROOF_INVALID` |
| `apple.authorizationCode` | string | Junto com `apple.identityToken` | Trocado com a Apple antes do commit; `sub` da troca deve coincidir com o do `identityToken` | `401 APPLE_PROOF_INVALID` |
| `apple.rawNonce` | string | Junto com `apple.identityToken` | Deve corresponder ao hash do `nonce` presente em `identityToken`, como em SPEC-001 §5.1; impede reaproveitar uma prova anterior | `401 APPLE_PROOF_INVALID` |
| `memberId` | UUID de rota | Sim no caminho administrativo | Perfil Kids ativo da família da sessão | `404 RESOURCE_NOT_FOUND`, `403 ACTION_NOT_ALLOWED` |

Corpo vazio é aceito para quem não é Criador e para o Criador com token Apple guardado. Campos desconhecidos ou protegidos (`memberId`, `familyId`, `role`, `isFamilyCreator`, `familyName`) no corpo recebem `400 UNKNOWN_FIELD`. Credenciais e provas Apple nunca são registradas em logs.

### 5.2. Endpoints

Todas as rotas usam `/v1`, HTTPS, JSON em inglês, `Authorization: Bearer <accessToken>` e a prova de instalação exigida pelo contrato de sessão.

| Método e rota | Caso de uso | Acesso | Entrada | Resultado confirmado |
|---|---|---|---|---|
| `POST /me/account-deletion` | `DeleteOwnAccount` | Qualquer perfil ativo | Corpo vazio ou `{ "apple": { "identityToken", "authorizationCode", "rawNonce" } }` | `204 No Content` após a exclusão confirmada; nenhuma sessão do titular permanece válida |
| `POST /family/members/{memberId}/account-deletion` | `DeleteKidsAccount` | Administrador; alvo Kids da mesma família | Sem corpo | `204 No Content` após a exclusão confirmada |
| `POST /access/apple` (alterado) | `SignInWithApple` | Prova Apple válida | Inalterada | Inalterado para o cliente; passa a guardar, cifrado, o refresh token Apple devolvido na troca do código |

Exemplo para o Criador sem token Apple guardado:

```json
{
  "apple": {
    "identityToken": "eyJraWQiOi...",
    "authorizationCode": "c1a2b3...",
    "rawNonce": "<nonce gerado pelo app>"
  }
}
```

### 5.3. Erros, concorrência e falhas

| HTTP | Código | Situação |
|---:|---|---|
| 400 | `UNKNOWN_FIELD` | Campo não reconhecido ou protegido |
| 401 | `SESSION_EXPIRED` | Access token ausente, inválido ou expirado (convenção de SPEC-001) |
| 401 | `SESSION_REVOKED` | Sessão revogada, inclusive pela própria exclusão ou pela exclusão da família |
| 401 | `APPLE_PROOF_INVALID` | Prova Apple inválida, troca recusada ou `sub` diferente da identidade Apple da família; resposta genérica, como em SPEC-001 |
| 403 | `ACTION_NOT_ALLOWED` | Ator sem permissão no caminho administrativo ou alvo adulto |
| 404 | `RESOURCE_NOT_FOUND` | Alvo inexistente, removido, excluído ou de outra família |
| 422 | `APPLE_PROOF_REQUIRED` | Criador sem token Apple guardado e sem prova Apple no corpo |
| 503 | `DEPENDENCY_UNAVAILABLE` | Persistência indisponível; não afirmar reversão de escrita incerta |

- **Concorrência:** a exclusão usa transação curta com lock por família (BA-07, BA-08) e revalida o estado do alvo após o lock. Remoção administrativa e exclusão simultâneas do mesmo perfil produzem um único efeito; a segunda operação recebe `404 RESOURCE_NOT_FOUND` (caminho administrativo) ou `401 SESSION_REVOKED` (própria sessão já revogada). Operações de outros membros sobre a família excluída pelo Criador, iniciadas depois do commit, recebem `401 SESSION_REVOKED`, ou `SESSION_EXPIRED` quando o access token já não é reconhecido.
- **Prova Apple:** a troca do `authorizationCode` ocorre antes da transação; falha de rede ou recusa responde `401 APPLE_PROOF_INVALID` e nada é excluído.
- **Revogação Apple (BA-40):** após o commit, o backend tenta `auth/revoke` com o refresh token (guardado ou obtido na troca). Falha da tentativa imediata registra uma intenção em fila persistente com retentativas e atraso crescente, com limites configuráveis. O token cifrado existe somente nessa fila até sucesso ou esgotamento das tentativas e então é apagado. A falha não desfaz a exclusão nem altera a resposta `204`.
- **Mídias:** no commit da exclusão de perfil, as mídias do titular passam a `DELETING`; um worker apaga os objetos no R2 depois do commit e marca `DELETED`. Na exclusão da família, as chaves dos objetos são registradas em fila persistente de limpeza no mesmo commit que apaga os registros, sem chamada ao R2 dentro da transação.
- **Resposta perdida (RNF12):** o app não reenvia a exclusão automaticamente. Consulta `GET /me/session`: `401` significa exclusão concluída (o app limpa credenciais locais e mostra o sucesso); `200` significa que a conta continua ativa e permite nova tentativa explícita.

## 6. Estados de domínio e transições

| Estado de | Evento | Estado para | Autor | Garantias |
|---|---|---|---|---|
| Perfil ativo não-Criador | Excluir a própria conta | Perfil excluído | Próprio titular | Sessões, push e convites revogados; nome, apelido e foto apagados; histórico preservado como "Membro removido"; responsabilidades futuras elegíveis ajustadas como em RN10 |
| Perfil Kids ativo | Excluir conta pelo Administrador | Perfil excluído | Administrador da família | Mesmos efeitos da linha anterior |
| Família ativa | Criador exclui a própria conta | Família inexistente | Criador | Todos os registros da família e a identidade Apple apagados fisicamente no mesmo commit; todas as sessões da família deixam de valer; revogação Apple e limpeza do R2 após o commit |
| Perfil removido (RN10) | Excluir conta | — | — | Não se aplica: perfil removido não tem sessão; o caminho administrativo responde `404` |

Um perfil excluído mantém somente o registro técnico necessário às referências históricas, sem nome, apelido, foto ou credencial. Ele não pode receber convite, responsabilidade, parabéns ou destaque novo.

## 7. Critérios de aceitação

- **CA-01: Exclusão da própria conta por adulto não-Criador**
  - **DADO QUE** um Administrador não-Criador ou Membro ativo tem sessão válida,
  - **QUANDO** enviar `POST /v1/me/account-deletion` sem corpo,
  - **ENTÃO O SISTEMA DEVE** responder `204` e marcar o perfil como excluído,
  - **E** revogar no mesmo commit todas as sessões, tokens, dispositivos de push e convites disponíveis do perfil. *(Origem: UC20, RN69, RF72, RN47, RNF22)*

- **CA-02: Anonimização e histórico preservado**
  - **DADO QUE** o perfil excluído tinha conclusões, créditos, participações, badges, destaques e parabéns,
  - **QUANDO** a exclusão for confirmada,
  - **ENTÃO O SISTEMA DEVE** apagar nome, apelido e foto do perfil,
  - **E** manter os registros históricos, apresentados como "Membro removido" em carga, relatório e demais consultas, sem recalcular valores já registrados. *(Origem: RN10, RN30, RN31, RN61, RN62, RN69)*

- **CA-03: Responsabilidades futuras**
  - **DADO QUE** o perfil excluído é responsável por tarefas futuras não concluídas e não protegidas e por tarefas antigas pendentes,
  - **QUANDO** a exclusão for confirmada,
  - **ENTÃO O SISTEMA DEVE** retirar somente esse perfil dos responsáveis das tarefas futuras não concluídas e não protegidas,
  - **E** não alterar tarefas antigas pendentes, concluídas ou protegidas. *(Origem: RN10, RF04)*

- **CA-04: Apagamento de mídias do titular**
  - **DADO QUE** o perfil excluído tem foto de perfil e fotos de sinalização Kids,
  - **QUANDO** a exclusão for confirmada,
  - **ENTÃO O SISTEMA DEVE** marcar essas mídias como `DELETING` no commit e apagar os objetos do R2 depois dele, marcando `DELETED`,
  - **E** manter as sinalizações registradas sem foto. *(Origem: RN69, RNF24, RNF28)*

- **CA-05: Kids exclui a própria conta**
  - **DADO QUE** um perfil Kids ativo tem sessão válida,
  - **QUANDO** enviar `POST /v1/me/account-deletion` sem corpo,
  - **ENTÃO O SISTEMA DEVE** aplicar os mesmos efeitos de CA-01 a CA-04,
  - **E** responder `204`. *(Origem: RN69, RF72)*

- **CA-06: Campos protegidos e isolamento**
  - **DADO QUE** o corpo da autoexclusão contém `memberId`, `familyId`, `role` ou outro campo não previsto,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** responder `400 UNKNOWN_FIELD` sem excluir nada,
  - **E** nunca usar dado do cliente para escolher o alvo. *(Origem: RNF06, RNF07)*

- **CA-07: Sessão inválida**
  - **DADO QUE** a sessão foi revogada ou o token expirou sem renovação,
  - **QUANDO** a exclusão for solicitada,
  - **ENTÃO O SISTEMA DEVE** responder `401 SESSION_REVOKED` ou `401 SESSION_EXPIRED`, conforme SPEC-001,
  - **E** não alterar dados. *(Origem: RNF22)*

- **CA-08: Resposta perdida**
  - **DADO QUE** o app enviou a exclusão e não recebeu resposta,
  - **QUANDO** consultar `GET /v1/me/session`,
  - **ENTÃO O APP DEVE** tratar `401` como exclusão concluída, limpando as credenciais locais e mostrando o sucesso,
  - **E** tratar `200` como conta ativa, permitindo nova tentativa explícita sem reenvio automático. *(Origem: RNF12, MA-08)*

- **CA-09: Retorno à entrada após a exclusão**
  - **DADO QUE** a exclusão foi confirmada pelo servidor,
  - **QUANDO** o app receber `204`,
  - **ENTÃO O APP DEVE** apagar refresh token e dados locais da sessão,
  - **E** abrir TEL-001 com a confirmação de conta excluída. *(Origem: UC20, UX-022)*

- **CA-10: Criador sem token Apple guardado e sem prova**
  - **DADO QUE** o Criador não possui refresh token Apple guardado,
  - **QUANDO** enviar `POST /v1/me/account-deletion` sem `apple`,
  - **ENTÃO O SISTEMA DEVE** responder `422 APPLE_PROOF_REQUIRED`,
  - **E** não excluir nada. *(Origem: RN70, RF73)*

- **CA-11: Prova Apple inválida ou de outra identidade**
  - **DADO QUE** o Criador envia prova Apple cujo `sub` não corresponde à identidade da família, cujo `rawNonce` não corresponde ao `nonce` do `identityToken`, ou cuja troca é recusada,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** responder `401 APPLE_PROOF_INVALID`,
  - **E** não excluir nada. *(Origem: RNF15, RNF16, RF73)*

- **CA-12: Exclusão da família pelo Criador**
  - **DADO QUE** o Criador tem token Apple guardado ou envia prova Apple válida,
  - **QUANDO** a exclusão for processada,
  - **ENTÃO O SISTEMA DEVE** apagar fisicamente, no mesmo commit, a família, todos os perfis e dados familiares e a identidade Apple, registrando as chaves R2 em fila de limpeza,
  - **E** fazer com que toda sessão da família responda `401` (`SESSION_REVOKED` ou `SESSION_EXPIRED`) a partir do commit. *(Origem: RN05, RN70, RF73)*

- **CA-13: Revogação Apple**
  - **DADO QUE** a família foi excluída,
  - **QUANDO** o backend tentar `auth/revoke` com o refresh token,
  - **ENTÃO O SISTEMA DEVE** apagar o token cifrado após sucesso,
  - **E**, em falha, manter a intenção em fila persistente com retentativas até sucesso ou esgotamento, apagando o token ao final, sem desfazer a exclusão. *(Origem: RN44, RF73, RNF28, BA-40)*

- **CA-14: Pré-requisito — guarda do token Apple no login**
  - **DADO QUE** a Fase 2 desta spec depende do refresh token Apple guardado no login,
  - **QUANDO** a Fase 2 for iniciada,
  - **ENTÃO** SPEC-001 Fase 4 (CA-12 a CA-15: guarda, substituição, ausência na resposta da Apple, limpeza de identidade sem família e sigilo) DEVE estar concluída ou ser entregue junto,
  - **E** esta spec não duplica esses critérios. *(Origem: RN44, RF37, RNF16, SPEC-001 E-11/E-12)*

- **CA-15: Nova família com a mesma Apple ID**
  - **DADO QUE** a família de um Criador foi excluída,
  - **QUANDO** a mesma Apple ID autenticar em `POST /v1/access/apple`,
  - **ENTÃO O SISTEMA DEVE** tratá-la como identidade sem família e encaminhar ao onboarding,
  - **E** não expor dados da família excluída. *(Origem: RN44, RN70, UC04)*

- **CA-16: Administrador exclui conta Kids**
  - **DADO QUE** um Administrador ativo seleciona um perfil Kids ativo da própria família,
  - **QUANDO** enviar `POST /v1/family/members/{memberId}/account-deletion`,
  - **ENTÃO O SISTEMA DEVE** aplicar ao Kids os efeitos de CA-01 a CA-04,
  - **E** responder `204`. *(Origem: RN07, RF74)*

- **CA-17: Caminho administrativo sem permissão**
  - **DADO QUE** o ator é Membro ou Kids, ou o alvo é um adulto,
  - **QUANDO** enviar `POST /v1/family/members/{memberId}/account-deletion`,
  - **ENTÃO O SISTEMA DEVE** responder `403 ACTION_NOT_ALLOWED`,
  - **E** não alterar dados. *(Origem: RNF07, RF74)*

- **CA-18: Caminho administrativo com alvo de outra família**
  - **DADO QUE** o `memberId` pertence a outra família, não existe ou já foi removido ou excluído,
  - **QUANDO** um Administrador solicitar a exclusão,
  - **ENTÃO O SISTEMA DEVE** responder `404 RESOURCE_NOT_FOUND`,
  - **E** não revelar dado ou metadado do alvo. *(Origem: RNF06)*

- **CA-19: Concorrência com remoção**
  - **DADO QUE** um Administrador remove um perfil enquanto ele exclui a própria conta,
  - **QUANDO** as duas operações forem processadas,
  - **ENTÃO O SISTEMA DEVE** aplicar somente a primeira a obter o lock,
  - **E** responder à segunda com `404 RESOURCE_NOT_FOUND` ou `401 SESSION_REVOKED`, sem estado parcial. *(Origem: RNF11, BA-08)*

- **CA-20: Acesso encerrado em outro aparelho**
  - **DADO QUE** um perfil teve a conta excluída por Administrador ou pertencia à família excluída,
  - **QUANDO** seu app receber `401` na renovação da sessão,
  - **ENTÃO O APP DEVE** limpar as credenciais locais e abrir TEL-001,
  - **E** mostrar a mensagem neutra de acesso encerrado, sem push. *(Origem: UC20, UX-022)*

### Checklist de cobertura obrigatória dos CAs

- [x] Fluxo principal de cada UC coberto (CA-01, CA-05, CA-12, CA-16)
- [x] Fluxos alternativos e exceções mapeados (CA-08, CA-10, CA-11, CA-13, CA-15, CA-19, CA-20)
- [x] Recusa explícita para cada perfil sem permissão (CA-17)
- [x] Isolamento estrito entre famílias (CA-06, CA-18)
- [x] Ações simultâneas e concorrência tratadas (CA-19)
- [x] Falha de conexão, timeout e preservação de estado (CA-08, CA-13)
- [x] Validações de fronteira cobertas (CA-06, CA-10, CA-11)

## 8. Observabilidade, auditoria e retenção

| Evento | Tipo | Gatilho | Propriedades | Destino |
|---|---|---|---|---|
| `account_deleted` | Métrica | Exclusão de perfil confirmada | `role`, `actor` (`self`/`administrator`), `familyDeleted: false` | Analytics |
| `family_deleted` | Métrica | Exclusão da família confirmada | `memberCount`, `appleTokenSource` (`stored`/`proof`) | Analytics |
| `apple_token_revoked` | Log | Revogação aceita pela Apple | `attempt` | Log estruturado |
| `apple_token_revocation_failed` | Log de segurança | Tentativa recusada ou esgotada | `attempt`, `reason` | Log estruturado |
| `media_deletion_failed` | Log | Falha ao apagar objeto no R2 | `attempt`, `reason` | Log estruturado |

- Nenhum evento registra nome, apelido, foto, identificador Apple, token, prova ou nome da família.
- **Retenção:** logs estruturados sem dado pessoal podem manter identificadores técnicos (`memberId`, `familyId`). Backups do provedor do banco expiram conforme o ciclo do provedor, sem rotina própria de backup. O token Apple cifrado é guardado enquanto a conta do Criador existir e apagado após a revogação ou o esgotamento das tentativas. A política de privacidade deve refletir este parágrafo.

## 9. Premissas e esclarecimentos

### 9.1. Premissas

- **P-01:** a família sempre tem o Criador como Administrador (RN05); por isso a exclusão de um Administrador não-Criador nunca deixa a família sem Administrador.
- **P-02:** a Apple devolve refresh token na troca do `authorizationCode` feita em `POST /v1/access/apple`; hoje esse token é descartado em `backend/src/integrations/apple/apple-token-client.ts`.
- **P-03:** o backend já cifra o identificador Apple com AES-256-GCM (`crypto-token-service.ts`); a guarda do refresh token reaproveita esse mecanismo. A chave deriva do segredo de sessão, cuja troca exige plano de recifragem (BA-40).

### 9.2. Esclarecimentos e decisões

| # | Pergunta / dúvida | Decisão tomada | Decidido por / data | Altera `docs/`? |
|---|---|---|---|---|
| E-01 | Numeração do par, dado que SPEC-021 foi absorvida pela SPEC-002 | SPEC-022 / UX-022 | Pessoa usuária / 2026-11-16 | Não |
| E-02 | Como excluir a conta do Criador, protegido por RN05 | A exclusão da conta do Criador exclui a família inteira; transferência do papel fica fora do escopo | Pessoa usuária / 2026-11-16 | Sim: RN05, RN70, RF73, UC02, UC20 |
| E-03 | Destino do histórico do perfil excluído | Anonimizar: apagar nome, apelido e foto; preservar conclusões, créditos, participações, badges, destaques e parabéns como "Membro removido". Arquivos de foto de sinalização do titular também são apagados e a sinalização permanece sem foto (recomendação assumida, sem objeção) | Pessoa usuária / 2026-11-16 | Sim: RN10, RN69, RF72, RNF24 |
| E-04 | Exclusão de conta Kids | Kids exclui a própria conta e Administrador também pode excluí-la em TEL-032; Administrador não exclui contas de adultos | Pessoa usuária / 2026-11-16 | Sim: RN07, RF74, UC02 |
| E-05 | Revogação dos tokens Apple | Guardar o refresh token Apple cifrado a cada login do Criador e revogá-lo na exclusão; sem token guardado, exigir nova autenticação Apple. Tentativa imediata e fila com retentativas; falha não desfaz a exclusão | Pessoa usuária / 2026-11-16 | Sim: RN44, RF37, RF39, RNF15, RNF16, RNF28, UC04; SPEC-001 |
| E-06 | Exclusão imediata ou com carência | Imediata e irreversível | Pessoa usuária / 2026-11-16 | Sim: RN69, RN70 |
| E-07 | Família excluída: apagamento físico? Mesma Apple ID pode criar nova família? | Sim às duas; exceção explícita à regra de não cascata do modelo; token cifrado sobrevive somente na fila de revogação | Pessoa usuária / 2026-11-16 | Sim: RN44, RN70, `05-modelo-de-dados.md` |
| E-08 | Confirmação do Criador | Digitar o nome da família antes da confirmação final; verificação exclusiva da interface | Pessoa usuária / 2026-11-16 | Não (UX-022) |
| E-09 | O que vê quem perde o acesso | Mensagem neutra nova de acesso encerrado, sem push | Pessoa usuária / 2026-11-16 | Não (UX-022) |
| E-10 | Retenção residual | Texto da seção 8 confirmado | Pessoa usuária / 2026-11-16 | Sim: RNF28 |
| E-11 | Rótulo do perfil excluído no histórico | Reaproveitar "Membro removido" | Pessoa usuária / 2026-11-16 | Sim: RN30, RN31, RN61, RN62 |

*Regra:* a base em `docs/` foi atualizada para RN 1.28 / RF 1.27 / UC 1.27 junto com esta spec. Spec aprovada pela pessoa usuária em 2026-11-17, junto com a revisão da SPEC-001 (Fase 4, guarda do token Apple) e as decisões UX-03/UX-04 da UX-022.

## 10. Fases de implementação e critérios de conclusão

| Fase | Objetivo | Critérios atendidos | Definition of Done | Status |
|---|---|---|---|---|
| **1** | Exclusão da própria conta por perfis não-Criador (backend e mobile), com anonimização, revogação, mídias, isolamento e falhas | CA-01 a CA-09, CA-19 | Testes de integração do backend e testes de ViewModel verdes; TEL-030, TEL-058 e MOD-015 conforme UX-022 | backend concluído; mobile a fazer |
| **2** | Guarda do token Apple no login e exclusão da família pelo Criador, com revogação e limpeza do R2 | CA-10 a CA-15, CA-20 | Testes com Apple simulada (troca, revogação, falha e fila); variante Criador de TEL-058 conforme UX-022 | backend concluído; mobile a fazer |
| **3** | Exclusão de conta Kids pelo Administrador | CA-16 a CA-18 | Testes de autorização e isolamento verdes; ação em TEL-032 conforme UX-022 | backend concluído; mobile a fazer |

- **Fora da Fase 1:** o Criador não vê a entrada "Excluir conta" em TEL-030; TEL-032 não oferece a ação administrativa.
- **Fora da Fase 2:** TEL-032 não oferece a ação administrativa.
- **Pode ser publicada de forma independente em produção?** Fase 1 sim, em TestFlight. A submissão à App Store exige as Fases 1 e 2, porque o Criador é quem cria conta pelo aplicativo. A Fase 3 pode sair depois.

## 11. Checklist de aprovação da spec

- [x] Todos os códigos citados existem na base funcional vigente (RN 1.28 / RF 1.27 / UC 1.27).
- [x] A rastreabilidade técnica (BA-40, MA-22) está registrada como proposta técnica; os detalhes serão confirmados no plano técnico de `desenvolver-card`.
- [x] O contrato de API compartilhado está completo.
- [x] O dicionário de campos define tipos, limites e códigos de erro.
- [x] Todo critério segue o padrão BDD e mapeia um teste automatizável.
- [x] Isolamento entre famílias (RNF06) e recusa por perfil (RNF07) constam nos CAs da primeira fase que expõe cada capacidade.
- [x] Nenhuma premissa sem validação: a revisão da SPEC-001 (Fase 4) foi aprovada em 2026-11-17.
- [x] A UX-spec correspondente está vinculada.
- [x] A seção "Fora de questão" elimina suposições incorretas.
- [x] Não há detalhes efêmeros de implementação que engessem a arquitetura.
