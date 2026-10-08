# Projeto Backend — App de Rotina Familiar

Serviço backend único estruturado como **Monólito Modular** com **Clean Architecture**, implementado em **Node.js** e **TypeScript (ESM)**.

O backend é a autoridade central para persistência, autorização, materialização de rotinas, apuração de pontuação e orquestração de notificações. O banco de dados PostgreSQL é hospedado no **Supabase** (usando o schema privado `app`), e o armazenamento privado de fotos é integrado ao **Cloudflare R2**.

---

## 1. Fontes de Verdade e Arquitetura

Antes de implementar novas funcionalidades, consulte a documentação arquitetural de referência:

- [Arquitetura Backend](../docs/architecture/backend-architecture.md) — Camadas, módulos, isolamento de famílias, concorrência e jobs.
- [Contratos de API e Rastreabilidade](../docs/architecture/backend-contracts.md) — Especificação `/v1`, erros RFC 9457 Problem Details e mapeamento UC01–UC19.
- [Decisões Técnicas](../docs/architecture/backend-decisions.md) — BA-01 a BA-20 (Node.js, Fastify, PostgreSQL com `pg`, Supabase gerenciado, sessão própria).
- [Modelo de Dados (DER)](../docs/05-modelo-de-dados.md) — Entidades, relacionamentos e glossário técnico em inglês.
- [Specs de Entrega](../specs/README.md) — Recortes funcionais aprovados para desenvolvimento incremental.

---

## 2. Pré-requisitos e Versões

Certifique-se de ter instalado em seu ambiente:

| Ferramenta     | Versão Exigida    | Observação                                                      |
| -------------- | ----------------- | --------------------------------------------------------------- |
| **Node.js**    | `>= 22.0.0` (LTS) | Testado e suportado em Node.js 22 LTS e 24 LTS                  |
| **npm**        | `>= 10.0.0`       | Gerenciador de pacotes padrão do Node                           |
| **PostgreSQL** | `15+` (Supabase)  | Instância remota no Supabase ou local via Docker / Supabase CLI |

---

## 3. Instalação

Na raiz do repositório, acesse a pasta `backend` e instale as dependências:

```bash
cd backend
npm install
```

> **Atenção:** O repositório utiliza exclusivamente o arquivo `.gitignore` localizado na **raiz do projeto**. Não crie nenhum `.gitignore` dentro do diretório `backend/`.

---

## 4. Configuração de Variáveis de Ambiente

O backend adota validação **fail-fast** no startup: caso qualquer variável obrigatória esteja ausente ou fora do formato esperado, o processo é encerrado imediatamente antes de abrir portas ou conexões.

### 4.1 Criar o arquivo `.env`

Copie o modelo de exemplo:

```bash
cp .env.example .env
```

### 4.2 Dicionário de Variáveis de Ambiente

| Variável               | Tipo      | Padrão                                 | Obrigatória        | Descrição                                                                                           |
| ---------------------- | --------- | -------------------------------------- | ------------------ | --------------------------------------------------------------------------------------------------- |
| `NODE_ENV`             | `enum`    | `development`                          | Sim                | Ambiente de execução: `development`, `test` ou `production`.                                        |
| `PORT`                 | `number`  | `3000`                                 | Não                | Porta TCP onde o servidor HTTP Fastify escutará.                                                    |
| `HOST`                 | `string`  | `0.0.0.0`                              | Não                | Interface de rede para bind do servidor.                                                            |
| `API_BASE_URL`         | `url`     | `http://localhost:3000`                | Não                | URL base pública do backend.                                                                        |
| `LOG_LEVEL`            | `enum`    | `info`                                 | Não                | Nível de log estruturado: `trace`, `debug`, `info`, `warn`, `error`, `fatal`.                       |
| `DATABASE_URL`         | `string`  | -                                      | **Sim**            | String de conexão PostgreSQL do Supabase (detalhes na seção 5).                                     |
| `DATABASE_SCHEMA`      | `string`  | `app`                                  | Não                | Schema privado do banco onde ficam as tabelas do produto (BA-19).                                   |
| `DATABASE_POOL_MIN`    | `number`  | `2`                                    | Não                | Número mínimo de conexões mantidas no pool `pg`.                                                    |
| `DATABASE_POOL_MAX`    | `number`  | `10`                                   | Não                | Número máximo de conexões no pool `pg`.                                                             |
| `DATABASE_SSL`         | `boolean` | `false`                                | Não                | Ativa SSL/TLS para a conexão com o banco (`true` no Supabase remoto).                               |
| `SESSION_SECRET`       | `string`  | -                                      | **Sim**            | Segredo para hash e autenticação das sessões próprias. Mínimo de 32 caracteres em `production`.     |
| `INVITE_ENVELOPE_KEY`  | `string`  | -                                      | **Sim**            | Chave para envelope de recuperação de ingresso (AES-GCM). Mínimo de 32 caracteres em `production`.  |
| `R2_ACCOUNT_ID`        | `string`  | -                                      | Não (Fase 0)       | ID da conta Cloudflare para armazenamento privado R2.                                               |
| `R2_ACCESS_KEY_ID`     | `string`  | -                                      | Não (Fase 0)       | Credencial de acesso compatível com S3 para o R2.                                                   |
| `R2_SECRET_ACCESS_KEY` | `string`  | -                                      | Não (Fase 0)       | Segredo de acesso compatível com S3 para o R2.                                                      |
| `R2_BUCKET_NAME`       | `string`  | -                                      | Não (Fase 0)       | Nome do bucket R2 onde as mídias privadas serão gravadas.                                           |
| `R2_ENDPOINT`          | `url`     | -                                      | Não (Fase 0)       | Endpoint do bucket R2 no Cloudflare.                                                                |
| `APPLE_CLIENT_ID`      | `string`  | `com.lizandramalta.familyroutine`      | Sim                | Bundle ID do app iOS; audiência esperada no `identityToken`.                                        |
| `APPLE_TEAM_ID`        | `string`  | -                                      | Só em `production` | Team ID da Apple Developer Account (10 caracteres alfanuméricos).                                   |
| `APPLE_KEY_ID`         | `string`  | -                                      | Só em `production` | Key ID da chave do Sign in with Apple (10 caracteres alfanuméricos).                                |
| `APPLE_PRIVATE_KEY`    | `string`  | -                                      | Só em `production` | Chave privada `.p8` do Sign in with Apple, em PEM (`\n` literal aceito). Em `production`, EC P-256. |
| `APPLE_ISSUER`         | `url`     | `https://appleid.apple.com`            | Sim                | Emissor esperado no `identityToken`.                                                                |
| `APPLE_JWKS_URL`       | `url`     | `https://appleid.apple.com/auth/keys`  | Sim                | JWKS com as chaves públicas da Apple.                                                               |
| `APPLE_TOKEN_URL`      | `url`     | `https://appleid.apple.com/auth/token` | Sim                | Endpoint de troca do `authorizationCode`.                                                           |
| `APNS_KEY_ID`          | `string`  | -                                      | Não (Fase 0)       | Key ID para notificações push via APNs.                                                             |
| `APNS_TEAM_ID`         | `string`  | -                                      | Não (Fase 0)       | Team ID da Apple para notificações APNs.                                                            |
| `APNS_TOPIC`           | `string`  | -                                      | Não (Fase 0)       | Bundle ID do app iOS para push notifications.                                                       |
| `APNS_PRIVATE_KEY`     | `string`  | -                                      | Não (Fase 0)       | Chave privada `.p8` do APNs.                                                                        |

As variáveis do Sign in with Apple são opcionais em `development` e `test` para não
bloquear o desenvolvimento local, e obrigatórias com validação estrita em `production`,
onde a chave privada precisa ser criptograficamente válida e EC na curva P-256 (exigência
do client secret ES256) e os três endpoints precisam ser exatamente os canônicos da Apple
(stubs valem apenas em `development` e `test`). O passo a passo de obtenção, formatação e rotação das credenciais está em
[docs/apple-integration-setup.md](docs/apple-integration-setup.md).

---

## 5. Integração com o Supabase

Conforme a decisão **BA-19**, o Supabase é utilizado **estritamente como PostgreSQL gerenciado**. A aplicação possui sua própria gestão de sessões, convites e autorização; recursos como Supabase Auth, Storage, Edge Functions e Realtime não são utilizados.

### 5.1 Conexão com o Supabase Remoto

A string de conexão fica no botão **Connect**, no topo do painel do projeto — em `Connection Method`, escolha `Session pooler` e mantenha `Type` em `URI`.

1. **Modo recomendado (Supavisor em modo sessão, IPv4):**

   ```env
   DATABASE_URL="postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-[N]-[REGION].pooler.supabase.com:5432/postgres"
   DATABASE_SSL=true
   ```

   Use a porta **5432** (sessão), não a 6543 (transação): o modo transação não
   mantém estado entre comandos e quebra as transações de múltiplas instruções
   exigidas pelos casos de uso.

2. **Modo direto (IPv6):**
   ```env
   DATABASE_URL="postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"
   DATABASE_SSL=true
   ```
   O host direto só publica registro `AAAA`. Em rede sem IPv6 a conexão falha com
   `getaddrinfo ENOTFOUND` — nesse caso, use o modo 1.

**Não inclua `?sslmode=require` na URL.** O `pg` trata esse parâmetro como
`verify-full` e a verificação falha com `self-signed certificate in certificate
chain`, porque a cadeia do Supabase não está entre as âncoras padrão do Node. O
TLS é ativado por `DATABASE_SSL=true`. Hoje a conexão é cifrada sem validar a
autoridade emissora; validar exige distribuir o certificado do Supabase e
continua pendente.

Se a senha tiver caracteres reservados de URL (`@`, `/`, `:`, `?`, `#`, `%`),
codifique-os em percent-encoding ou a string é interpretada errado.

### 5.2 Schema Privado `app`

As tabelas do produto são alocadas no schema `app` (`DATABASE_SCHEMA`). O pool passa
`-c search_path=app,public` nas opções de inicialização da conexão, de modo que o
`search_path` já vale na primeira consulta do cliente.

No Supabase, a Data API pública (PostgREST) não deve expor o schema `app`: confira
em `Settings` → `API` → `Exposed schemas` que apenas `public` e `graphql_public`
estão listados. A migration `0001` também retira privilégios de `anon` e
`authenticated` sobre o schema, inclusive para objetos criados depois dela.

### 5.3 Desenvolvimento Local com Supabase CLI (Opcional)

Se optar por rodar uma instância local do Supabase via CLI:

1. **Instalação do Supabase CLI:**
   - macOS (Homebrew): `brew install supabase/tap/supabase`
   - npm/npx: `npx supabase --version`
2. **Iniciar o ambiente local:**
   ```bash
   npx supabase start
   ```
3. **Configuração no `.env`:**
   ```env
   DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
   DATABASE_SSL=false
   ```
4. **Parar o ambiente local:**
   ```bash
   npx supabase stop
   ```

### 5.4 Migrations

O schema é versionado em `database/migrations/` como SQL **forward-only**
(BA-05, `backend-architecture.md` §15). Não há rollback: corrigir é criar uma
migration nova. O schema **não** é sincronizado no boot da API — aplicar é um
passo explícito:

```bash
npm run migrate
```

O comando lê a `DATABASE_URL` do `.env`, aplica os arquivos pendentes em ordem de
nome (cada um em sua própria transação) e registra versão e hash em
`app.schema_migrations`. Rodar de novo sem mudanças não faz nada.

Arquivos seguem `NNNN_descricao_em_ingles.sql`, com número sequencial nunca
reaproveitado. Editar uma migration já aplicada é erro: o hash deixa de bater e o
comando aborta antes de tocar no banco, porque quem já aplicou não receberia a
alteração.

Detalhes da convenção em [`database/migrations/README.md`](database/migrations/README.md).

> Pendência: `backend-architecture.md` §6 exige que migrations usem credencial
> separada e que o papel de runtime não tenha DDL. Hoje ambos usam a mesma
> `DATABASE_URL`. Criar o papel restrito de runtime é trabalho ainda não feito.

---

## 6. Execução dos Ambientes

### 6.1 Ambiente de Desenvolvimento (`development`)

Inicie o servidor HTTP com hot reload via `tsx`:

```bash
npm run dev
```

O servidor iniciará em `http://0.0.0.0:3000`.

### 6.1.1 Documentação OpenAPI / Swagger

Com a API em execução, abra a documentação interativa em
`http://localhost:3000/docs`. A especificação OpenAPI 3.1 gerada pelos schemas
das rotas fica disponível em `http://localhost:3000/docs/json`.

Os endpoints protegidos mostram o esquema **Bearer**. Depois de obter um access
token em um fluxo válido, use o botão **Authorize** para incluí-lo nos testes
interativos. A documentação não gera tokens nem substitui a autorização real da
API.

Para iniciar o processo de Worker (background jobs) em desenvolvimento:

```bash
npm run dev:worker
```

### 6.2 Ambiente de Testes (`test`)

Os testes automatizados utilizam **Vitest** e são configurados via `.env.test` de forma isolada:

```bash
# Executar todos os testes uma única vez
npm run test

# Executar em modo watch (reexecuta ao salvar arquivos)
npm run test:watch

# Gerar relatório de cobertura de código
npm run test:coverage
```

### 6.3 Ambiente de Produção (`production`)

No ambiente de produção, o TypeScript é compilado para JavaScript ESM puro no diretório `dist/`:

1. **Compilar a aplicação:**
   ```bash
   npm run build
   ```
2. **Executar a API HTTP:**
   ```bash
   NODE_ENV=production npm run start
   ```
3. **Executar o Worker em segundo plano:**
   ```bash
   NODE_ENV=production npm run start:worker
   ```

> **Regra de Segurança em Produção:** Em `NODE_ENV=production`, o bootstrap valida obrigatoriamente se `SESSION_SECRET` e `INVITE_ENVELOPE_KEY` possuem no mínimo 32 caracteres seguros.

---

## 7. Scripts Disponíveis

| Comando                 | Descrição                                                                          |
| ----------------------- | ---------------------------------------------------------------------------------- |
| `npm run dev`           | Executa a API HTTP em desenvolvimento com recarregamento automático (`tsx watch`). |
| `npm run dev:worker`    | Executa o Worker de background em desenvolvimento com recarregamento automático.   |
| `npm run build`         | Limpa `dist/` e compila TypeScript estrito para ESM em `dist/`.                    |
| `npm run start`         | Executa a API compilada em `dist/bootstrap/api-main.js` via Node.js puro.          |
| `npm run start:worker`  | Executa o Worker compilado em `dist/bootstrap/worker-main.js`.                     |
| `npm run test`          | Executa a suíte de testes unitários e de integração com Vitest.                    |
| `npm run test:watch`    | Executa testes em modo contínuo de observação.                                     |
| `npm run test:coverage` | Executa testes e exibe cobertura via V8.                                           |
| `npm run lint`          | Executa verificação de código estático via ESLint (TypeScript-ESLint).             |
| `npm run lint:fix`      | Corrige problemas automáticos de lint.                                             |
| `npm run format`        | Formata o código com Prettier.                                                     |
| `npm run format:check`  | Verifica a formatação do código sem alterá-lo.                                     |
| `npm run typecheck`     | Executa checagem de tipos TypeScript sem gerar arquivos (`tsc --noEmit`).          |

---

## 8. Verificação e Endpoints Operacionais

Conforme a seção 6 de `docs/architecture/backend-contracts.md`, o servidor disponibiliza endpoints de monitoramento:

### 8.1 Liveness Probe (`GET /health/live`)

Verifica se o processo Node.js está em execução e respondendo a chamadas HTTP:

```bash
curl http://localhost:3000/health/live
```

**Resposta (HTTP 200):**

```json
{
  "status": "ok",
  "environment": "development",
  "timestamp": "2026-10-06T20:21:01.505Z"
}
```

### 8.2 Readiness Probe (`GET /health/ready`)

Verifica a prontidão da aplicação testando ativamente a conectividade com o banco PostgreSQL (Supabase):

```bash
curl http://localhost:3000/health/ready
```

- **Se o banco estiver conectado (HTTP 200):**
  ```json
  {
    "status": "ready",
    "checks": {
      "database": {
        "status": "healthy",
        "latencyMs": 4
      }
    },
    "timestamp": "2026-10-06T20:21:01.505Z"
  }
  ```
- **Se o banco estiver inacessível (HTTP 503):**
  ```json
  {
    "status": "not_ready",
    "checks": {
      "database": {
        "status": "unhealthy",
        "error": "connect ECONNREFUSED 127.0.0.1:54322"
      }
    },
    "timestamp": "2026-10-06T20:21:01.505Z"
  }
  ```

### 8.3 Informações da API (`GET /v1`)

```bash
curl http://localhost:3000/v1
```

**Resposta (HTTP 200):**

```json
{
  "name": "App Rotina Familiar API",
  "version": "0.1.0",
  "status": "operational",
  "environment": "development",
  "timestamp": "2026-10-06T20:21:01.514Z"
}
```

---

## 9. Tratamento de Erros (RFC 9457 Problem Details)

Todos os erros retornados pela API seguem o padrão `application/problem+json`:

```json
{
  "type": "https://api.rotinafamiliar.com/errors/resource-not-found",
  "title": "NotFoundError",
  "status": 404,
  "code": "RESOURCE_NOT_FOUND",
  "requestId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "detail": "Family member was not found"
}
```

Em ambiente de produção, detalhes internos ou mensagens brutas de erro não são expostos na resposta HTTP.

---

## 10. Estrutura de Diretórios

```text
backend/
├── src/
│   ├── bootstrap/               # Bootstrap, fail-fast config, container e entrypoints
│   │   ├── api-main.ts          # Entrypoint da API HTTP Fastify
│   │   ├── worker-main.ts       # Entrypoint do Worker de background jobs
│   │   ├── configuration.ts     # Validação centralizada de ambiente (Zod)
│   │   └── container.ts         # Injeção e composição de dependências
│   ├── presentation/
│   │   └── http/                # Fastify app, plugins, hooks e error handler (RFC 9457)
│   ├── modules/                 # Módulos de negócio da Clean Architecture
│   │   ├── access/              # Sessões, convites, Sign in with Apple
│   │   ├── family/              # Gestão da família, membros e fusos
│   │   ├── profile/             # Perfil próprio, apelidos, badges
│   │   ├── tasks/               # Tarefas, conclusões e créditos
│   │   ├── routines/            # Rotinas recorrentes e materialização
│   │   ├── kids/                # Sinalização kids e fila de validação
│   │   ├── missions/            # Missões coletivas e conquistas
│   │   ├── rewards/             # Catálogo de recompensas e aceite
│   │   ├── insights/            # Carga familiar e progresso
│   │   ├── reports/             # Snapshot semanal para relatório PDF
│   │   ├── recognition/         # Ciclos e destaque semanal
│   │   ├── media/               # Upload e gerenciamento de mídia privada
│   │   └── notifications/       # APNs e fila de push
│   ├── shared/                  # Código compartilhado entre módulos
│   │   ├── domain/              # LocalDate, MemberRole, DomainError
│   │   ├── application/         # Clock, ActorContext, TransactionRunner
│   │   └── infrastructure/      # Pool Postgres, observabilidade (Logger)
│   └── integrations/            # Clientes externos (Apple, Cloudflare R2, APNs)
├── database/
│   ├── migrations/              # Arquivos SQL de migração versionados
│   └── seeds/                   # Carga inicial (Badges predefinidos, catálogo)
├── contracts/                   # Especificações OpenAPI e esquemas de contrato
├── tests/
│   ├── unit/                    # Testes unitários puros (domain, config, logger)
│   ├── integration/             # Testes integrados com banco e adaptadores
│   └── contract/                # Testes de conformidade de contrato HTTP
├── .env.example                 # Modelo de variáveis de ambiente
├── .env.test                    # Variáveis para execução de testes locais
├── package.json                 # Dependências e scripts
└── tsconfig.json                # Configuração TypeScript estrita
```

---

## 11. Troubleshooting

### Erro: `Fail-fast: Environment configuration validation failed: - [DATABASE_URL]: Required`

- **Causa:** O arquivo `.env` não existe ou a variável `DATABASE_URL` não está definida.
- **Solução:** Execute `cp .env.example .env` e configure sua URL de conexão PostgreSQL.

### Erro: `connect ECONNREFUSED 127.0.0.1:54322` no `/health/ready`

- **Causa:** O servidor iniciou, mas a instância do PostgreSQL local não está em execução.
- **Solução:** Inicie o banco local com `npx supabase start` ou aponte `DATABASE_URL` para sua instância remota no Supabase.

### Erro de SSL ao conectar no Supabase remoto

- **Causa:** Conexões com o Supabase exigem SSL/TLS ativo.
- **Solução:** Configure `DATABASE_SSL=true` no arquivo `.env` e assegure-se de que a URL contenha `?sslmode=require`.

### Arquivo `.gitignore` não encontrado dentro de `backend/`

- **Comportamento esperado:** O repositório segue a regra estrita de manter exclusivamente o `.gitignore` na **raiz do projeto**. Nenhuma alteração de ignore deve ser feita dentro de `backend/`.
