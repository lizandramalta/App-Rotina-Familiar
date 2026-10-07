/**
 * Aplicador de migrations SQL forward-only (BA-05, backend-architecture.md §15).
 *
 * Lê `database/migrations/*.sql` em ordem de nome, aplica as pendentes — cada uma
 * em sua própria transação — e registra versão e hash em `app.schema_migrations`.
 * O schema nunca é sincronizado no boot da API: migração é um passo explícito.
 */
import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import { loadConfiguration, ConfigurationError } from '../src/bootstrap/configuration.js';

const MIGRATIONS_DIR = join(dirname(fileURLToPath(import.meta.url)), 'migrations');

const checksumOf = (sql: string): string => createHash('sha256').update(sql).digest('hex');

async function main(): Promise<void> {
  const config = loadConfiguration();

  const client = new pg.Client({
    connectionString: config.DATABASE_URL,
    ssl: config.DATABASE_SSL ? { rejectUnauthorized: false } : false,
  });
  await client.connect();

  try {
    // Bootstrap do próprio registro: idempotente e anterior a qualquer migration.
    await client.query('create schema if not exists app');
    await client.query(`
      create table if not exists app.schema_migrations (
        version    text        primary key,
        checksum   text        not null,
        applied_at timestamptz not null default now()
      )
    `);

    // No Supabase os roles `anon` e `authenticated` já existem; em um Postgres
    // limpo (CI, instalação local) não, e as migrations que revogam privilégios
    // deles falhariam. Criá-los aqui mantém o SQL das migrations intocado.
    // O catch cobre bancos gerenciados onde o usuário não pode criar roles:
    // nesse caso os roles já existem e seguir adiante é seguro.
    try {
      await client.query(`
        do $$
        begin
          if not exists (select from pg_roles where rolname = 'anon') then
            create role anon;
          end if;
          if not exists (select from pg_roles where rolname = 'authenticated') then
            create role authenticated;
          end if;
        end
        $$;
      `);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.log(`aviso: não foi possível garantir os roles anon/authenticated (${message})`);
    }

    const applied = new Map<string, string>(
      (
        await client.query<{ version: string; checksum: string }>(
          'select version, checksum from app.schema_migrations',
        )
      ).rows.map((r) => [r.version, r.checksum]),
    );

    const files = (await readdir(MIGRATIONS_DIR)).filter((f) => f.endsWith('.sql')).sort();
    let appliedNow = 0;

    for (const file of files) {
      const sql = await readFile(join(MIGRATIONS_DIR, file), 'utf8');
      const checksum = checksumOf(sql);
      const previous = applied.get(file);

      if (previous === checksum) {
        continue;
      }
      if (previous !== undefined) {
        throw new Error(
          `A migration "${file}" já foi aplicada e seu conteúdo mudou. ` +
            'Migrations são forward-only: crie um arquivo novo em vez de editar este.',
        );
      }

      await client.query('begin');
      try {
        await client.query(sql);
        await client.query(
          'insert into app.schema_migrations (version, checksum) values ($1, $2)',
          [file, checksum],
        );
        await client.query('commit');
      } catch (error) {
        await client.query('rollback');
        throw new Error(`Falha ao aplicar "${file}": ${(error as Error).message}`);
      }

      console.log(`aplicada: ${file}`);
      appliedNow += 1;
    }

    console.log(
      appliedNow === 0
        ? `nenhuma migration pendente (${files.length} já aplicadas)`
        : `${appliedNow} migration(s) aplicada(s); ${files.length} no total`,
    );
  } finally {
    await client.end();
  }
}

main().catch((error: unknown) => {
  const message = error instanceof ConfigurationError ? error.message : (error as Error).message;
  console.error(`\x1b[31m${message}\x1b[0m`);
  process.exit(1);
});
