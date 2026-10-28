# Spec 003: Gerenciar membros

**Status:** aprovada\
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-19
**Base funcional:** RN 1.26 / RF 1.25 / UC 1.25\
**UX-spec:** [UX-003-gerenciar-membros.md](UX-003-gerenciar-membros.md)  
**Projetos envolvidos:** ambos  
**Tema do backlog:** Tema 1 - Acesso, família e perfis

## 1. Contexto e objetivo

- **Problema / necessidade:** membros iniciais já podem nascer com a família em SPEC-002; após a criação, Administradores precisam incluir outros e manter os perfis sem conceder gestão indevida, expor dados entre famílias ou perder histórico.
- **Objetivo da entrega:** permitir que um Administrador crie, consulte e administre perfis da própria família — inclusive papel, modo Kids e remoção — preservando as proteções do Criador, a revogação de acesso e os vínculos históricos.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Caso de uso | UC02 (recorte: criação e gestão de membro; sem emissão de convite), UC01 (reuso no onboarding) |
| Regras de negócio | RN01–RN08, RN10 |
| Requisitos funcionais | RF02–RF06, RF38, RF40 |
| Requisitos não funcionais | RNF01, RNF05–RNF09, RNF12–RNF14, RNF22 |
| Telas e fluxos | TEL-002 (retorno em edição), TEL-030 (saída da administração), TEL-032, TEL-033, TEL-050, TEL-057, MOD-010, UF-01, UF-12 |
| Decisões arquiteturais | MA-07–MA-11, MA-15, MA-18; BA-07, BA-08, BA-10, BA-20, BA-36 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-feature-catalog.md`, `docs/architecture/mobile-decisions.md`, `docs/architecture/backend-contracts.md` e `docs/architecture/backend-decisions.md`.
- **Depende de:** [SPEC-002-criar-configurar-familia.md](SPEC-002-criar-configurar-familia.md), aprovada na revisão de 2026-10-19. A sessão criada para o Criador delimita a família e o ator das operações persistentes desta entrega.
- **Dependências externas e infraestrutura:** sessão própria do backend, banco transacional e prova de instalação já previstos para sessões. Não depende de Sign in with Apple, geração de convite ou envio externo nesta entrega.

## 3. Escopo da entrega

### 3.1. Dentro do escopo

- Consultar a projeção de membros e o detalhe administrativo da própria família, para adultos, em `GET /v1/family/members` e `GET /v1/family/members/{memberId}`.
- Criar, por Administrador, perfil sem sessão nos papéis `administrator`, `member` ou `kids` depois que a família existir, inclusive se o Criador retornar de TEL-056 a TEL-002 e adicionar novo membro.
- Corrigir exclusivamente o nome administrativo de perfil Kids da própria família; adultos alteram o próprio nome em Meu perfil (SPEC-006). Apelido, foto e identidade Apple continuam fora do comando administrativo.
- Alterar papel entre `administrator`, `member` e `kids`, aplicando as restrições de Criador e de modo Kids.
- Permitir que Administrador que não seja Criador deixe a administração e se torne Membro.
- Remover logicamente membro que não seja Criador, revogar seu acesso e ajustar, de forma consistente, somente suas responsabilidades futuras não concluídas e não protegidas.
- Expor criação em TEL-033, correção de nome Kids em TEL-057 ou TEL-032 e ações de papel, convite e remoção em TEL-032 somente quando a capacidade confirmada do ator permitir.

### 3.2. Fora do escopo

- Gerar, reenviar, visualizar ou compartilhar link e senha de convite: `SPEC-004`.
- Inspecionar, consumir ou recuperar ingresso por convite: `SPEC-005`.
- Editar apelido, foto, badges ou outros dados pessoais do titular: `SPEC-006`.
- Consulta e detalhes das tarefas de um membro; TEL-032 apenas preserva o ponto de entrada e o contexto visual necessários à gestão. A capacidade funcional de tarefas é entregue nas specs de tarefas.
- Remoção física, transferência de histórico, troca de família ou reativação de membro removido.
- Preparação em rascunho e criação atômica dos membros iniciais com a família: SPEC-002.

### 3.3. Fora de questão

- Criar perfil **não** emite convite, credencial nem sessão automaticamente.
- `kids` é um valor de `role`; não há um campo adicional `kidsMode` que possa divergir do papel.
- Nenhuma operação aceita `familyId`, `isFamilyCreator`, `nickname`, `photoMediaId`, identidade Apple, sessão, convite ou crédito como entrada alterável.
- Um perfil removido não volta a ter acesso por refresh, sessão anterior ou convite antigo.
- Ocultar ação no mobile não substitui a autorização no backend.

## 4. Perfis, atores e regras de autorização

| Perfil / situação | Pode | Não pode | Reação a tentativa não autorizada |
|---|---|---|---|
| Administrador não-Criador | Gerir membros da própria família, corrigir nome de Kids; deixar a própria administração | Gerir outra família; editar nome de outro adulto, foto/apelido de terceiros; alterar o Criador; emitir convite nesta spec | `403 ACTION_NOT_ALLOWED` ou `404 RESOURCE_NOT_FOUND`; ação oculta quando a projeção já permite saber a restrição |
| Criador / Administrador | Gerir outros membros da própria família | Ser removido, rebaixado ou deixar a administração | `409 MEMBER_STATE_CONFLICT`; ação não é apresentada |
| Membro | Consultar lista e detalhe permitidos a adultos | Criar, editar, mudar papel/modo ou remover membro | `403 ACTION_NOT_ALLOWED`; controles ocultos |
| Kids | Nenhuma capacidade desta entrega | Acessar Família ou gerir membros | `403 ACTION_NOT_ALLOWED`; sem entrada visual |
| Recurso de outra família | — | Ser consultado ou alterado | `404 RESOURCE_NOT_FOUND`, sem revelar dados ou metadados |

- **Isolamento familiar (RNF06):** a família é derivada da sessão ativa. Cada consulta por `memberId` adiciona o escopo da família do ator; um recurso externo é indistinguível de inexistente.
- **Autorização (RNF07):** o backend valida sessão ativa, perfil não removido, família, papel e proteção do Criador antes da escrita e novamente após eventual espera por lock.
- **Revogação (RN10, RNF22):** remoção revoga a sessão antes usada pelo perfil e impede renovação posterior; falha de rede não é, por si, revogação.

## 5. Contrato de dados, interface e validações

### 5.1. Dicionário de campos

| Campo JSON | Tipo | Obrigatório | Validação | Erro de campo |
|---|---|---:|---|---|
| `name` | string | Sim em criação; opcional em edição | Após `trim`, 1–60 caracteres Unicode visíveis; sem caracteres de controle | `MEMBER_NAME_REQUIRED`, `MEMBER_NAME_INVALID_LENGTH`, `MEMBER_NAME_INVALID_CONTENT` |
| `role` | enum | Sim em criação e transição | `administrator`, `member` ou `kids`; transição deve respeitar RN02, RN03, RN05 e RN08 | `MEMBER_ROLE_INVALID`, `MEMBER_ROLE_TRANSITION_NOT_ALLOWED` |
| `memberId` | UUID de rota | Sim quando aplicável | Deve identificar membro ativo da família da sessão | — |

`name` é administrativo e distinto de `nickname`; `nickname` e `photoMediaId` não pertencem a esta API. Campos desconhecidos ou protegidos recebem `400 UNKNOWN_FIELD`.

### 5.2. Endpoints

Todas as rotas usam `/v1`, HTTPS, JSON em inglês, `Authorization: Bearer <accessToken>` e a prova privada de instalação exigida pelo contrato de sessão. Credenciais e provas nunca são registradas em logs.

| Método e rota | Caso de uso | Acesso | Entrada | Resultado confirmado |
|---|---|---|---|---|
| `GET /family/members` | `ListFamilyMembers` | Adulto | `cursor` opaco opcional | `{ items, nextCursor }` da própria família, em páginas de até 20 perfis |
| `GET /family/members/{memberId}` | `GetMemberDetail` | Adulto da família | `memberId` na rota | Dados públicos do perfil e capacidades administrativas do ator |
| `POST /family/members` | `CreateMember` | Administrador | `name`, `role` | `201 Created` e projeção do perfil, ainda sem sessão/convite |
| `PATCH /family/members/{memberId}` | `UpdateMember` | Administrador; alvo Kids | `name` | `200 OK` e projeção confirmada |
| `POST /family/members/{memberId}/role-changes` | `ChangeMemberRole` | Administrador | `role` | `200 OK` e projeção confirmada |
| `POST /me/administration-exit` | `LeaveAdministration` | Administrador não-Criador | Sem corpo | `200 OK` e sessão/projeção com papel `member` |
| `DELETE /family/members/{memberId}` | `RemoveMember` | Administrador; alvo não-Criador | Sem corpo | `204 No Content` após a remoção lógica e seus efeitos confirmados |

Exemplo de criação ou mudança de papel:

```json
{
  "name": "Marina Silva",
  "role": "member"
}
```

Uma projeção de membro contém, no mínimo, `id`, `name`, `role`, `isFamilyCreator` e `createdAt`. Ela não devolve credenciais, hashes, token Apple, apelido configurável ou foto privada.

### 5.3. Erros, concorrência e falhas

Todos os erros usam `application/problem+json` com `type`, `title`, `status`, `code`, `requestId` e `fieldErrors` quando aplicável.

| HTTP | Código | Situação |
|---:|---|---|
| 400 | `UNKNOWN_FIELD` | Campo não reconhecido ou protegido, inclusive `familyId`, `isFamilyCreator`, apelido ou foto |
| 401 | `SESSION_INVALID` | Credencial inválida, expirada ou sessão revogada |
| 403 | `ACTION_NOT_ALLOWED` | Ator sem capacidade administrativa ou tentativa de editar nome de adulto por esta rota |
| 404 | `RESOURCE_NOT_FOUND` | Membro ausente, removido ou de outra família |
| 409 | `MEMBER_STATE_CONFLICT` | Estado atual impede a operação, inclusive proteção do Criador ou mudança incompatível com o estado atual |
| 422 | `VALIDATION_FAILED` | Nome, papel ou cursor semanticamente inválidos; inclui `fieldErrors` (`CURSOR_INVALID` para cursor opaco malformado) |
| 503 | `DEPENDENCY_UNAVAILABLE` | Persistência ou dependência indisponível; não afirmar reversão de escrita incerta |

- **Concorrência:** aplica-se última gravação válida persistida para edição de nome. Mudanças de papel e remoção usam transação curta, lock por família e revalidação das invariantes no commit (BA-07, BA-08).
- **Falhas:** POST/PATCH/DELETE não são reenviados automaticamente. Diante de resposta perdida, o mobile consulta o estado confirmado antes de oferecer nova ação; não apresenta sucesso antecipadamente e preserva a digitação ainda não confirmada (RNF12–13, MA-08).
- **Remoção:** “futuras” significa data posterior a hoje no fuso da família. Responsabilidades de tarefas futuras não concluídas e não protegidas são atualizadas sem remover os demais responsáveis; histórico, pendências antigas, conclusões e dados protegidos são preservados.

## 6. Estados de domínio e transições

| Estado de | Evento | Estado para | Autor | Garantias |
|---|---|---|---|---|
| Perfil ativo sem sessão | Criar perfil | Perfil ativo sem sessão | Administrador | Sem convite ou credencial; pertence somente à família da sessão |
| `member` | Mudar para `administrator` | `administrator` | Administrador | Permitido apenas para adulto; não há Kids Administrador |
| `administrator` não-Criador | Rebaixar ou deixar a administração | `member` | Administrador / próprio titular | Criador não participa desta transição |
| `kids` | Mudar para `member` | `member` | Administrador | Necessário antes de promover a Administrador |
| `member` ou `administrator` não-Criador | Mudar para `kids` | `kids` | Administrador | Administrador não pode permanecer Kids; a transição efetiva é para `kids` |
| Perfil ativo não-Criador | Remover | Perfil removido | Administrador | Sessão revogada; histórico preservado; responsabilidades futuras elegíveis ajustadas |

## 7. Critérios de aceitação

- **CA-01: criação autorizada de perfil**
  - **DADO QUE** um Administrador possui sessão ativa na família,
  - **QUANDO** enviar `POST /v1/family/members` com `name` válido e `role` permitido,
  - **ENTÃO O SISTEMA DEVE** criar o perfil exclusivamente na família da sessão,
  - **E** responder `201 Created` com a projeção canônica, sem sessão, convite ou credencial. *(UC02, RF02, RF40, RN07)*

- **CA-02: validação do nome e do papel**
  - **DADO QUE** um Administrador cria um perfil ou corrige o nome de um perfil Kids,
  - **QUANDO** enviar nome vazio, fora de 1–60 caracteres visíveis, com caractere de controle, ou papel fora do enum,
  - **ENTÃO O SISTEMA DEVE** rejeitar a persistência com `422 VALIDATION_FAILED`,
  - **E** devolver o erro de campo estável correspondente. *(RF02, RF03, RF40)*

- **CA-03: autorização e isolamento familiar**
  - **DADO QUE** um Membro, Kids ou Administrador de outra família tenta gerir um perfil,
  - **QUANDO** executar qualquer comando ou consulta protegida,
  - **ENTÃO O SISTEMA DEVE** recusar Membro/Kids com `403 ACTION_NOT_ALLOWED` e recurso externo com `404 RESOURCE_NOT_FOUND`,
  - **E** não persistir nem revelar dados de outra família. *(RN07, RNF06, RNF07)*
  - **E** negar com `403 ACTION_NOT_ALLOWED` a tentativa de Administrador corrigir o nome de outro adulto; adultos usam o próprio perfil. *(RF03, RF48)*

- **CA-04: papel, modo Kids e Criador protegido**
  - **DADO QUE** um Administrador muda o papel de um perfil,
  - **QUANDO** promover Kids sem antes torná-lo Membro, tentar manter uma configuração incompatível de Administrador e Kids, ou rebaixar o Criador,
  - **ENTÃO O SISTEMA DEVE** manter o estado vigente e responder `409 MEMBER_STATE_CONFLICT`,
  - **E** permitir somente as transições previstas em RN02, RN03 e RN08. *(RF03, RF05, RF06)*

- **CA-05: saída voluntária da administração**
  - **DADO QUE** um Administrador não-Criador possui sessão ativa,
  - **QUANDO** confirmar `POST /v1/me/administration-exit`,
  - **ENTÃO O SISTEMA DEVE** alterar seu papel para `member` e devolver o estado confirmado,
  - **E** impedir a mesma ação para o Criador com `409 MEMBER_STATE_CONFLICT`. *(RN04, RN05, RF05)*

- **CA-06: remoção preserva histórico e revoga acesso**
  - **DADO QUE** um Administrador remove outro membro não-Criador,
  - **QUANDO** a remoção for confirmada,
  - **ENTÃO O SISTEMA DEVE** revogar a sessão e impedir renovação de acesso do perfil removido,
  - **E** retirar somente esse perfil das responsabilidades futuras não concluídas e não protegidas, preservando histórico, tarefas antigas e os demais responsáveis. *(RN10, RF04, RNF09, RNF22)*

- **CA-07: resultado incerto não simula sucesso**
  - **DADO QUE** uma escrita de membro perde a resposta ou a dependência fica indisponível,
  - **QUANDO** o mobile não puder confirmar a persistência,
  - **ENTÃO O SISTEMA NÃO DEVE** mostrar a alteração como salva,
  - **E** DEVE preservar o rascunho e consultar o estado atual antes de oferecer nova tentativa explícita. *(RNF12, RNF13, MA-08)*

## 8. Observabilidade e auditoria

| Evento | Gatilho | Dados permitidos |
|---|---|---|
| `family_member_created` | Perfil confirmado | `familyId`, `memberId`, `role` |
| `family_member_role_changed` | Papel confirmado | `familyId`, `memberId`, papel anterior/novo, ator |
| `family_member_removed` | Remoção confirmada | `familyId`, `memberId`, ator, instante |
| `member_management_denied` | Operação bloqueada | `requestId`, ator, rota, motivo técnico |

Segredos, tokens, provas de instalação, hashes, apelido privado configurável e credenciais de convite nunca entram em telemetria ou logs.

## 9. Decisões registradas

| # | Decisão | Origem | Altera `docs/`? |
|---|---|---|---|
| E-01 | Nome administrativo: obrigatório, 1–60 caracteres Unicode visíveis após `trim`, sem caracteres de controle. | Aprovação da prévia em 2026-10-06 | Sim — RF02/RF03 e base 1.7 atualizadas |
| E-02 | Os papéis permitidos na criação são `administrator`, `member` e `kids`; `kids` não possui booleano separado. | Aprovação da prévia em 2026-10-06 | Sim — RF40 e base 1.7 atualizadas |
| E-03 | A saída voluntária de Administrador não-Criador pertence a esta entrega, embora sua entrada visual exista em TEL-030. | Aprovação da prévia em 2026-10-06 | Não — aplica UC02/RN04 existentes |
| E-04 | A emissão e o reenvio de convite não integram esta entrega; criação de perfil e convite continuam comandos distintos. | Mapa de specs e contrato backend | Não |
| E-05 | Revisada: membros iniciais são preparados em TEL-002 e criados com a família por SPEC-002; TEL-056 só oferece convite. Inclusões após a criação usam a gestão persistente desta SPEC. | Pessoa usuária / 2026-10-19 | Sim — RN01/RN07, RF02/RF40 e UC01/UC02. |
| E-07 | Adultos editam o próprio nome pela SPEC-006; Administrador corrige apenas o nome administrativo de Kids por esta SPEC, em TEL-057 ou TEL-032. A rota de atualização administrativa responde 403 para alvo adulto da mesma família. | Pessoa usuária / 2026-10-28 | Sim — RN07/RN63, RF03/RF60, UC02/UC10 e contrato backend. |
| E-06 | A lista de membros usa cursor opaco, ordenação estável e páginas de até 20 perfis; `nextCursor: null` encerra a consulta. O Mobile carrega as páginas seguintes por rolagem infinita. | Pessoa usuária / 2026-10-08 | Não — detalha o contrato e a experiência de consulta, sem alterar RN/RF. |

## 10. Fases de implementação e conclusão

| Fase | Objetivo | CAs | Prontidão | Status |
|---|---|---|---|---|
| 1 | Consulta e criação segura: projeções adultas, criação e validação de perfil, RBAC e isolamento | CA-01 a CA-03, CA-07 | Testes unitários, integração e UI dos fluxos publicados verdes | em andamento — backend concluído (SCRUM-27); Mobile pendente (SCRUM-29) |
| 2 | Administração de papel e modo Kids, incluindo saída voluntária | CA-04, CA-05, CA-07 | Transições e recusas por papel/Criador cobertas por testes de integração e UI | a fazer |
| 3 | Remoção consistente, revogação e regressão | CA-06, CA-07 | Transação de remoção, sessão revogada e regressão de responsabilidades verificadas | a fazer |

**Registro de execução (2026-10-19):** SCRUM-27 concluiu a criação e consulta posterior de membros no backend. A criação atômica dos membros iniciais pertence à revisão de SPEC-002. A Fase 1 desta SPEC não é considerada concluída porque a interface Mobile correspondente (SCRUM-29) ainda não foi entregue.

- **Fase 1:** não expõe mudança de papel, saída voluntária ou remoção; o perfil recém-criado permanece sem convite, que pertence à SPEC-004.
- **Fase 2:** não emite convite nem implementa edição de foto/apelido; pode ser publicada depois da Fase 1.
- **Fase 3:** não pode ser publicada sem as garantias de revogação e de preservação definidas por RN10/RNF22.

## 11. Checklist de aprovação

- [x] Códigos funcionais, UX e arquiteturais pesquisados e existentes.
- [x] Revisão de SPEC-002 e deste par SPEC/UX aprovada para o novo onboarding.
- [x] Autorização, isolamento e validação fazem parte da primeira fase exposta.
- [x] Contratos, validações, erros e política de falha definidos.
- [x] UX-spec vinculada.
- [x] Decisões E-01 a E-04 registradas e alterações de base efetuadas quando necessárias.
- [x] Revisão de 2026-10-19 aprovada; aprovação anterior de 2026-10-06 preservada no histórico.
