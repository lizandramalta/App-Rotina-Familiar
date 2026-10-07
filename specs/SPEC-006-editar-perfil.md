# Spec 006: Editar perfil e consultar badges

**Status:** aprovada
**Autor:** Claude | **Criada em:** 2026-10-07 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-07
**Base funcional:** 1.13
**UX-spec:** [UX-006-editar-perfil.md](UX-006-editar-perfil.md)
**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 1 - Acesso, família e perfis

## 1. Contexto e Objetivo

- **Problema / Necessidade:** com SPEC-003 aprovada, um Administrador já cria e gerencia perfis, mas nenhum perfil consegue configurar sua própria identificação pessoal (foto, apelido) — a rota administrativa recusa explicitamente esses campos. Com SPEC-014 aprovada, missões já concedem badges por participação, mas essa conquista fica invisível: não existe superfície de consulta. Sem esta entrega, UC10 permanece sem implementação.
- **Objetivo da entrega:** permitir que qualquer perfil (Administrador, Membro, Kids) edite a foto opcional e o apelido do próprio perfil, sem alterar papel, família ou modo Kids, e consultar os badges cumulativos por participação em missões, incluindo o detalhe das missões contribuintes de cada marco.

## 2. Rastreabilidade e Dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Casos de uso | UC10 (completo) |
| Regras de negócio | RN33, RN63, RN64 |
| Requisitos funcionais | RF48, RF62, RF65 |
| Requisitos não funcionais | RNF01, RNF05, RNF06, RNF07, RNF08, RNF12, RNF13, RNF14, RNF22, RNF24, RNF27 |
| Telas e fluxos de navegação | TEL-030 (recorte de dados pessoais e badges), MOD-009, TEL-054, UF-13 |
| Decisões arquiteturais aplicáveis | MA-07, MA-08, MA-11, MA-15, MA-16; BA-08, BA-16 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md` (RN33/63/64), `docs/02-requisitos.md` (RF48/62/65 e RNF citadas), `docs/03-casos-de-uso.md` (UC10), `docs/05-modelo-de-dados.md` (MEMBRO, MIDIA, BADGE, MEMBRO_BADGE, BADGE_PARTICIPACAO), `docs/06-diagrama-de-classes.md` (Member, MemberService, Badge, BadgeAward, BadgeTier, rastreio-uc10), `docs/design/screen-map.md` (TEL-030/054, MOD-009), `docs/design/user-flows.md` (UF-13), `docs/architecture/backend-contracts.md` (§1, §3, §6, §7), `docs/architecture/backend-architecture.md` (processamento de mídia), `docs/architecture/backend-decisions.md` (BA-16), `docs/architecture/mobile-decisions.md` (P-04), `docs/architecture/mobile-feature-catalog.md`.
- **Depende de (specs pré-requisito):** [SPEC-003-gerenciar-membros](SPEC-003-gerenciar-membros.md) (aprovada) — define `Member` e a rota administrativa que já exclui apelido/foto. [SPEC-014-gerenciar-missoes](SPEC-014-gerenciar-missoes.md) (aprovada) — `CloseEligibleMissions` já registra `MissionParticipation` e concede `BadgeAward`.
- **Dependências externas e infraestrutura:** Cloudflare R2 (armazenamento privado de mídia), conforme BA-16. Nenhuma dependência de Apple Sign-In, APNs ou serviços externos novos.

## 3. Escopo da Entrega

### 3.1. Dentro do escopo

- `GET /v1/me/profile` (`GetOwnProfile`): nome administrativo (somente leitura), `nickname`, `photoMediaId`, total de participações em missões e próximo marco.
- `PATCH /v1/me/profile` (`UpdateOwnProfile`): atualizar `nickname` e/ou `photoMediaId`, ambos opcionais e nuláveis; rejeitar qualquer campo protegido (papel, família, modo Kids, identidade Apple).
- `GET /v1/me/badges` (`GetOwnBadges`): lista de badges cumulativos concedidos ao titular (bronze/prata/ouro/diamante).
- `GET /v1/me/badges/{awardId}` (`GetBadgeContributions`): marco, data de concessão e missões que contribuíram para ele, restrito ao titular do marco.
- `POST /v1/media` e `GET /v1/media/{mediaId}/content`, restritos nesta entrega a `purpose: profilePhoto` — infraestrutura compartilhada de upload/leitura de mídia privada (R2), reutilizável por `purpose: taskSignal` em entrega futura (SPEC-012/UC15), que não é implementada aqui.
- TEL-030 (recorte de dados pessoais e badges — a ação "deixar administração" já entregue por SPEC-003 permanece inalterada), MOD-009 (Editar meu perfil) e TEL-054 (Detalhe do marco) no mobile.
- Autorização por titularidade exclusiva, isolamento multitenant/entre membros e validação de entrada, desde a Fase 1.

### 3.2. Fora do escopo (desta spec)

- Gestão administrativa de membros (nome administrativo, papel, modo Kids, remoção, convites) — `SPEC-003`.
- Ação "Sair da administração" em TEL-030 — já entregue por `SPEC-003`.
- Progresso, participações e recompensa de missões na tela de Missões e conquistas — `SPEC-016`.
- `purpose: taskSignal` do upload de mídia (sinalização Kids) — `SPEC-012`.
- Acompanhamento de carga familiar — fora do escopo de UC10.

### 3.3. Fora de questão (Anti-requisitos / Suposições descartadas)

- Não existe seleção, criação ou concessão manual de selo/badge por missão; badges seguem exclusivamente os marcos fixos 5/10/25/50 (RN64).
- Não há concessão retroativa de badge a quem ingressou na família depois do encerramento de uma missão (RN64).
- Nenhum perfil, inclusive Administrador, edita apelido ou foto de outro membro por qualquer rota, inclusive a administrativa (RF48, RNF27).
- Não há moderação de conteúdo nem filtro de palavras no apelido além do limite de caracteres definido nesta spec.
- O upload de foto não aceita URL remota arbitrária; a mídia é sempre recebida, validada e armazenada pelo backend (backend-architecture.md).
- Kids não ativam ou desativam o próprio modo Kids por este fluxo (UC10 alternativas).
- Não há exclusão física de `BadgeAward`/`MissionParticipation` por esta spec; reversão desses dados é exclusiva da reabertura de tarefa (`SPEC-011`/UC17), fora deste recorte.

## 4. Perfis, Atores e Regras de Autorização (RBAC)

| Perfil | Pode | Não pode | Reação do sistema a tentativa não autorizada |
|---|---|---|---|
| **Administrador** | Editar a própria foto/apelido; consultar os próprios badges e missões contribuintes | Editar apelido/foto de outro membro, inclusive pela rota administrativa (`PATCH /family/members/{id}`); consultar badge de outro membro | HTTP 403 `ACTION_NOT_ALLOWED` (campo protegido) / HTTP 404 `RESOURCE_NOT_FOUND` (badge de terceiro) / Ação oculta na UI |
| **Membro** | Idem Administrador | Idem Administrador | Idem Administrador |
| **Kids** | Editar a própria foto/apelido (câmera ou galeria, igual aos adultos); consultar os próprios badges | Ativar/desativar o próprio modo Kids por este fluxo; qualquer ação administrativa | HTTP 403 `ACTION_NOT_ALLOWED` / Ação oculta na UI |

- **Isolamento Multitenant Familiar (RNF06):** `GET /v1/me/badges/{awardId}` com um `awardId` que não pertença ao titular autenticado (de qualquer família) responde `404 Not Found` com código `RESOURCE_NOT_FOUND`, sem revelar metadado do marco de terceiro.
- **Titularidade exclusiva (RF48, RNF27):** as rotas `/v1/me/profile` e `/v1/me/badges*` operam exclusivamente sobre o membro da sessão ativa; não aceitam `memberId` como parâmetro. A rota administrativa `PATCH /v1/family/members/{memberId}` (SPEC-003) já rejeita `nickname`/`photoMediaId` com `400 UNKNOWN_FIELD`, preservando essa restrição sem alteração nesta entrega.

## 5. Contrato de Dados, Interface e Validações

### 5.1. Dicionário de Campos e Validações de Entrada

| Campo (`json_key`) | Tipo | Obrigatório? | Regras de Validação e Limites | Código de Erro (`fieldErrors[].code`) | Descrição e Comportamento |
|---|---|---|---|---|---|
| `nickname` | string ou `null` | Não | Opcional. Após remover espaços nas extremidades, no máximo **20 caracteres não-espaço** (espaços internos não contam para o limite); sem caracteres de controle. `null` ou string vazia após trim remove a configuração vigente. | `NICKNAME_INVALID_LENGTH` | Etiqueta/apelido visível à família; configuração exclusiva do titular (RN63) |
| `photoMediaId` | uuid ou `null` | Não | Deve referenciar uma `MIDIA` em estado `READY`, pertencente ao titular (`titular_id`), com `finalidade: PROFILE_PHOTO`. `null` remove a foto vigente e volta à identificação padrão. | `PHOTO_MEDIA_NOT_READY` / `PHOTO_MEDIA_NOT_OWNED` / `PHOTO_MEDIA_PURPOSE_MISMATCH` | Foto de perfil opcional, por câmera ou galeria (RN63) |
| `purpose` (em `POST /media`) | enum | Sim | Nesta entrega, apenas `profilePhoto` é aceito; `taskSignal` responde `422` até `SPEC-012` implementar esse uso. | `MEDIA_PURPOSE_NOT_SUPPORTED` | Finalidade declarada do upload |
| arquivo (multipart, em `POST /media`) | binário | Sim | Formato de imagem reconhecível pelo decodificador do servidor; o backend converte para JPEG com lado maior ≤1.600px e ≤5MB após processamento, removendo metadados (BA-16, mobile-decisions.md P-04). Falha de decodificação ou tamanho de entrada acima do limite operacional responde `415`/`413`. | `MEDIA_FORMAT_UNSUPPORTED` / `MEDIA_TOO_LARGE` | Conteúdo da foto a ser processado e armazenado no R2 |

Campos não reconhecidos ou protegidos (`role`, `familyId`, `kidsMode`, `isFamilyCreator`, `appleUserID`, `status`, `concededAt`, `contributingMissionIds`) em `PATCH /v1/me/profile` são rejeitados com `400 UNKNOWN_FIELD`, sem persistir (convenção §1 dos contratos backend).

### 5.2. Contrato de API Compartilhado

#### `GET /v1/me/profile`
- **Autenticação:** Bearer Token de sessão ativa.
- **Resposta de sucesso — `200 OK`:**
```json
{
  "memberId": "c1d2e3f4-a5b6-7890-cdef-123456789abc",
  "name": "Maria Silva",
  "nickname": "Mari",
  "photoMediaId": "d4e5f6a7-b8c9-0123-def4-567890abcdef",
  "totalParticipations": 7,
  "nextTier": { "code": "silver", "requiredMissionCount": 10, "remaining": 3 }
}
```
`nextTier` é `null` quando o titular já atingiu `diamond` (50). `photoMediaId` é `null` sem foto configurada.

#### `PATCH /v1/me/profile`
- **Autenticação:** Bearer Token de sessão ativa.
- **Payload de entrada:**
```json
{ "nickname": "Mari", "photoMediaId": "d4e5f6a7-b8c9-0123-def4-567890abcdef" }
```
- **Resposta de sucesso — `200 OK`:** mesmo formato de `GetOwnProfile`, refletindo o estado canônico persistido.

#### `GET /v1/me/badges`
- **Resposta de sucesso — `200 OK`:**
```json
{
  "totalParticipations": 7,
  "nextTier": { "code": "silver", "requiredMissionCount": 10, "remaining": 3 },
  "awards": [
    { "awardId": "e5f6a7b8-...", "tier": "bronze", "requiredMissionCount": 5, "awardedAt": "2026-09-20T12:00:00Z" }
  ]
}
```

#### `GET /v1/me/badges/{awardId}`
- **Resposta de sucesso — `200 OK`:**
```json
{
  "awardId": "e5f6a7b8-...",
  "tier": "bronze",
  "awardedAt": "2026-09-20T12:00:00Z",
  "contributingMissions": [
    { "missionId": "f6a7b8c9-...", "title": "Organizar a sala", "completedAt": "2026-09-18T20:00:00Z" }
  ]
}
```

#### `POST /v1/media`
- **Autenticação:** Bearer Token de sessão ativa.
- **Headers:** `Content-Type: multipart/form-data`.
- **Entrada:** campo `purpose: "profilePhoto"` e arquivo de imagem.
- **Resposta de sucesso — `201 Created`:**
```json
{ "mediaId": "d4e5f6a7-b8c9-0123-def4-567890abcdef", "state": "READY", "width": 1600, "height": 1600 }
```
`state` pode retornar `UPLOADING` se o processamento for assíncrono; o cliente consulta novamente antes de vincular em `PATCH /me/profile`.

#### `GET /v1/media/{mediaId}/content`
- **Autenticação:** Bearer Token de sessão ativa; o servidor confere titularidade/família/finalidade a cada leitura.
- **Resposta de sucesso:** `200 OK`, streaming binário com `Content-Type` da imagem, sem cache compartilhado.

#### Respostas de Erro Padronizadas (RFC 9457)

| HTTP Status | `code` estável | Cenário / Causa |
|---|---|---|
| `400 Bad Request` | `UNKNOWN_FIELD` | Campo não reconhecido ou protegido em `PATCH /me/profile` |
| `400 Bad Request` | `VALIDATION_FAILED` | `fieldErrors` com `NICKNAME_INVALID_LENGTH` |
| `401 Unauthorized` | `SESSION_EXPIRED` | Token ausente, inválido ou expirado |
| `403 Forbidden` | `ACTION_NOT_ALLOWED` | Tentativa de ação administrativa pelo fluxo pessoal (ex.: Kids alterando modo) |
| `404 Not Found` | `RESOURCE_NOT_FOUND` | `awardId` que não pertence ao titular, de qualquer família |
| `413 Payload Too Large` | `MEDIA_TOO_LARGE` | Upload acima do limite de entrada aceito pelo servidor |
| `415 Unsupported Media Type` | `MEDIA_FORMAT_UNSUPPORTED` | Formato de imagem não reconhecido |
| `422 Unprocessable Entity` | `PHOTO_MEDIA_NOT_READY` / `PHOTO_MEDIA_NOT_OWNED` / `PHOTO_MEDIA_PURPOSE_MISMATCH` | `photoMediaId` ainda processando, de outro titular, ou com finalidade incompatível |
| `422 Unprocessable Entity` | `MEDIA_PURPOSE_NOT_SUPPORTED` | `purpose: taskSignal` nesta entrega (reservado para SPEC-012) |
| `429 Too Many Requests` | `RATE_LIMIT_EXCEEDED` | Excesso de requisições de edição/upload por janela |

### 5.3. Estratégia de Concorrência, Idempotência e Falhas

- **Idempotência:** `PATCH /me/profile` não usa `Idempotency-Key`; segue a convenção geral (§1 dos contratos) de que comandos do usuário não são reenviados automaticamente — resposta perdida leva à consulta de `GET /me/profile` antes de repetir.
- **Concorrência:** última gravação válida persistida vence (MA-08), sem exigência de versão esperada. Substituir foto mantém a mídia anterior vinculada até a transação de perfil confirmar a nova (backend-architecture.md); falha não perde a foto vigente.
- **Tratamento de Falhas e Rede Intermitente (RNF12, RNF13):** falha ao salvar `nickname`/`photoMediaId` mantém os dados anteriores persistidos e informa a falha sem apagar o que foi digitado no formulário; falha de upload de foto opcional permite tentar novamente ou prosseguir sem foto (UC10 alternativas).

## 6. Estados de Domínio e Transições

| Estado De | Evento / Ação | Estado Para | Quem Pode Executar | Regras e Validações | Efeitos Colaterais |
|---|---|---|---|---|---|
| `MIDIA.UPLOADING` | Upload confirmado pelo R2 e verificado | `READY` | Sistema (backend) | Bytes/formato válidos; conversão JPEG ≤1.600px/≤5MB | Mídia torna-se vinculável via `photoMediaId` |
| `MIDIA.UPLOADING` | Falha de processamento ou I/O | `FAILED` | Sistema (backend) | — | Cliente é informado para repetir o upload |
| `MIDIA` sem vínculo (nenhum `MEMBRO.foto_id` aponta para ela) | 24 horas sem vínculo | `DELETING` → `DELETED` | Job assíncrono | BA-16 | Objeto removido do R2 |
| `MEMBRO.foto_id = A` | `UpdateOwnProfile` com `photoMediaId = B` (B `READY`, do titular) | `MEMBRO.foto_id = B` | Titular (qualquer papel) | B deve ser `READY`, do titular, `purpose: profilePhoto` | Mídia `A` passa a não ter vínculo; sujeita à limpeza de 24h se nenhuma outra referência existir |
| `MEMBRO.foto_id = A` | `UpdateOwnProfile` com `photoMediaId = null` | `MEMBRO.foto_id = null` | Titular (qualquer papel) | — | Identificação padrão volta a ser exibida |

## 7. Critérios de Aceitação (BDD Formal)

- **CA-01: [Fluxo principal — Consulta do próprio perfil]**
  - **DADO QUE** um perfil ativo de qualquer papel está autenticado,
  - **QUANDO** consultar `GET /v1/me/profile`,
  - **ENTÃO O SISTEMA DEVE** retornar nome administrativo, apelido, `photoMediaId`, total de participações e próximo marco, sem dados de terceiros,
  - **E** retornar HTTP `200 OK`. *(UC10 passo 1; RF48, RF62)*

- **CA-02: [Fluxo principal — Edição com sucesso]**
  - **DADO QUE** um titular autenticado envia `nickname` com até 20 caracteres não-espaço e/ou `photoMediaId` de mídia `READY` própria,
  - **QUANDO** `PATCH /v1/me/profile` for processado,
  - **ENTÃO O SISTEMA DEVE** persistir as alterações e retornar o estado canônico atualizado,
  - **E** NÃO DEVE alterar papel, família ou modo Kids. *(UC10 passos 3–4; RF48, RN63)*

- **CA-03: [Campo protegido]**
  - **DADO QUE** o payload de `PATCH /v1/me/profile` contém `role`, `familyId` ou `kidsMode`,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** rejeitar com HTTP `400 Bad Request` e código `UNKNOWN_FIELD`,
  - **E** não persistir nenhuma alteração. *(RF48; convenção §1 dos contratos)*

- **CA-04: [Tentativa Não Autorizada — Apelido/foto de terceiro]**
  - **DADO QUE** um Administrador tenta alterar `nickname`/`photoMediaId` de outro membro pela rota `PATCH /v1/family/members/{memberId}`,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** rejeitar com HTTP `400 Bad Request` e código `UNKNOWN_FIELD` (comportamento já garantido por SPEC-003, reafirmado aqui como critério de isolamento),
  - **E** a rota `/v1/me/profile` não aceita parâmetro de `memberId`, operando apenas sobre o titular da sessão. *(RF48, RNF27)*

- **CA-05: [Isolamento Multitenant — Badge de outro titular]**
  - **DADO QUE** um `awardId` existe e pertence a outro membro (da mesma família ou de outra),
  - **QUANDO** o titular autenticado tentar `GET /v1/me/badges/{awardId}`,
  - **ENTÃO O SISTEMA DEVE** responder HTTP `404 Not Found` com código `RESOURCE_NOT_FOUND`,
  - **E** não revelar tier, data de concessão ou missões do marco de terceiro. *(RNF06)*

- **CA-06: [Validação — Apelido acima do limite]**
  - **DADO QUE** o usuário envia `nickname` com mais de 20 caracteres não-espaço após trim,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** recusar com HTTP `400 Bad Request`,
  - **E** retornar `fieldErrors` contendo o campo `nickname` e o código `NICKNAME_INVALID_LENGTH`. *(RN63)*

- **CA-07: [Validação — Mídia não pronta ou não própria]**
  - **DADO QUE** `photoMediaId` referencia uma mídia em `UPLOADING`, `FAILED`, de outro titular, ou com `finalidade` diferente de `PROFILE_PHOTO`,
  - **QUANDO** `PATCH /v1/me/profile` for processado,
  - **ENTÃO O SISTEMA DEVE** recusar com HTTP `422 Unprocessable Entity` e o código específico (`PHOTO_MEDIA_NOT_READY`, `PHOTO_MEDIA_NOT_OWNED` ou `PHOTO_MEDIA_PURPOSE_MISMATCH`),
  - **E** manter a foto anteriormente vinculada sem alteração. *(RNF24; backend-architecture.md)*

- **CA-08: [Validação — Upload fora dos limites]**
  - **DADO QUE** o arquivo enviado a `POST /v1/media` excede o limite de entrada do servidor ou tem formato não reconhecido,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** recusar com HTTP `413 Payload Too Large` ou `415 Unsupported Media Type`, conforme o caso,
  - **E** não criar registro `MIDIA` em estado utilizável. *(BA-16, mobile-decisions.md P-04)*

- **CA-09: [Resiliência — Falha de persistência do perfil]**
  - **DADO QUE** a gravação de `PATCH /v1/me/profile` falha após envio,
  - **QUANDO** o cliente mobile identificar a falha,
  - **ENTÃO O SISTEMA DEVE** manter o apelido/foto anteriores persistidos,
  - **E** o aplicativo DEVE manter os dados preenchidos no formulário, permitindo nova tentativa sem perda de digitação. *(RNF12, RNF13; UC10 alternativas)*

- **CA-10: [Badges — Estado vazio e marcos]**
  - **DADO QUE** um titular não tem nenhuma participação registrada,
  - **QUANDO** consultar `GET /v1/me/badges`,
  - **ENTÃO O SISTEMA DEVE** retornar `totalParticipations: 0` e `nextTier` apontando para `bronze` (5),
  - **E** NÃO DEVE simular ou conceder qualquer badge. *(RN64; UC10 alternativas)*

- **CA-11: [Badges — Detalhe do marco]**
  - **DADO QUE** um titular possui o badge `silver` concedido,
  - **QUANDO** consultar `GET /v1/me/badges/{awardId}` para esse marco,
  - **ENTÃO O SISTEMA DEVE** retornar as missões que contribuíram para a concessão, com `missionId` e `title` para permitir abrir o detalhe de cada uma. *(RF62, RN64)*

- **CA-12: [Perfil Kids]**
  - **DADO QUE** o usuário autenticado tem papel `kids`,
  - **QUANDO** editar a própria foto/apelido pelas rotas `/v1/me/profile` e `/v1/media`,
  - **ENTÃO O SISTEMA DEVE** permitir a operação nos mesmos termos de um perfil adulto,
  - **E** NÃO DEVE expor nenhuma ação administrativa ou de terceiros nessas rotas. *(UC10 Atores; RF65)*

### Checklist de Cobertura Obrigatória dos CAs:
- [x] Fluxo principal de cada UC coberto (CA-01, CA-02)
- [x] Todos os fluxos alternativos e exceções dos UCs mapeados (CA-06 a CA-10)
- [x] Recusa explícita para cada perfil sem permissão (RNF07) — CA-03, CA-04, CA-12
- [x] Isolamento estrito entre famílias / multitenancy (RNF06) — CA-05
- [ ] Ações simultâneas e concorrência tratadas (RNF11) — não aplicável nesta entrega: não há dois atores concorrendo sobre o mesmo recurso de perfil pessoal (titularidade exclusiva elimina a disputa); concorrência de última gravação válida é descrita na seção 5.3.
- [x] Falha de conexão, timeout e preservação de estado (RNF12, RNF13) — CA-09
- [x] Limites numéricos de campos e validações de fronteira cobertos — CA-06, CA-08

## 8. Observabilidade, Métricas e Auditoria

| Evento | Tipo | Gatilho / Condição | Propriedades Registradas | Destino |
|---|---|---|---|---|
| `own_profile_updated` | Métrica / Analytics | `PATCH /me/profile` confirmado | `memberId`, `familyId`, `changedFields` (sem valores) | Analytics |
| `profile_photo_uploaded` | Métrica / Analytics | `POST /media` com `purpose: profilePhoto` concluído | `memberId`, `familyId`, `mediaState` | Analytics |
| `badge_contributions_viewed` | Métrica / Analytics | `GET /me/badges/{awardId}` com sucesso | `memberId`, `familyId`, `tier` | Analytics |
| `audit_unauthorized_access` | Log de Segurança | Tentativa de acessar `awardId` de terceiro ou campo protegido | `actorId`, `targetAwardId` ou `rejectedField`, `endpoint` | Log estruturado |

*Nota de Privacidade e Segurança:* Conteúdo da foto, tokens, senhas e hashes nunca são registrados em logs ou eventos de telemetria (backend-architecture.md).

## 9. Premissas e Esclarecimentos

### 9.1. Premissas

- **P-01:** O limite de 20 caracteres não-espaço para o apelido conta apenas caracteres visíveis após remover espaços nas extremidades; espaços internos permanecem no valor salvo mas não contam para o limite.
- **P-02:** O limite de upload bruto antes do processamento (bytes aceitos pelo servidor antes da conversão para JPEG ≤1.600px/≤5MB) é parâmetro operacional de infraestrutura, não bloqueando esta spec, conforme `docs/architecture/backend-decisions.md`.

### 9.2. Esclarecimentos e Decisões

| # | Pergunta / Dúvida | Decisão Tomada | Decidido por / Data | Altera a documentação em `docs/`? |
|---|---|---|---|---|
| E-01 | Não havia limite de caracteres/charset definido para `nickname` em nenhuma fonte (RN63, RF48, modelo de dados). | Até 20 caracteres não-espaço após trim, sem caracteres de controle; vazio/nulo remove a configuração. | Pessoa usuária / 2026-10-07 | Sim — RN63 e RF48 atualizados (base funcional 1.13). |
| E-02 | A tabela de rastreabilidade UC→backend associa `UploadMedia` explicitamente a UC15 (SPEC-012, ainda não criada), não a UC10. Quem implementa a infraestrutura compartilhada de mídia primeiro? | Esta spec (SPEC-006) implementa `POST /media`/`GET /media/{id}/content` restritos a `purpose: profilePhoto`; `taskSignal` fica reservado para SPEC-012 reutilizar a mesma infraestrutura. | Pessoa usuária / 2026-10-07 | Não — apenas sequenciamento de entrega, sem mudança de regra. |

## 10. Fases de Implementação e Critérios de Conclusão

| Fase | Objetivo da Entrega | Critérios de Aceite Atendidos | Critério de Prontidão (Definition of Done) | Status |
|---|---|---|---|---|
| **1** | **Núcleo Mínimo (Core API + Isolamento):** `GetOwnProfile`, `UpdateOwnProfile`, `GetOwnBadges`, `GetBadgeContributions`, `POST /media`/`GET /media/{id}/content` (`purpose: profilePhoto`); titularidade, isolamento e validação. | CA-01, CA-02, CA-03, CA-04, CA-05, CA-06, CA-07, CA-08, CA-10, CA-11, CA-12 | Testes unitários e de integração verdes cobrindo os CAs listados. | a fazer |
| **2** | **Experiência Mobile + Integração:** TEL-030 (recorte), MOD-009, TEL-054; câmera/galeria; estados de carregamento/erro/falha de upload. | CA-02, CA-06 a CA-10 integrados à UI | Telas integradas com a API, testes de UI/E2E e UX-spec verificada. | a fazer |
| **3** | **Polimento e Casos Raros:** acessibilidade fina, transições de badge, textos de borda, animação de marco conquistado. | — (refinamento, sem novo CA) | Suíte de regressão verde e validação de QA concluída. | a fazer |

### Para cada fase:
- **Fase 1 — Fora desta fase:** nenhuma tela; capacidade exposta apenas via API. **Pode ser publicada de forma independente em produção?** Não — requer Fase 2 para ser utilizável.
- **Fase 2 — Fora desta fase:** polimento visual fino de TEL-054 e animações. **Pode ser publicada de forma independente em produção?** Sim.
- **Fase 3 — Fora desta fase:** nada; é refinamento da Fase 2. **Pode ser publicada de forma independente em produção?** Sim, após a Fase 2.

## 11. Checklist de Aprovação da Spec (Definition of Ready)

- [x] Todos os códigos citados (`RN`, `RF`, `RNF`, `UC`, `TEL`, `UF`) existem na base funcional vigente.
- [x] A rastreabilidade técnica (`MA-..`, `BA-..`) está alinhada com as diretrizes de arquitetura.
- [x] O contrato de API compartilhado (rotas, payloads JSON, status HTTP e Problem Details) está completo e sem ambiguidades.
- [x] O dicionário de campos define tipos, limites e códigos de erro estáveis para todos os inputs.
- [x] Todo critério de aceitação segue o padrão formal BDD (DADO / QUANDO / ENTÃO / E) e mapeia um teste automatizável.
- [x] Isolamento entre famílias (RNF06) e recusa por perfil (RNF07) constam explicitamente nos CAs da Fase 1.
- [x] Nenhuma premissa sem validação ou esclarecimento pendente na seção 9 — E-01 e E-02 decididos.
- [x] A UX-spec correspondente está vinculada, revisada e coerente.
- [x] A seção "Fora de questão" elimina riscos de suposições incorretas.
- [x] Não há detalhes efêmeros de implementação que engessem a arquitetura interna dos módulos.
