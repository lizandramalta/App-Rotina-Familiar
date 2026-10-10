# Migrations

SQL versionado e **forward-only** (`backend-architecture.md` §15). Não há rollback:
uma correção é sempre uma migration nova.

## Convenção

Arquivos `NNNN_descricao_em_ingles.sql`, aplicados em ordem crescente do nome. O
identificador persistido em `app.schema_migrations` é o **nome completo do arquivo**,
não apenas o prefixo numérico. Há prefixos históricos repetidos (`0005` e `0007`), que
não podem ser renomeados depois de aplicados. Para novas migrations, use o próximo
prefixo ainda não usado (atualmente `0008`) e não reutilize prefixos daqui em diante.

Cada arquivo roda dentro de uma transação. Se falhar, nada daquele arquivo é
aplicado e o processo para — as migrations seguintes não rodam.

## Registro

O controle do que já foi aplicado fica em `app.schema_migrations`, junto com o
hash do arquivo. Alterar uma migration já aplicada é erro: o runner compara o
hash e aborta, porque o banco de quem já rodou não teria como receber a mudança.

## Como rodar

```bash
npm run migrate
```

Usa a `DATABASE_URL` do `.env`. Ver `../../README.md` §5.
