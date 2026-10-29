# Convenções de código backend

**Versão:** 1.1
**Data:** 2026-10-08  
**Situação:** norma técnica para implementações Node.js, TypeScript e Fastify

[Arquitetura backend](backend-architecture.md) · [Contratos backend](backend-contracts.md) · [Decisões backend](backend-decisions.md) · [Índice](../DOCUMENTACAO.md)

## 1. Escopo e precedência

Estas convenções se aplicam a código em `backend/`. Elas complementam a arquitetura e os contratos; em conflito, prevalecem a SPEC aprovada para comportamento e os contratos para transporte, autorização e erros. Não autorizam criar endpoints ou alterar regras de produto.

Código, arquivos, identificadores de banco, APIs e testes usam inglês. Documentação explicativa, comentários de decisão e mensagens operacionais podem permanecer em português. Comentários explicam invariantes, segurança ou uma decisão não óbvia — não repetem o que o código já diz.

## 2. TypeScript e organização

- Use TypeScript estrito. Não introduza `any`; prefira `unknown` na borda e faça estreitamento explícito. Trate `null` e `undefined` como estados distintos quando o contrato os diferencia.
- Arquivos usam `kebab-case` (`connection-pool.ts`); tipos, classes e enums usam `PascalCase`; funções, propriedades, variáveis e campos JSON usam `camelCase`.
- Use exports nomeados. Imports relativos ESM incluem a extensão `.js`, mesmo quando a fonte é `.ts`, conforme `NodeNext`.
- Organize cada módulo por `domain`, `application`, `presentation` e `infrastructure`. Domain e Application não importam Fastify, `pg`, variáveis de ambiente ou detalhes HTTP.
- Ports descrevem capacidade (`TaskRepository`, `Clock`, `TransactionRunner`); adaptadores declaram o mecanismo (`PostgresTaskRepository`, `SystemClock`). Evite nomes vagos como `Helper`, `Manager`, `Common` ou `Utils`.
- Mantenha DTOs, schemas HTTP e modelos de domínio separados. Um handler traduz request/response; um caso de uso executa o comportamento; repositórios persistem dados.

## 3. Fastify, contratos e erros

- Registre rotas no módulo de Presentation e valide `params`, `querystring`, `headers` e `body` com schemas versionados no código. Defina schema de resposta para contratos públicos; schemas nunca vêm de entrada do usuário.
- Todo endpoint usa o prefixo `/v1`, exceto probes operacionais. Preserve `application/problem+json`, `requestId` e os códigos estáveis definidos em `backend-contracts.md`.
- Toda rota HTTP pública ou operacional criada ou alterada deve manter o schema OpenAPI que alimenta `/docs/json`: tag, resumo, autenticação quando necessária, entradas e respostas devem descrever o contrato efetivamente exposto. A interface interativa fica em `/docs`; suas próprias rotas não precisam ser documentadas como parte da API do produto.
- Atores vêm da sessão/`ActorContext`; `familyId`, papel, créditos, autor e timestamps enviados pelo cliente jamais autorizam uma ação. Consulte recursos sempre no escopo da família/titularidade exigida.
- Erros de domínio são intencionais e mapeados uma vez na borda. Não exponha stack trace, SQL, segredo, token, senha, prova de instalação ou conteúdo de mídia em resposta ou log.
- Fastify valida e serializa a partir de schemas. Caso configure validadores/serializadores customizados, preserve o contrato síncrono de retorno de erro/valor recomendado pelo framework.

## 4. Persistência, transação e segurança

- Use consultas SQL parametrizadas; nunca concatene valores de request em SQL. Preserve `DATABASE_SCHEMA` e o `search_path` controlado pela infraestrutura.
- Escritas que protegem invariantes de família, crédito, missão, convite ou recompensa usam a mesma transação e a conexão reservada exigida pelo caso de uso. Revalide autorização e estado após esperar lock.
- Migrations são SQL, forward-only, numeradas como `NNNN_descricao_em_ingles.sql` e nunca são editadas depois de aplicadas. Alterações corretivas entram em migration nova.
- Configuração é validada no bootstrap. Segredos vêm do ambiente e não recebem valor de produção conhecido no código; templates usam placeholders e nunca credenciais reais.
- Logs estruturados incluem contexto seguro (`requestId`, caso de uso, duração e erro sanitizado). Omitir dados sensíveis é requisito, não ajuste posterior.

## 5. Qualidade e testes

- Mantenha `eslint`, `tsc --noEmit` e Prettier como fonte de formatação. Execute `npm run lint`, `npm run typecheck`, `npm run test` e `npm run build` antes de entregar; use `npm run format:check` quando o card alterar código ou configuração formatados pelo backend.
- Testes Vitest descrevem comportamento em inglês e isolam dependências de infraestrutura em unidade. Use PostgreSQL real em integração para locks, unicidade, transações e isolamento entre famílias.
- Cada novo endpoint cobre caminho autorizado, validação, ausência/recurso fora do escopo e erro de domínio relevante. Cada escrita crítica cobre concorrência ou reconciliação quando a SPEC exigir.
- Fixtures são determinísticas, usam UUIDs/dados fictícios e não carregam segredos ou dados pessoais reais.

## Referências

- [TypeScript strictness](https://www.typescriptlang.org/docs/handbook/2/basic-types.html#strictness) — verificação estática rigorosa e tratamento explícito de nulos.
- [Fastify: Validation and Serialization](https://fastify.dev/docs/latest/Reference/Validation-and-Serialization/) — schemas para entrada e resposta.
- [Arquitetura backend](backend-architecture.md) e [contratos backend](backend-contracts.md) — fronteiras, transações, erros e autorização deste projeto.

## Histórico

| Versão | Data | Alteração |
|---|---|---|
| 1.1 | 2026-10-08 | Rotas HTTP passam a exigir documentação OpenAPI/Swagger em `/docs` e `/docs/json`, alinhada ao contrato e coberta quando aplicável por teste de contrato. |
| 1.0 | 2026-10-08 | Convenções iniciais de TypeScript/Fastify, camadas, contratos, persistência, segurança e testes. |
