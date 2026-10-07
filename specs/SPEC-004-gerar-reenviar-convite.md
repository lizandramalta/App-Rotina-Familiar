# Spec 004: Gerar e reenviar convite

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06  
**Base funcional:** 1.14\
**UX-spec:** [UX-004-gerar-reenviar-convite.md](UX-004-gerar-reenviar-convite.md)  
**Projetos envolvidos:** ambos  
**Tema do backlog:** Tema 1 - Acesso, família e perfis

## 1. Contexto e objetivo

- **Problema / necessidade:** um perfil criado para um integrante da família não recebe sessão automaticamente. Um Administrador precisa gerar as credenciais de ingresso e, quando necessário, recuperar o acesso ao mesmo perfil ativo sem duplicar histórico ou vínculos.
- **Objetivo da entrega:** permitir que um Administrador emita ou reemita, após confirmação explícita dos efeitos, um novo link e senha para um perfil elegível da própria família, disponibilizando-os juntos apenas pela folha de compartilhamento do sistema.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Caso de uso | UC02 (recorte: gerar e reenviar convite), UC01 (emissão inicial no onboarding) |
| Regras de negócio | RN01, RN06, RN07, RN45–RN47 |
| Requisitos funcionais | RF02, RF38, RF40, RF41, RF54 |
| Requisitos não funcionais | RNF05–RNF08, RNF12–RNF14, RNF17–RNF22 |
| Telas e fluxos | TEL-032, TEL-034, TEL-050, TEL-056, UF-01, UF-12 |
| Decisões arquiteturais | MA-07–MA-11, MA-15; BA-07–BA-10, BA-20 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-architecture.md`, `docs/architecture/mobile-feature-catalog.md`, `docs/architecture/mobile-decisions.md`, `docs/architecture/backend-architecture.md`, `docs/architecture/backend-contracts.md` e `docs/architecture/backend-decisions.md`.
- **Depende de:** [SPEC-003-gerenciar-membros.md](SPEC-003-gerenciar-membros.md), aprovada. Ela cria o perfil sem sessão e disponibiliza o detalhe de membro que inicia esta jornada.
- **Dependências externas e infraestrutura:** sessão própria do backend, geração criptograficamente segura de credenciais e folha de compartilhamento nativa de iOS/iPadOS. Esta entrega não envia mensagem, e-mail ou notificação por servidor.

## 3. Escopo da entrega

### 3.1. Dentro do escopo

- Emitir convite inicial ou reemitir convite para perfil ativo existente que não seja o Criador, pelo comando `IssueMemberInvite`.
- Confirmar visualmente, antes da emissão, que um novo link e senha substituirão todos os convites anteriores ainda disponíveis e revogarão a sessão anterior daquele perfil.
- Criar link e senha novos, sem expiração temporal, e persistir apenas seus verificadores protegidos.
- Revogar em uma única operação os convites disponíveis anteriores e a sessão ativa anterior do perfil, sem recriar ou alterar o perfil, seu histórico, suas tarefas ou vínculos.
- Entregar as credenciais transitórias apenas como conteúdo único da folha de compartilhamento do sistema, contendo link e senha juntos.
- Permitir que TEL-056 inicie a mesma emissão inicial imediatamente após a criação de um membro, sempre por ação explícita e sem criar uma variante de contrato.
- Tratar autorização, isolamento familiar, concorrência, resposta perdida, auditoria sem segredos e falhas de dependência.

### 3.2. Fora do escopo

- Criar, editar, mudar papel ou remover membro: `SPEC-003`.
- Inspecionar, abrir, validar senha, consumir convite, criar sessão, trocar o acesso local ou recuperar ingresso com resposta perdida: `SPEC-005`.
- Enviar e-mail, SMS, mensagem de WhatsApp, push ou qualquer compartilhamento automático pelo backend.
- Copiar link/senha separadamente, exibir uma lista de destinos de envio própria ou persistir localmente as credenciais após a folha de compartilhamento ser fechada.
- Recuperar senha ou revelar novamente um link/senha já emitidos.

### 3.3. Fora de questão

- A criação do perfil não emite convite automaticamente; emissão e reemissão continuam comandos explícitos e separados.
- O Criador não recebe convite e recupera acesso exclusivamente por Sign in with Apple.
- Link e senha não são login permanente; cada conjunto aceita somente um ingresso bem-sucedido, tratado pela `SPEC-005`.
- A confirmação na interface não substitui a autorização no backend, e a posse de `memberId` não autoriza operar outra família.
- Não há retry automático de emissão nem operação geral de idempotência para recuperar uma senha cuja resposta se perdeu.

## 4. Perfis, atores e regras de autorização

| Perfil / situação | Pode | Não pode | Reação a tentativa não autorizada |
|---|---|---|---|
| Administrador da família | Emitir ou reemitir convite para outro perfil ativo e elegível da própria família | Emitir para Criador, removido ou outra família | `409 INVITE_NOT_ISSUABLE` para estado inelegível; ação só aparece quando a capacidade estiver presente |
| Membro | Consultar o detalhe quando permitido por UC11 | Emitir ou reenviar convite | `403 ACTION_NOT_ALLOWED`; ação oculta |
| Kids | Nenhuma capacidade desta entrega | Acessar detalhe adulto ou emitir convite | `403 ACTION_NOT_ALLOWED`; sem entrada visual |
| Criador como alvo | Retornar por Apple | Receber ou recuperar acesso por convite | `409 INVITE_NOT_ISSUABLE`; ação não apresentada |
| Membro removido como alvo | — | Receber novo convite ou sessão | `404 RESOURCE_NOT_FOUND`; sem revelar estado além do necessário |
| Recurso de outra família | — | Ser consultado ou receber convite | `404 RESOURCE_NOT_FOUND`, sem dados ou metadados |

- **Isolamento familiar (RNF06):** a família vem exclusivamente da sessão ativa. A busca por `memberId` aplica o escopo familiar do ator, de modo que alvo externo é indistinguível de inexistente.
- **Autorização (RNF07):** o backend valida sessão ativa, papel de Administrador, perfil ativo do alvo e proteção do Criador antes da escrita e novamente depois do lock transacional. A ação oculta no app é apenas proteção de experiência.
- **Revogação (RN46, RN47, RNF22):** a emissão confirmada revoga imediatamente a sessão anterior do alvo; falha de rede, cancelamento da confirmação ou cancelamento da folha de compartilhamento não revogam por si só uma sessão.

## 5. Contrato de dados, interface e validações

### 5.1. Dicionário de campos

| Campo | Local | Tipo | Obrigatório | Validação | Comportamento |
|---|---|---|---:|---|---|
| `memberId` | parâmetro de rota | UUID | Sim | Identifica perfil ativo e elegível da família da sessão | Não pode identificar Criador, removido ou membro de outra família |
| `inviteId` | resposta | UUID | Sim | Gerado pelo servidor | Identifica a emissão; não recupera credenciais |
| `link` | resposta transitória | URL | Sim | Token opaco gerado pelo backend | Não é persistido em texto legível nem registrado |
| `password` | resposta transitória | string | Sim | Senha independente e imprevisível gerada pelo backend | Não é persistida em texto legível, nem é recuperável |

O comando não aceita corpo. Campos enviados no corpo, incluindo `familyId`, papel, estado, link, senha, token ou flag de Criador, recebem `400 UNKNOWN_FIELD`.

### 5.2. Endpoint

- **Método e rota:** `POST /v1/family/members/{memberId}/invites`
- **Caso de uso de aplicação:** `IssueMemberInvite`
- **Autenticação:** `Authorization: Bearer <accessToken>` e prova privada da instalação exigida pela sessão.
- **Entrada:** sem corpo; `memberId` na rota.
- **Sucesso:** `201 Created`, `Cache-Control: no-store` e credenciais transitórias.

```json
{
  "inviteId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "link": "https://example.invalid/invite/opaque-token",
  "password": "transient-password"
}
```

A resposta só é utilizada na memória necessária para abrir a folha de compartilhamento nativa. Seu único conteúdo de compartilhamento reúne link e senha; o app não oferece cópia individual, armazenamento local ou consulta posterior.

Todos os erros usam `application/problem+json` com `type`, `title`, `status`, `code`, `requestId` e, quando aplicável, `fieldErrors`.

| HTTP | Código | Situação |
|---:|---|---|
| 400 | `UNKNOWN_FIELD` | Corpo ou campo protegido não permitido |
| 401 | `SESSION_INVALID` | Credencial inválida, expirada ou sessão revogada |
| 403 | `ACTION_NOT_ALLOWED` | Ator autenticado sem papel Administrador |
| 404 | `RESOURCE_NOT_FOUND` | Alvo ausente, removido ou de outra família |
| 409 | `INVITE_NOT_ISSUABLE` | Alvo é Criador ou o estado atual não permite emissão |
| 429 | `RATE_LIMITED` | Proteção contra emissão ou tentativas abusivas aplicada |
| 503 | `DEPENDENCY_UNAVAILABLE` | Persistência ou gerador de credenciais indisponível; resultado pode ser incerto |

### 5.3. Concorrência e falhas

- Não há `Idempotency-Key`, replay automático ou recuperação de senha. Cada nova ação confirmada gera um conjunto novo de credenciais.
- A emissão usa transação curta, serializada por família, com revalidação do ator e alvo. Em cada emissão confirmada, os convites disponíveis anteriores e a sessão anterior do alvo são revogados no mesmo commit antes de o novo convite ficar disponível.
- Se a resposta for perdida, o mobile não mostra sucesso e não reenvia automaticamente. Não existe rota que reconstrua a senha; nova emissão exige confirmação explícita e substitui qualquer conjunto que possa ter sido criado.
- Nenhum token, senha, link, hash, cabeçalho de instalação ou conteúdo da folha de compartilhamento entra em logs, auditoria ou telemetria.

## 6. Estados de domínio e transições

| Estado de | Evento | Estado para | Autor | Garantias |
|---|---|---|---|---|
| Perfil ativo sem convite disponível | Emitir convite | Novo convite `available` | Administrador | Link e senha novos; perfil e histórico preservados |
| Convite `available` e eventual sessão ativa | Emitir ou reemitir convite | Convite anterior `invalidated`, sessão anterior revogada e novo convite `available` | Administrador | Uma única operação consistente; novas credenciais são transitórias |
| Convite `available` | Ingresso bem-sucedido (SPEC-005) | `consumed` | Pessoa convidada | Fora desta entrega; não pode ser reutilizado |
| Perfil Criador, removido ou fora do escopo familiar | Tentar emitir convite | Sem alteração | Administrador ou ator indevido | Recusa sem criação de credencial nem exposição de dados |

## 7. Critérios de aceitação

- **CA-01: emissão inicial para perfil elegível**
  - **DADO QUE** um Administrador possui sessão ativa e um perfil ativo não-Criador existe em sua família,
  - **QUANDO** confirmar `POST /v1/family/members/{memberId}/invites`,
  - **ENTÃO O SISTEMA DEVE** criar um novo convite disponível com link e senha inéditos,
  - **E** responder `201 Created` com credenciais transitórias, sem recriar o perfil, seu histórico, tarefas ou vínculos. *(UC02, RF40, RF41, RN45–RN46)*

- **CA-02: reemissão revoga credenciais e sessão anteriores**
  - **DADO QUE** o perfil elegível possui convite disponível e/ou sessão ativa anterior,
  - **QUANDO** um Administrador confirmar nova emissão,
  - **ENTÃO O SISTEMA DEVE** invalidar os convites disponíveis anteriores e revogar a sessão anterior do perfil na mesma operação que cria as novas credenciais,
  - **E** manter o perfil, a família, o histórico e os vínculos existentes. *(UC02, RF41, RF54, RN46–RN47, RNF22)*

- **CA-03: autorização e isolamento familiar**
  - **DADO QUE** um Membro, Kids ou Administrador de outra família tenta emitir um convite,
  - **QUANDO** enviar o comando protegido,
  - **ENTÃO O SISTEMA DEVE** recusar Membro/Kids com `403 ACTION_NOT_ALLOWED` e alvo externo com `404 RESOURCE_NOT_FOUND`,
  - **E** não DEVE criar convite, revogar sessão ou revelar dados de outra família. *(RN07, RNF06, RNF07)*

- **CA-04: alvo inelegível não recebe credenciais**
  - **DADO QUE** o `memberId` corresponde ao Criador, a perfil removido ou a estado inelegível,
  - **QUANDO** um Administrador tentar emitir ou reenviar convite,
  - **ENTÃO O SISTEMA DEVE** manter o estado atual sem gerar credenciais,
  - **E** responder com `409 INVITE_NOT_ISSUABLE` para Criador/estado inelegível ou `404 RESOURCE_NOT_FOUND` para perfil removido. *(RN05, RN45, RN47)*

- **CA-05: credenciais protegidas e transitórias**
  - **DADO QUE** uma emissão é confirmada,
  - **QUANDO** o backend gerar link e senha,
  - **ENTÃO O SISTEMA DEVE** gerar valores imprevisíveis e persistir somente verificadores protegidos,
  - **E** devolver as credenciais somente na resposta `no-store`, sem registrá-las, armazená-las localmente ou permitir recuperação posterior. *(RN46, RF54, RNF17)*

- **CA-06: concorrência preserva um único convite utilizável**
  - **DADO QUE** duas emissões para o mesmo perfil são confirmadas concorrentemente,
  - **QUANDO** os comandos forem processados,
  - **ENTÃO O SISTEMA DEVE** serializar e revalidar cada transação,
  - **E** manter no fim no máximo um convite disponível e nenhuma sessão anterior ativa. *(RN46, RNF21, BA-08–BA-10)*

- **CA-07: resposta incerta não inventa sucesso**
  - **DADO QUE** a emissão perde a resposta ou retorna indisponibilidade após o envio,
  - **QUANDO** o mobile não puder confirmar o resultado,
  - **ENTÃO O SISTEMA NÃO DEVE** exibir link, senha ou confirmação de compartilhamento,
  - **E** DEVE preservar o contexto do membro e exigir nova confirmação explícita para outra emissão, que substituirá qualquer emissão anterior eventualmente persistida. *(RNF12–RNF13, MA-08, BA-07)*

- **CA-08: compartilhamento nativo único e explícito**
  - **DADO QUE** a emissão retorna credenciais confirmadas,
  - **QUANDO** TEL-034 apresentar a folha de compartilhamento do sistema,
  - **ENTÃO O APP DEVE** fornecer link e senha no mesmo conteúdo de compartilhamento,
  - **E** NÃO DEVE oferecer cópia individual, destinos próprios, envio automático ou persistência das credenciais após o fechamento da folha. *(RF41, RF54; decisão E-01 desta spec)*

## 8. Observabilidade e auditoria

| Evento | Gatilho | Dados permitidos |
|---|---|---|
| `member_invite_issued` | Emissão confirmada | `familyId`, `memberId`, `inviteId`, ator e instante |
| `member_invite_issue_denied` | Emissão recusada | `requestId`, ator, rota e motivo técnico sem segredo |
| `member_invite_issue_uncertain` | Resposta ausente ou dependência indisponível | `requestId`, rota e classificação de falha |

Token, senha, link, hashes, cabeçalhos de instalação e conteúdo compartilhado nunca são eventos ou campos de log.

## 9. Premissas e decisões

| # | Decisão | Origem | Altera `docs/`? |
|---|---|---|---|
| E-01 | Após emissão confirmada, o único meio de entrega é a folha de compartilhamento nativa, com link e senha no mesmo conteúdo; não há cópia individual nem canal próprio. | Pessoa usuária, 2026-10-06 | Não — define apresentação da entrega, coerente com compartilhamento explícito previsto em RF41/RF54 |
| E-02 | A resposta de emissão usa `inviteId`, `link` e `password`, alinhada ao tipo `InviteCredentials`; o comando não recebe corpo. | Modelo de classes e contrato backend | Não |
| E-03 | O onboarding pode iniciar a emissão logo após criar o membro, mas não a executa automaticamente; cancelar o compartilhamento não remove o membro nem impede avançar. | Pessoa usuária / 2026-10-07 | Não — concretiza RF41 e UC01. |

Não há esclarecimentos pendentes para este recorte.

## 10. Fases de implementação e conclusão

| Fase | Objetivo | CAs | Prontidão | Status |
|---|---|---|---|---|
| 1 | Emissão segura: endpoint, geração protegida, transação de revogação, RBAC, isolamento e tratamento de falhas | CA-01 a CA-07 | Testes unitários e de integração verdes, incluindo concorrência e ausência de segredos em logs | a fazer |
| 2 | Jornada mobile: entrada autorizada, confirmação, folha nativa de compartilhamento e estados de erro | CA-07, CA-08 | Testes de UI e integração verdes; UX-spec verificada em iPhone e iPad | a fazer |
| 3 | Regressão e auditoria | CA-02, CA-05 a CA-08 | Regressão de sessão revogada, resposta incerta, acessibilidade e telemetria segura concluída | a fazer |

- **Fase 1:** não expõe o botão de emissão no app antes de a transação segura existir. Pode ser publicada somente junto à experiência mínima da Fase 2, pois credenciais não têm canal de entrega alternativo.
- **Fase 2:** não implementa ingresso, troca de acesso ou recuperação de resposta perdida do ingresso; esses comportamentos pertencem à `SPEC-005`.
- **Fase 3:** não acrescenta regra funcional; reforça cobertura, diagnóstico e acessibilidade.

## 11. Checklist de aprovação

- [x] Códigos funcionais, de UX e arquiteturais pesquisados e existentes.
- [x] Dependência `SPEC-003` validada como aprovada.
- [x] Autorização, isolamento, geração protegida e revogação fazem parte da primeira fase.
- [x] Contrato, falha incerta e ausência de recuperação de senha definidos.
- [x] UX-spec vinculada e decisão de compartilhamento nativo registrada.
- [x] Sem alteração necessária na base funcional em `docs/`.
- [x] Status autorizado explicitamente como `aprovada` pela pessoa usuária em 2026-10-06.
