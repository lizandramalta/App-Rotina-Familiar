# Spec NNN: [Nome curto da funcionalidade]

**Status:** rascunho | em esclarecimento | aprovada | em implementação (fase N) | em validação qa | implementada  
**Autor:** | **Criada em:** AAAA-MM-DD | **Aprovada por:** | **Em:** AAAA-MM-DD  
**Base funcional:** [versão vigente da documentação em docs/, ex.: 1.5]  
**UX-spec:** [link para UX-NNN-nome-curto.md] | não aplicável: [justificativa técnica obrigatória]  
**Projetos envolvidos:** mobile | backend | ambos  
**Tema do backlog:** [Tema 1..5 conforme specs/README.md]  

<!--
================================================================================
DIRETRIZES DE ENGENHARIA E PREENCHIMENTO (SPECIFICATION-DRIVEN DEVELOPMENT - SDD)
================================================================================
1. PROPÓSITO: Esta spec é o CONTRATO DE ENTREGA executável entre mobile, backend e QA.
   Ela define O QUÊ, POR QUÊ, REGRAS DE NEGÓCIO, CRITÉRIOS DE ACEITAÇÃO e o
   CONTRATO DE INTERFACE COMPARTILHADO (endpoints, payloads, validações e erros).
2. FRONTEIRA ARQUITETURAL: A spec não deve ditar detalhes internos e efêmeros de
   implementação (ex.: se a view SwiftUI usa VStack ou se o banco usa índice B-tree).
   Contudo, DEVE DEFINIR DE FORMA INEQUÍVOCA o contrato de interface (rotas, DTOs,
   códigos de erro Problem Details RFC 9457 e modelos de dados afetados).
3. RASTREABILIDADE: Não invente regras nem comportamentos. Cite os códigos estáveis
   (RN, RF, RNF, UC, TEL, UF, MA, BA). Divergências devem ser resolvidas na base
   documental antes de aprovar esta spec.
4. FATIAMENTO VERTICAL: Uma spec representa uma fatia utilizável de ponta a ponta
   (geralmente 1 a 2 Casos de Uso completos).
5. PALAVRAS-CHAVE NORMATIVAS (RFC 2119):
   - DEVE / NÃO DEVE (MUST / MUST NOT): Requisito mandatório, bloqueia aceite.
   - DEVERIA / NÃO DEVERIA (SHOULD / SHOULD NOT): Recomendação técnica justificada.
   - PODE (MAY): Comportamento estritamente opcional.
6. RELAÇÃO COM A UX-SPEC: Esta spec é soberana em COMPORTAMENTO, DADOS E REGRAS.
   A UX-spec é soberana em APRESENTAÇÃO, HIERARQUIA VISUAL, VIEWSTATES E TEXTOS.
================================================================================
-->

## 1. Contexto e Objetivo

- **Problema / Necessidade:** [Descreva brevemente qual dor do usuário ou necessidade funcional motivou esta entrega e por que agora].
- **Objetivo da entrega:** [Uma ou duas frases objetivas: o que esta entrega realiza, com qual valor e para qual perfil de usuário].

## 2. Rastreabilidade e Dependências

| Categoria | Códigos incluídos nesta entrega |
|---|---|
| Casos de uso | UC.. |
| Regras de negócio | RN.. |
| Requisitos funcionais | RF.. |
| Requisitos não funcionais | RNF.. |
| Telas e fluxos de navegação | TEL-.., MOD-.., UF-.. |
| Decisões arquiteturais aplicáveis | MA-.., BA-.. |

- **Documentos consultados:** [Ex.: `docs/01-regras-de-negocio.md`, `docs/architecture/backend-contracts.md`, etc.]
- **Depende de (specs pré-requisito):** [Ex.: SPEC-002; ou "Nenhuma - entrega independente"]
- **Dependências externas e infraestrutura:** [Ex.: Cloudflare R2, Apple Sign-In, APNs, nenhuma]

## 3. Escopo da Entrega

### 3.1. Dentro do escopo
- [Lista clara do que será implementado e entregue nesta spec].

### 3.2. Fora do escopo (desta spec)
- [Partes dos UCs referenciados ou extensões que ficam para specs posteriores, com a respectiva justificativa].

### 3.3. Fora de questão (Anti-requisitos / Suposições descartadas)
*Esta seção é fundamental para evitar sobre-engenharia e alucinações de agentes de IA sobre comportamentos que parecem plausíveis, mas NÃO existem no produto.*

- [Exemplo: O sistema NÃO envia e-mails transacionais nesta etapa; a comunicação é exclusivamente in-app].
- [Exemplo: Não haverá deleção física de registros nesta funcionalidade; apenas inativação lógica].

## 4. Perfis, Atores e Regras de Autorização (RBAC)

O isolamento familiar e a restrição de perfis são inegociáveis desde a primeira fase de implementação.

| Perfil | Pode | Não pode | Reação do sistema a tentativa não autorizada |
|---|---|---|---|
| **Administrador** | | | HTTP 403 `INSUFFICIENT_PERMISSIONS` / Ação oculta na UI |
| **Membro** | | | HTTP 403 `INSUFFICIENT_PERMISSIONS` / Ação oculta na UI |
| **Kids** | | | HTTP 403 `INSUFFICIENT_PERMISSIONS` / Ação oculta na UI |

- **Isolamento Multitenant Familiar (RNF06):** Qualquer tentativa de leitura, alteração ou exclusão de recurso pertencente a outra família DEVE responder com HTTP `404 Not Found` (com código de erro estável `RESOURCE_NOT_FOUND`), sem vazar a existência do recurso ou metadados de terceiros.

## 5. Contrato de Dados, Interface e Validações

### 5.1. Dicionário de Campos e Validações de Entrada
*Define a autoridade de validação para frontend e backend.*

| Campo (`json_key`) | Tipo | Obrigatório? | Regras de Validação e Limites | Código de Erro (`fieldErrors[].code`) | Descrição e Comportamento |
|---|---|---|---|---|---|
| `title` | string | Sim | Min: 3, Max: 80 caracteres; sem HTML | `TITLE_INVALID_LENGTH` | Título legível da tarefa |
| `description` | string | Não | Max: 500 caracteres | `DESCRIPTION_TOO_LONG` | Detalhes adicionais |
| `assignedMemberId` | uuid | Não | Deve pertencer à mesma família ativa | `ASSIGNEE_NOT_IN_FAMILY` | Responsável pela execução |

### 5.2. Contrato de API Compartilhado (Endpoints e Payloads)
*Contrato canônico entre `mobile/` e `backend/`. Se houver mais de um endpoint, repita este bloco.*

- **Método e Rota:** `POST /v1/...`
- **Autenticação:** Bearer Token de sessão ativa (`Authorization: Bearer <token>`).
- **Headers específicos:** [Ex.: `X-Device-Installation-Proof`, `Idempotency-Key` ou Nenhum].

#### Payload de Entrada (Request Body):
```json
{
  "title": "Arrumar os brinquedos",
  "description": "Guardar no baú do quarto",
  "assignedMemberId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

#### Resposta de Sucesso:
- **HTTP Status:** `201 Created` (ou `200 OK`, `204 No Content`)
- **Headers de Resposta:** [Ex.: `Location: /v1/...`]
- **Payload de Retorno (JSON):**
```json
{
  "id": "e4f5a6b7-c8d9-0123-4567-89abcdef0123",
  "title": "Arrumar os brinquedos",
  "status": "pending",
  "createdAt": "2026-10-06T15:00:00Z"
}
```

#### Respostas de Erro Padronizadas (RFC 9457 - Problem Details):
Todos os erros utilizam `Content-Type: application/problem+json`.

| HTTP Status | `code` estável | Cenário / Causa | Exemplo de `fieldErrors` |
|---|---|---|---|
| `400 Bad Request` | `VALIDATION_FAILED` | Payload inválido ou campos obrigatórios ausentes | `[{"field": "title", "code": "TITLE_INVALID_LENGTH"}]` |
| `401 Unauthorized` | `SESSION_EXPIRED` | Token ausente, inválido ou expirado | - |
| `403 Forbidden` | `ACTION_NOT_ALLOWED` | Perfil sem permissão para executar a ação | - |
| `404 Not Found` | `RESOURCE_NOT_FOUND` | Recurso não existe ou pertence a outra família | - |
| `409 Conflict` | `TASK_ALREADY_COMPLETED` | Conflito de estado de domínio | - |
| `429 Too Many Requests`| `RATE_LIMIT_EXCEEDED` | Excesso de requisições por janela temporal | - |

### 5.3. Estratégia de Concorrência, Idempotência e Falhas
- **Idempotência (RNF11):** [Ex.: Operações de criação aceitam header `Idempotency-Key: UUID`. Retentativas com a mesma chave retornam o resultado original sem duplicar o registro].
- **Concorrência:** [Ex.: *Last-write-wins* para edição de título; ou *Optimistic locking* com verificação de status atual para transições de estado].
- **Tratamento de Falhas e Rede Intermitente (RNF12, RNF13):** Em caso de falha de conexão, o aplicativo móvel DEVE manter os dados preenchidos localmente em rascunho, alertar o usuário de forma não-destrutiva e permitir o reenvio sem perda de digitação.

## 6. Estados de Domínio e Transições

*Obrigatório sempre que a funcionalidade envolver mudança de ciclo de vida (ex.: Tarefa, Missão, Convite, Membro).*

| Estado De | Evento / Ação | Estado Para | Quem Pode Executar | Regras e Validações | Efeitos Colaterais |
|---|---|---|---|---|---|
| `pending` | Concluir | `completed` | Responsável / Admin | RN.. | Dispara evento de auditoria; pontua missão |
| `pending` | Cancelar | `cancelled` | Apenas Administrador | RN.. | Remove das pendências ativas |

## 7. Critérios de Aceitação (BDD Formal)

Os critérios utilizam a estrutura formal **DADO QUE / QUANDO / ENTÃO / E**.  
Cada critério possui um identificador unívoco (`CA-01`, `CA-02`...) que deve ser citado nos testes automatizados e nas PRs.

- **CA-01: [Fluxo Principal - Criação com sucesso]**
  - **DADO QUE** um usuário autenticado com perfil `Administrador` ou `Membro` está ativo na família,
  - **QUANDO** enviar uma requisição `POST /v1/...` com todos os campos obrigatórios válidos,
  - **ENTÃO O SISTEMA DEVE** persistir o registro com status inicial `pending` associado à família do usuário,
  - **E** retornar HTTP status `201 Created` contendo o ID gerado e os dados canônicos persistidos. *(Origem: UC.. passo .., RN..)*

- **CA-02: [Tentativa Não Autorizada - Perfil sem permissão]**
  - **DADO QUE** o usuário autenticado possui o perfil `Kids`,
  - **QUANDO** tentar executar esta operação protegida,
  - **ENTÃO O SISTEMA DEVE** rejeitar a operação sem persistir alterações,
  - **E** retornar HTTP status `403 Forbidden` com código `ACTION_NOT_ALLOWED`. *(Origem: RNF07, RN..)*

- **CA-03: [Isolamento Multitenant - Recurso de outra família]**
  - **DADO QUE** um recurso existe e pertence à "Família B",
  - **QUANDO** um usuário autenticado pertencente à "Família A" tentar consultar ou alterar o recurso,
  - **ENTÃO O SISTEMA DEVE** responder com HTTP status `404 Not Found` com código `RESOURCE_NOT_FOUND`,
  - **E** não revelar qualquer dado, contagem ou metadado do recurso pertencente a terceiros. *(Origem: RNF06)*

- **CA-04: [Validação de Entrada - Limite de tamanho de campo]**
  - **DADO QUE** o usuário envia o campo `title` com tamanho superior a 80 caracteres,
  - **QUANDO** a requisição for processada,
  - **ENTÃO O SISTEMA DEVE** recusar a persistência com HTTP status `400 Bad Request`,
  - **E** retornar no corpo da resposta o erro estruturado contendo o campo `title` e o código `TITLE_INVALID_LENGTH`. *(Origem: RN..)*

- **CA-05: [Concorrência e Ações Simultâneas]**
  - **DADO QUE** dois membros da mesma família tentam concluir a mesma tarefa simultaneamente,
  - **QUANDO** a segunda requisição for processada após a primeira ter sido confirmada,
  - **ENTÃO O SISTEMA DEVE** recusar a segunda transição com HTTP status `409 Conflict` e código `TASK_ALREADY_COMPLETED`,
  - **E** orientar a interface a atualizar a lista de pendências sem exibir erro genérico de servidor. *(Origem: RNF11, RN..)*

- **CA-06: [Resiliência - Falha de rede e retenção local]**
  - **DADO QUE** o dispositivo perde conectividade antes de receber a resposta da API,
  - **QUANDO** o cliente mobile identificar timeout ou indisponibilidade de rede,
  - **ENTÃO O SISTEMA DEVE** reter o formulário em estado de rascunho seguro,
  - **E** permitir ao usuário tentar novamente assim que a conexão for restabelecida, sem perda de dados. *(Origem: RNF12, RNF13)*

### Checklist de Cobertura Obrigatória dos CAs:
- [ ] Fluxo principal de cada UC coberto
- [ ] Todos os fluxos alternativos e exceções dos UCs mapeados
- [ ] Recusa explícita para cada perfil sem permissão (RNF07)
- [ ] Isolamento estrito entre famílias / multitenancy (RNF06)
- [ ] Ações simultâneas e concorrência tratadas (RNF11)
- [ ] Falha de conexão, timeout e preservação de estado (RNF12, RNF13)
- [ ] Limites numéricos de campos e validações de fronteira cobertos

## 8. Observabilidade, Métricas e Auditoria

| Evento | Tipo | Gatilho / Condição | Propriedades Registradas | Destino |
|---|---|---|---|---|
| `task_created` | Métrica / Analytics | Tarefa criada com sucesso | `taskId`, `familyId`, `hasAssignee`, `hasDueDate` | Analytics |
| `task_completed` | Métrica / Analytics | Tarefa concluída | `taskId`, `familyId`, `role` | Analytics |
| `audit_unauthorized_access` | Log de Segurança | Tentativa de acesso bloqueada | `actorId`, `targetFamilyId`, `endpoint`, `ip` | Log estruturado |

*Nota de Privacidade e Segurança:* Segredos, tokens de autenticação, senhas e hashes NUNCA devem ser registrados em logs ou eventos de telemetria.

## 9. Premissas e Esclarecimentos

### 9.1. Premissas
*O que se está assumindo como verdadeiro durante o desenho desta entrega.*
- **P-01:** [Ex.: O fuso horário da família já está configurado na criação da conta e orienta o cálculo de datas locais].

### 9.2. Esclarecimentos e Decisões
*Dúvidas levantadas durante a especificação e as decisões confirmadas.*

| # | Pergunta / Dúvida | Decisão Tomada | Decidido por / Data | Altera a documentação em `docs/`? |
|---|---|---|---|---|
| E-01 | | | | Sim / Não |

*Regra:* Se "Altera docs/?" for Sim, a base documental correspondente DEVE ser atualizada e versionada antes da aprovação final desta spec.

## 10. Fases de Implementação e Critérios de Conclusão

Divide a entrega em etapas funcionais incrementais e utilizáveis.  
*Regra de Segurança:* Autorização, isolamento multitenant (RNF06) e validação de entrada NUNCA são adiados para fases posteriores; entram obrigatoriamente na Fase 1.

| Fase | Objetivo da Entrega | Critérios de Aceite Atendidos | Critério de Prontidão (Definition of Done) | Status |
|---|---|---|---|---|
| **1** | **Núcleo Mínimo (Core API + Isolamento):** Contrato de dados, persistência, regras de acesso e isolamento de família. | CA-01, CA-02, CA-03, CA-04 | Testes unitários e de integração verdes cobrindo os CAs listados. | a fazer |
| **2** | **Experiência Mobile + Integração:** Integração com as telas móveis, fluxos alternativos e feedback visual. | CA-05, CA-06... | Telas integradas com a API, testes de UI/E2E e UX-spec verificada. | a fazer |
| **3** | **Polimento e Casos Raros:** Tratamentos adicionais, métricas e casos excepcionais de borda. | CA-.. | Suíte de regressão verde e validação de QA concluída. | a fazer |

### Para cada fase, documente:
- **Fora desta fase:** O que ainda não funciona ao final da fase e como isso se apresenta ao usuário (ex.: botão oculto na UI, recurso desabilitado).
- **Pode ser publicada de forma independente em produção?** Sim / Não (se Não, informar com qual fase deve sair em conjunto).

## 11. Checklist de Aprovação da Spec (Definition of Ready)

Antes de alterar o status desta spec para `aprovada`, verifique:

- [ ] Todos os códigos citados (`RN`, `RF`, `RNF`, `UC`, `TEL`, `UF`) existem na base funcional vigente.
- [ ] A rastreabilidade técnica (`MA-..`, `BA-..`) está alinhada com as diretrizes de arquitetura.
- [ ] O contrato de API compartilhado (rotas, payloads JSON, status HTTP e Problem Details) está completo e sem ambiguidades.
- [ ] O dicionário de campos define tipos, limites e códigos de erro estáveis para todos os inputs.
- [ ] Todo critério de aceitação segue o padrão formal BDD (DADO / QUANDO / ENTÃO / E) e mapeia um teste automatizável.
- [ ] Isolamento entre famílias (RNF06) e recusa por perfil (RNF07) constam explicitamente nos CAs da Fase 1.
- [ ] Nenhuma premissa sem validação ou esclarecimento pendente na seção 9.
- [ ] A UX-spec correspondente está vinculada, revisada e coerente — ou marcada como "não aplicável" com justificativa aprovada.
- [ ] A seção "Fora de questão" elimina riscos de suposições incorretas.
- [ ] Não há detalhes efêmeros de implementação que engessem a arquitetura interna dos módulos.
