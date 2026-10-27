# Spec 012: Sinalizar tarefa como realizada

**Status:** aprovada
**Autor:** Claude | **Criada em:** 2026-10-07 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-07
**Base funcional:** 1.14
**UX-spec:** [UX-012-sinalizar-tarefa-kids.md](UX-012-sinalizar-tarefa-kids.md)
**Projetos envolvidos:** ambos
**Tema do backlog:** Tema 3 - Participação Kids

## 1. Contexto e Objetivo

- **Problema / Necessidade:** com SPEC-007 aprovada, a tarefa já existe e pode ter responsável Kids, mas a criança não tem nenhuma forma de informar que realizou sua parte — ela só consegue consultar a tarefa (SPEC-009). Sem esta entrega, UC15 permanece sem implementação e a fila administrativa de UC03/SPEC-013 nunca recebe itens.
- **Objetivo da entrega:** permitir que um perfil Kids sinalize a realização de uma tarefa própria pendente, com foto opcional capturada diretamente pela câmera, movendo a tarefa para `awaitingConfirmation` sem gerar crédito ou conclusão parcial.

## 2. Rastreabilidade e Dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Caso de uso | UC15 (completo) |
| Regras de negócio | RN21, RN22, RN23, RN24, RN30, RN35, RN54, RN55, RN56 |
| Requisitos funcionais | RF23, RF24, RF55, RF56 |
| Requisitos não funcionais | RNF01, RNF02, RNF04, RNF05, RNF06, RNF07, RNF08, RNF09, RNF11, RNF12, RNF13, RNF14, RNF22, RNF24 |
| Telas e fluxos de navegação | TEL-041, MOD-011, UF-07 (somente o ramo Kids) |
| Decisões arquiteturais aplicáveis | MA-07, MA-08, MA-16; BA-16 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md` (RN21–24/30/35/54–56), `docs/02-requisitos.md` (RF23/24/55/56 e RNF citadas), `docs/03-casos-de-uso.md` (UC15, e UC03 para delimitar a fronteira), `docs/05-modelo-de-dados.md` (`OCORRENCIA`, `OCORRENCIA_EVENTO`, `MIDIA`), `docs/06-diagrama-de-classes.md` (`FamilyTask`, `KidsSignal`, `TaskStatus`, rastreio-uc15), `docs/design/screen-map.md` (TEL-041, MOD-011), `docs/design/user-flows.md` (UF-07), `docs/architecture/backend-contracts.md` (§4, §6, §7), `docs/architecture/backend-architecture.md` (§13, fotos no R2), `docs/architecture/backend-decisions.md` (BA-16), `docs/architecture/mobile-decisions.md` (MA-07/08/16), `docs/architecture/mobile-feature-catalog.md`.
- **Depende de (specs pré-requisito):** [SPEC-002-criar-configurar-familia](SPEC-002-criar-configurar-familia.md) (aprovada) — introduz `POST /v1/media` e `GET /v1/media/{mediaId}/content` para `profilePhoto`; [SPEC-007-gerenciar-tarefas](SPEC-007-gerenciar-tarefas.md) (aprovada) — define `FamilyTask` e os estados `pending`/`awaitingConfirmation`/`completed`; [SPEC-006-editar-perfil](SPEC-006-editar-perfil.md) (aprovada) — reutiliza a mídia em edição posterior de perfil.
- **Dependências externas e infraestrutura:** Cloudflare R2 (armazenamento privado de mídia), conforme BA-16. Câmera do dispositivo (captura local antes do upload). Nenhuma dependência de Apple Sign-In, APNs ou serviços externos novos.

## 3. Escopo da Entrega

### 3.1. Dentro do escopo

- `POST /v1/tasks/{taskId}/signals` (`SignalTask`): Kids sinaliza tarefa própria em `pending` da qual é responsável, com `photoMediaId` opcional; transição para `awaitingConfirmation`.
- Consumir `purpose: taskSignal` em `POST /v1/media`, cuja infraestrutura é introduzida por SPEC-002 e reutilizada por SPEC-006. A validação no upload fica restrita ao papel do ator (deve ser Kids); a validação de contexto da tarefa (estado `pending`, titularidade do responsável) acontece no vínculo, em `SignalTask` — não no upload.
- Autorização exclusiva de Kids, isolamento multitenant/entre responsáveis e validação de entrada, desde a Fase 1.
- TEL-041 (recorte "Sinalizar se pendente") e MOD-011 (Sinalizar realização) no mobile.

### 3.2. Fora do escopo (desta spec)

- Fila de confirmações, avaliação da sinalização, confirmar/recusar, leitura da foto pelo Administrador (`GET /kids/signals`, `GET /kids/signals/{signalId}`, `POST /kids/signals/{signalId}/decision`) — `SPEC-013` (UC03).
- Conclusão manual de tarefa Kids e preservação de evidência para auditoria administrativa — já entregue por `SPEC-010`.
- Edição de tarefa `awaitingConfirmation` com `signalResolution` e exclusão removendo a sinalização corrente — já entregues por `SPEC-007` (`MOD-014`).
- Reabertura de tarefa — `SPEC-011`.

### 3.3. Fora de questão (Anti-requisitos / Suposições descartadas)

- Sinalizar não credita peso, não gera progresso parcial e não conclui a tarefa, com ou sem foto (RN23, RNF11).
- Não existe seletor câmera/galeria nesta sinalização: o app abre a câmera diretamente; a ausência de foto nunca impede sinalizar (RN54).
- Kids não sinaliza tarefa da qual não é responsável, tarefa de outro Kids, nem tarefa que já deixou de ser `pending` (RN21, RF24).
- Esta spec não introduz validação de contexto de tarefa no upload de mídia (`POST /v1/media`); toda revalidação de tarefa/titularidade ocorre exclusivamente no vínculo via `SignalTask` (decisão E-01).
- Não há retenção de rascunho local nem gravação offline da sinalização (MA-07): resposta perdida leva à consulta do estado atual, nunca a reenvio automático.
- Administrador e Membro nunca chamam este endpoint; não há variante adulta de sinalização.

## 4. Perfis, Atores e Regras de Autorização (RBAC)

| Perfil | Pode | Não pode | Reação do sistema a tentativa não autorizada |
|---|---|---|---|
| **Kids** | Sinalizar tarefa própria `pending` da qual é responsável, com ou sem foto | Sinalizar tarefa de outro responsável; sinalizar tarefa que não esteja `pending`; sinalizar mais de uma vez enquanto aguarda decisão | `404 RESOURCE_NOT_FOUND` (titularidade/isolamento) / `409 TASK_NOT_PENDING` (estado) |
| **Administrador** | — | Chamar `POST /tasks/{taskId}/signals` (ação exclusiva de Kids) | `403 ACTION_NOT_ALLOWED` / ação ausente na UI |
| **Membro** | — | Idem Administrador | Idem Administrador |

- **Isolamento Multitenant Familiar e de titularidade (RNF06):** tarefa inexistente, pertencente a outra família, **ou da qual o perfil Kids autenticado não é responsável**, respondem igualmente com HTTP `404 Not Found` e código `RESOURCE_NOT_FOUND`, sem distinguir os três casos e sem revelar metadado da tarefa de terceiro — mesmo padrão de titularidade usado em `SPEC-006`/CA-05 para badges de outro membro.
- **RNF07:** a permissão é revalidada no backend a cada chamada, independentemente de a ação estar oculta na UI para Administrador/Membro.

## 5. Contrato de Dados, Interface e Validações

### 5.1. Dicionário de Campos e Validações de Entrada

| Campo (`json_key`) | Tipo | Obrigatório? | Regras de Validação e Limites | Código de Erro | Descrição e Comportamento |
|---|---|---|---|---|---|
| `photoMediaId` (em `POST /tasks/{taskId}/signals`) | uuid | Não | Quando presente, deve referenciar uma `MIDIA` em estado `READY`, pertencente ao titular (perfil Kids autenticado), com `finalidade: TASK_SIGNAL`. Omitido ou `null` envia a sinalização sem foto. | `PHOTO_MEDIA_NOT_READY` / `PHOTO_MEDIA_NOT_OWNED` / `PHOTO_MEDIA_PURPOSE_MISMATCH` | Foto opcional da sinalização (RN54, RF55) |
| `purpose` (em `POST /v1/media`) | enum | Sim | Passa a aceitar `profilePhoto` **e** `taskSignal`. O upload com `purpose: taskSignal` só exige que o ator autenticado tenha papel `kids`; não recebe nem valida `taskId` nesta etapa (decisão E-01) — a amarração à tarefa específica ocorre somente no vínculo via `SignalTask`. | `MEDIA_PURPOSE_NOT_SUPPORTED` (para qualquer valor fora desses dois) | Finalidade declarada do upload |
| arquivo (multipart, em `POST /v1/media`) | binário | Sim | Inalterado em relação a SPEC-002: formato de imagem reconhecível; conversão para JPEG ≤1.600px/≤5MB; metadados removidos (BA-16) | `MEDIA_FORMAT_UNSUPPORTED` / `MEDIA_TOO_LARGE` | Conteúdo da foto a processar e armazenar no R2 |

Campos não reconhecidos em `POST /tasks/{taskId}/signals` são rejeitados com `400 UNKNOWN_FIELD`, sem persistir (convenção §1 dos contratos backend).

### 5.2. Contrato de API Compartilhado

#### `POST /v1/tasks/{taskId}/signals`
- **Autenticação:** Bearer Token de sessão ativa; ator deve ter papel `kids`.
- **Headers específicos:** Nenhum.
- **Payload de entrada:**
```json
{ "photoMediaId": "d4e5f6a7-b8c9-0123-def4-567890abcdef" }
```
`photoMediaId` pode ser omitido para sinalizar sem foto.

- **Resposta de sucesso — `201 Created`:**
```json
{
  "task": {
    "id": "e4f5a6b7-c8d9-0123-4567-89abcdef0123",
    "status": "awaitingConfirmation",
    "title": "Guardar os brinquedos",
    "weight": 2,
    "scheduledDate": "2026-10-07",
    "assigneeIds": ["a1b2c3d4-e5f6-7890-abcd-ef1234567890"]
  },
  "signal": {
    "id": "f6a7b8c9-d0e1-2345-6789-0abcdef12345",
    "signaledAt": "2026-10-07T18:00:00Z",
    "hasPhoto": true
  }
}
```
`signal.id` é a identidade estável da sinalização corrente (`KidsSignal.id`), a mesma que `GET /kids/signals/{signalId}` (SPEC-013) endereçará para avaliação administrativa.

#### Respostas de Erro Padronizadas (RFC 9457)

| HTTP Status | `code` estável | Cenário / Causa |
|---|---|---|
| `400 Bad Request` | `UNKNOWN_FIELD` | Campo não reconhecido no body |
| `401 Unauthorized` | `SESSION_EXPIRED` | Token ausente, inválido ou expirado |
| `403 Forbidden` | `ACTION_NOT_ALLOWED` | Ator autenticado não tem papel `kids` |
| `404 Not Found` | `RESOURCE_NOT_FOUND` | Tarefa indisponível, de outra família, ou da qual o Kids não é responsável |
| `409 Conflict` | `TASK_NOT_PENDING` | Tarefa já `awaitingConfirmation` ou `completed` |
| `422 Unprocessable Entity` | `PHOTO_MEDIA_NOT_READY` / `PHOTO_MEDIA_NOT_OWNED` / `PHOTO_MEDIA_PURPOSE_MISMATCH` | `photoMediaId` ainda processando, de outro titular, ou com finalidade diferente de `TASK_SIGNAL` |
| `429 Too Many Requests` | `RATE_LIMIT_EXCEEDED` | Excesso de requisições por janela |

`POST /v1/media` com `purpose: taskSignal` reaproveita integralmente as respostas de erro já documentadas em SPEC-002 (`413 MEDIA_TOO_LARGE`, `415 MEDIA_FORMAT_UNSUPPORTED`); nenhum código novo é introduzido nesse endpoint.

### 5.3. Estratégia de Concorrência, Idempotência e Falhas

- **Idempotência:** `POST /tasks/{taskId}/signals` não usa `Idempotency-Key`, seguindo a convenção geral (§1 dos contratos): comandos do usuário não são reenviados automaticamente. Resposta perdida leva à consulta de `GET /tasks/{taskId}` (ou `GET /me/tasks`) antes de qualquer nova ação explícita — nunca reenvio automático.
- **Concorrência:** a primeira sinalização válida sobre uma tarefa `pending` vence; uma segunda tentativa (duplo toque, ou corrida com conclusão manual administrativa via SPEC-010) encontra a tarefa fora de `pending` e recebe `409 TASK_NOT_PENDING`, sem criar segunda sinalização.
- **Tratamento de Falhas e Rede Intermitente (RNF12, RNF13):** falha ao enviar a foto opcional informa o problema e permite tentar de novo ou enviar a sinalização sem foto (RF55); falha ao enviar a sinalização em si não é apresentada como sucesso — o app consulta o estado da tarefa antes de permitir nova tentativa (MA-07: sem banco local de negócio nem gravação offline).

## 6. Estados de Domínio e Transições

| Estado De | Evento / Ação | Estado Para | Quem Pode Executar | Regras e Validações | Efeitos Colaterais |
|---|---|---|---|---|---|
| `pending` | `SignalTask` | `awaitingConfirmation` | Kids responsável pela tarefa | Tarefa pertence à família do ator; ator consta em `assigneeIds`; estado atual é `pending` | Cria `KidsSignal` (`signaledBy`, `signaledAt`, `photoURL?`); nenhum crédito, carga ou progresso é afetado (RN23, RNF11) |
| `awaitingConfirmation` | `SignalTask` | — (recusado) | — | Já existe sinalização corrente aguardando decisão | `409 TASK_NOT_PENDING`, nada persiste |
| `completed` | `SignalTask` | — (recusado) | — | Tarefa já concluída (por confirmação, recusa+nova conclusão, ou conclusão manual concorrente) | `409 TASK_NOT_PENDING`, nada persiste |
| `MIDIA.UPLOADING` (`finalidade: TASK_SIGNAL`) | Upload confirmado pelo R2 e verificado | `READY` | Sistema (backend) | Idêntico ao fluxo de `profilePhoto` descrito em SPEC-002 | Mídia torna-se vinculável via `photoMediaId` |

## 7. Critérios de Aceitação (BDD Formal)

- **CA-01: [Fluxo principal — Sinalizar sem foto]**
  - **DADO QUE** um perfil Kids autenticado é responsável por uma tarefa `pending` da própria família,
  - **QUANDO** enviar `POST /v1/tasks/{taskId}/signals` sem `photoMediaId`,
  - **ENTÃO O SISTEMA DEVE** transicionar a tarefa para `awaitingConfirmation` e criar a sinalização,
  - **E** retornar HTTP `201 Created` com `task.status: awaitingConfirmation` e `signal.hasPhoto: false`, sem alterar carga ou progresso. *(UC15 passos 1/3–4; RF23/24, RN23)*

- **CA-02: [Fluxo principal — Sinalizar com foto]**
  - **DADO QUE** o mesmo perfil Kids já fez upload de uma foto própria com `purpose: taskSignal` e recebeu um `mediaId` em estado `READY`,
  - **QUANDO** enviar `POST /v1/tasks/{taskId}/signals` com esse `photoMediaId`,
  - **ENTÃO O SISTEMA DEVE** transicionar a tarefa para `awaitingConfirmation` vinculando a foto à sinalização,
  - **E** retornar HTTP `201 Created` com `signal.hasPhoto: true`, sem creditar peso ou progresso. *(UC15 passo 2; RF23/55, RN54)*

- **CA-03: [Tentativa Não Autorizada — Perfil adulto]**
  - **DADO QUE** o usuário autenticado possui o perfil `Administrador` ou `Membro`,
  - **QUANDO** tentar `POST /v1/tasks/{taskId}/signals`,
  - **ENTÃO O SISTEMA DEVE** rejeitar a operação sem persistir alterações,
  - **E** retornar HTTP `403 Forbidden` com código `ACTION_NOT_ALLOWED`. *(RNF07; Ator: Kids)*

- **CA-04: [Isolamento e titularidade — Tarefa inacessível]**
  - **DADO QUE** a tarefa pertence a outra família, não existe, ou existe na mesma família mas o Kids autenticado não consta em `assigneeIds`,
  - **QUANDO** o Kids tentar sinalizá-la,
  - **ENTÃO O SISTEMA DEVE** responder HTTP `404 Not Found` com código `RESOURCE_NOT_FOUND`,
  - **E** não revelar título, responsáveis ou qualquer metadado da tarefa de terceiro. *(RNF06)*

- **CA-05: [Validação de Estado — Tarefa fora de `pending`]**
  - **DADO QUE** a tarefa já está `awaitingConfirmation` (sinalização anterior ainda não decidida) ou `completed`,
  - **QUANDO** o Kids responsável tentar sinalizá-la novamente,
  - **ENTÃO O SISTEMA DEVE** recusar a transição sem persistir,
  - **E** retornar HTTP `409 Conflict` com código `TASK_NOT_PENDING`. *(RN21, RN23, RF24)*

- **CA-06: [Validação — Mídia inválida]**
  - **DADO QUE** `photoMediaId` referencia uma mídia em `UPLOADING`/`FAILED`, pertencente a outro titular, ou com `finalidade` diferente de `TASK_SIGNAL`,
  - **QUANDO** `POST /v1/tasks/{taskId}/signals` for processado,
  - **ENTÃO O SISTEMA DEVE** recusar com HTTP `422 Unprocessable Entity` e o código específico (`PHOTO_MEDIA_NOT_READY`, `PHOTO_MEDIA_NOT_OWNED` ou `PHOTO_MEDIA_PURPOSE_MISMATCH`),
  - **E** não transicionar a tarefa. *(RNF24)*

- **CA-07: [Resiliência — Falha de upload da foto opcional]**
  - **DADO QUE** o envio da foto a `POST /v1/media` falha por permissão negada, câmera indisponível, cancelamento ou falha de rede,
  - **QUANDO** a criança estiver preparando a sinalização,
  - **ENTÃO O SISTEMA DEVE** permitir repetir a captura ou enviar a sinalização sem foto,
  - **E** não impedir o envio da sinalização nesses casos. *(RF55, RN54)*

- **CA-08: [Resiliência — Resposta perdida na sinalização]**
  - **DADO QUE** a resposta de `POST /v1/tasks/{taskId}/signals` se perde antes de confirmar sucesso ao app,
  - **QUANDO** o cliente mobile detectar timeout ou indisponibilidade,
  - **ENTÃO O SISTEMA DEVE** evitar reenvio automático do comando,
  - **E** o app deve consultar o estado atual da tarefa antes de qualquer nova ação explícita. *(RNF12/13, MA-07)*

### Checklist de Cobertura Obrigatória dos CAs

- [x] Fluxo principal de UC15 coberto (CA-01, CA-02)
- [x] Recusa explícita para perfil sem permissão (CA-03, RNF07)
- [x] Isolamento/titularidade (CA-04, RNF06)
- [x] Estado inválido tratado (CA-05)
- [x] Validação de mídia (CA-06)
- [x] Falha de conexão/upload e preservação de estado (CA-07, CA-08)

## 8. Observabilidade, Métricas e Auditoria

| Evento | Tipo | Gatilho / Condição | Propriedades Registradas | Destino |
|---|---|---|---|---|
| `task_signaled` | Métrica / Analytics | Sinalização criada com sucesso | `taskId`, `familyId`, `signalId`, `hasPhoto` | Analytics |
| `task_signal_denied` | Log de Segurança | Tentativa bloqueada por papel, titularidade ou estado | `requestId`, `actorId`, `code` | Log estruturado |

*Nota de Privacidade e Segurança:* conteúdo de foto, tokens e segredos nunca são registrados em logs ou eventos de telemetria (consistente com backend-architecture.md §14).

## 9. Premissas e Esclarecimentos

### 9.1. Premissas

- **P-01:** a infraestrutura de mídia (`POST /v1/media`, `GET /v1/media/{mediaId}/content`, estados `UPLOADING`/`READY`/`FAILED`/`DELETING`/`DELETED`, limpeza de órfãos após 24h) já existe integralmente por SPEC-002/BA-16; esta spec apenas habilita uma nova `finalidade`.
- **P-02:** `GET /v1/media/{mediaId}/content` para fotos com `finalidade: TASK_SIGNAL` sendo lidas por um Administrador é responsabilidade de autorização da SPEC-013 (UC03), não desta spec — aqui a criança não relê a própria foto pela API após o upload local.

### 9.2. Esclarecimentos e Decisões

| # | Pergunta / Dúvida | Decisão Tomada | Decidido por / Data | Altera a documentação em `docs/`? |
|---|---|---|---|---|
| E-01 | `POST /v1/media` com `purpose: taskSignal` deve validar o contexto da tarefa (`taskId`) já no upload, ou só no vínculo via `SignalTask`? | Alternativa simples: o upload valida somente que o ator tem papel `kids`; toda validação de tarefa/titularidade ocorre no vínculo (`SignalTask`). Sem campo `taskId` em `POST /v1/media`. | Pessoa usuária / 2026-10-07 | Sim — `backend-contracts.md` |
| E-02 | Seria necessário um código `PHOTO_MEDIA_TASK_MISMATCH` para mídia reservada a outra tarefa? | Não aplicável: como E-01 não amarra a mídia a um `taskId` no upload, não há "tarefa errada" para detectar; os três códigos já existentes (`PHOTO_MEDIA_NOT_READY`/`NOT_OWNED`/`PURPOSE_MISMATCH`) cobrem toda a validação necessária. Nenhum código novo introduzido. | Pessoa usuária / 2026-10-07 | Não |
| E-03 | A habilitação de `purpose: taskSignal` exige nova versão de `backend-contracts.md`? | Sim, esta entrega inclui a nova versão do documento (sem reabrir SPEC-006, que permanece válida como registro histórico do que foi entregue naquele momento). | Pessoa usuária / 2026-10-07 | Sim — `backend-contracts.md` |
| E-04 | Formato da resposta de sucesso de `SignalTask`? | `201 Created` com `task` (estado canônico) e `signal` (`id`, `signaledAt`, `hasPhoto`); `signal.id` é o identificador que SPEC-013 usará em `GET /kids/signals/{signalId}`. | Pessoa usuária / 2026-10-07 | Não |
| E-05 | Código de erro quando o Kids não é responsável pela tarefa? | `404 RESOURCE_NOT_FOUND`, igual ao caso de outra família — mesmo padrão de titularidade de SPEC-006/CA-05, sem distinguir os casos para não revelar a existência da tarefa a um perfil sem acesso. | Pessoa usuária / 2026-10-07 | Não |

*Regra:* Como E-01 e E-03 alteram `docs/architecture/backend-contracts.md`, essa atualização é parte desta entrega (seção 11, antes da aprovação final).

## 10. Fases de Implementação e Critérios de Conclusão

| Fase | Objetivo da Entrega | Critérios de Aceite Atendidos | Critério de Prontidão (Definition of Done) | Status |
|---|---|---|---|---|
| **1** | **Núcleo Mínimo (API + RBAC + Isolamento):** `SignalTask`, habilitação de `purpose: taskSignal`, transição de estado, validações de titularidade/mídia. | CA-01 a CA-06 | Testes unitários e de integração verdes cobrindo os CAs listados; `backend-contracts.md` atualizado. | a fazer |
| **2** | **Experiência Mobile:** TEL-041/MOD-011 integrados, câmera direta, revisar/refazer/descartar. | CA-01, CA-02, CA-07 | Telas integradas com a API; UX-spec verificada; testes de UI verdes. | a fazer |
| **3** | **Resiliência e Observabilidade:** falhas de rede/upload e telemetria. | CA-08 | Suíte de regressão verde; eventos `task_signaled`/`task_signal_denied` emitidos. | a fazer |

- **Fora da Fase 1:** a interface mobile (botão Sinalizar/MOD-011) pertence à Fase 2 e está integrada nesta entrega; a validação visual específica permanece pendente.
- **Pode ser publicada de forma independente em produção?** Fase 1: não (sem UI, sem valor percebido). Fase 2: sim, desde que SPEC-013 ainda não exista — a tarefa fica em `awaitingConfirmation` sem fila administrativa visível até SPEC-013 ser entregue; isso é aceitável como entrega intermediária, mas a família só completa o ciclo depois de SPEC-013.

## 11. Checklist de Aprovação da Spec (Definition of Ready)

- [x] Todos os códigos citados (`RN`, `RF`, `RNF`, `UC`, `TEL`, `MOD`, `UF`) existem na base funcional vigente (1.13).
- [x] A rastreabilidade técnica (`MA-..`, `BA-..`) está alinhada com as diretrizes de arquitetura.
- [x] O contrato de API compartilhado está completo e sem ambiguidades, incluindo a extensão de `POST /v1/media`.
- [x] O dicionário de campos define tipos, limites e códigos de erro estáveis.
- [x] Todo critério de aceitação segue o padrão formal BDD.
- [x] Isolamento entre famílias/titularidade (RNF06) e recusa por perfil (RNF07) constam explicitamente na Fase 1.
- [x] Esclarecimentos E-01 a E-05 decididos; nenhuma premissa sem validação pendente.
- [x] UX-spec vinculada (UX-012).
- [x] A seção "Fora de questão" elimina riscos de suposições incorretas.
- [x] `docs/architecture/backend-contracts.md` atualizado para versão 1.8, refletindo E-01/E-03.
- [x] Status `aprovada` autorizado pela pessoa usuária em 2026-10-07.
