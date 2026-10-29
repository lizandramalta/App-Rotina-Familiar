# SPEC-015: Gerenciar recompensas coletivas

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Usuária | **Em:** 2026-10-10  
**Base funcional:** 1.15  
**UX-spec:** [UX-015-gerenciar-recompensas-coletivas.md](UX-015-gerenciar-recompensas-coletivas.md)  
**Projetos envolvidos:** ambos  
**Tema do backlog:** Tema 4 — Missões e recompensas

## 1. Contexto e objetivo

Administradores precisam consultar o catálogo coletivo da roleta e acrescentar opções que façam sentido para a própria família. Esta entrega disponibiliza o catálogo inicial e o cadastro seguro de itens personalizados, sem realizar sorteio ou aceitar resgate.

## 2. Rastreabilidade e dependências

| Categoria | Códigos incluídos |
|---|---|
| Casos de uso | UC06 |
| Regras de negócio | RN41, RN42 |
| Requisitos funcionais | RF33, RF34 |
| Requisitos não funcionais | RNF01, RNF05–08, RNF12–14, RNF22 |
| Telas e fluxos | TEL-023, MOD-008, UF-11 |
| Decisões arquiteturais | MA-07, MA-08, MA-09, MA-11; BA-05, BA-07, BA-08, BA-20 |

- **Documentos consultados:** `docs/01-regras-de-negocio.md`, `docs/02-requisitos.md`, `docs/03-casos-de-uso.md`, `docs/05-modelo-de-dados.md`, `docs/06-diagrama-de-classes.md`, `docs/design/screen-map.md`, `docs/design/user-flows.md`, `docs/architecture/mobile-feature-catalog.md` e `docs/architecture/backend-contracts.md`.
- **Depende de:** SPEC-002, para família, sessão e papel de Administrador.
- **Dependências externas:** nenhuma.

## 3. Escopo

### 3.1 Dentro do escopo

- Listar para o Administrador os itens predefinidos e os itens personalizados da família da sessão.
- Disponibilizar seis itens predefinidos: “Escolher o filme da noite”, “Escolher o jantar em família”, “Noite de jogos em família”, “Sobremesa especial”, “Piquenique ou passeio no parque” e “Escolher uma atividade em família”.
- Cadastrar item personalizado com título obrigatório e descrição opcional.
- Validar limites, caracteres de controle e unicidade do título personalizado por família.
- Tornar o item confirmado elegível em sorteios futuros, sem vinculá-lo a uma missão.
- Exibir e tratar estados de carregamento, validação, falha e resultado incerto conforme a UX-spec.

### 3.2 Fora do escopo

- Sorteio, animação, aceite e registro de recompensa da missão (SPEC-017).
- Consulta de missões/recompensas para Membro ou Kids (SPEC-016).
- Editar, excluir, reordenar, ocultar ou desativar item de recompensa.
- Alterar os itens predefinidos em tempo de execução.

### 3.3 Anti-requisitos

- O mobile NÃO decide autorização, família, unicidade ou elegibilidade: o backend é autoritativo.
- O cadastro NÃO cria missão, vínculo de missão, participação, badge ou resgate.
- Não há rota por identificador nesta entrega; portanto, a proteção entre famílias é demonstrada pela projeção da lista, sem inventar `404` para um recurso que não é recebido pela API.

## 4. Perfis e autorização

| Perfil | Pode | Não pode | Tentativa remota |
|---|---|---|---|
| Administrador | Consultar e adicionar itens da própria família | Alterar predefinidos ou itens já existentes | Sucesso quando válido |
| Membro | — | Consultar ou adicionar | `403 INSUFFICIENT_PERMISSIONS` |
| Kids | — | Consultar ou adicionar | `403 INSUFFICIENT_PERMISSIONS` |

A família é obtida exclusivamente da sessão. A resposta de `GET /reward-items` DEVE conter todos os predefinidos e apenas os personalizados daquela família; nunca deve aceitar `familyId` no corpo ou query.

## 5. Contrato de dados e API

### 5.1 Validações

| Campo | Tipo | Obrigatório | Regra | Erro de campo |
|---|---|---|---|---|
| `title` | string | Sim | Após `trim`, não pode ser vazio, conter caracteres de controle ou exceder 60 caracteres não-espaço | `REWARD_TITLE_REQUIRED`, `REWARD_TITLE_TOO_LONG`, `REWARD_TITLE_CONTROL_CHARACTERS` |
| `details` | string | Não | No máximo 255 caracteres, contando espaços | `REWARD_DETAILS_TOO_LONG` |

Dois títulos personalizados da mesma família são iguais quando seus valores após `trim` forem iguais sem distinguir maiúsculas de minúsculas. A segunda criação DEVE retornar `422 REWARD_TITLE_ALREADY_EXISTS`; essa regra inclui duas tentativas concorrentes.

### 5.2 Listar itens

- **Método e rota:** `GET /v1/reward-items`
- **Autenticação:** sessão ativa de Administrador.
- **Resposta `200 OK`:**

```json
{
  "predefined": [
    { "id": "…", "title": "Escolher o filme da noite", "details": null, "source": "predefined" }
  ],
  "custom": [
    { "id": "…", "title": "Noite de pizza", "details": "Escolher juntos", "source": "custom", "createdAt": "2026-10-10T13:00:00Z" }
  ]
}
```

`predefined` DEVE preservar os seis itens de RN42; `custom` DEVE conter somente itens da família atual. `401` indica sessão ausente/inválida e `403 INSUFFICIENT_PERMISSIONS` indica perfil não administrador.

### 5.3 Adicionar item

- **Método e rota:** `POST /v1/reward-items`
- **Autenticação:** sessão ativa de Administrador.
- **Request:**

```json
{
  "title": "Noite de pizza",
  "details": "Escolher juntos"
}
```

- **Resposta `201 Created`:** o item canônico, com `id`, `title` aparado, `details`, `source: "custom"` e `createdAt`.
- **Erros:** `401`, `403 INSUFFICIENT_PERMISSIONS`, `422 VALIDATION_FAILED` com `fieldErrors`, `422 REWARD_TITLE_ALREADY_EXISTS` e `429` quando aplicável à política de proteção.
- Campos desconhecidos ou protegidos DEVEM ser rejeitados; `familyId`, `source`, `createdAt` e autor nunca são aceitos do cliente.

### 5.4 Resultado incerto

Se o cliente perder a resposta após enviar o cadastro, ele NÃO DEVE afirmar que salvou. Ao recarregar a lista, a presença do título normalizado confirma o item; se não estiver presente, a pessoa pode reenviar. A restrição de unicidade garante que o reenvio não crie duplicata.

## 6. Modelo e integridade

`RECOMPENSA` preserva `titulo`, `titulo_normalizado`, `descricao`, `familia_id`, `criado_por_id` e `criado_em`. Para personalizados, `titulo_normalizado` é único por `familia_id`; itens predefinidos não pertencem a família. A criação e a unicidade DEVEM ser atômicas no backend.

O modelo de domínio usa `RewardItem.custom(title:details:by:)`; descrição é `String?`. A elegibilidade do item passa a valer após o `201`, mas o item não é associado automaticamente a nenhuma missão.

## 7. Critérios de aceitação

| ID | Fase | Critério verificável |
|---|---|---|
| CA-01 | 1 | Administrador autenticado recebe os seis itens predefinidos e somente os personalizados da própria família, com origem e descrição. |
| CA-02 | 1 | Administrador salva título válido e descrição de até 255 caracteres; o retorno é `201`, o item aparece na lista e fica elegível sem criar vínculo de missão. |
| CA-03 | 1 | Título vazio após `trim`, com controle ou com mais de 60 caracteres não-espaço, e descrição acima de 255, retornam validação de campo e preservam o rascunho no mobile. |
| CA-04 | 1 | Repetir título na mesma família, inclusive com espaços nas extremidades ou diferença de maiúsculas/minúsculas, retorna `422 REWARD_TITLE_ALREADY_EXISTS`; tentativa concorrente cria um único item. |
| CA-05 | 1 | Membro e Kids não veem o caminho no aplicativo e recebem `403 INSUFFICIENT_PERMISSIONS` se chamarem as rotas. |
| CA-06 | 1 | Itens personalizados de outra família nunca aparecem em `GET /reward-items`, mesmo se o cliente tentar indicar outro `familyId`. |
| CA-07 | 1 | Depois de resposta perdida, o aplicativo informa estado incerto e permite confirmar pelo recarregamento, sem duplicar o item. |

## 8. Fases e verificação

### Fase 1 — Fatia vertical

- Backend: persistência, migração/seed dos predefinidos, `ListRewardItems`, `AddRewardItem`, RBAC, isolamento e unicidade transacional.
- Mobile: TEL-023, MOD-008, estados da UX-spec, repositório/DTOs e os casos de uso de consulta e adição.
- Testes: unidade para normalização e limites; integração para RBAC, isolamento e concorrência; UI para erro, cancelamento, sucesso e resposta incerta.
- Cobre CA-01 a CA-07.

## 9. Observabilidade e segurança

- Logs estruturados podem registrar rota, resultado, família pseudonimizada e código de erro; não devem registrar token, conteúdo de descrição nem dados de outra família.
- Métricas de criação, validação, duplicidade e falhas de consulta devem ser agregadas por resultado.
- Erros seguem Problem Details RFC 9457 e não expõem `familyId`, consultas SQL ou itens de terceiros.

## 10. Decisões consolidadas

1. Título personalizado: até 60 caracteres não-espaço após `trim`, sem caracteres de controle.
2. Título personalizado: único por família após `trim`, sem distinguir maiúsculas/minúsculas.
3. Catálogo inicial: os seis itens listados na seção 3.1.
4. Descrição personalizada: opcional, até 255 caracteres contando espaços.

Essas decisões atualizaram RN42, RF34, UC06, DER, diagrama de classes, contratos backend e artefatos de design antes da criação deste rascunho.

## 11. Checklist de aprovação

- [x] Rastreabilidade funcional e UX identificada.
- [x] Decisões de limite, unicidade, catálogo e descrição consolidadas na base documental.
- [x] Contrato, isolamento, autorização e recuperação de resposta incerta definidos.
- [x] SPEC funcional aprovada.
- [x] UX-spec vinculada aprovada.
