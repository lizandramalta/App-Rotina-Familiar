# Site do Mora

Site estático do app Mora: landing page (`/`), política de privacidade (`/privacidade/`) e suporte (`/suporte/`). As URLs de privacidade e de suporte são as cadastradas no App Store Connect.

É feito só com HTML e CSS, sem build nem scripts. As cores seguem os tokens de `Color.App` (`docs/design/design-system.md`), os títulos usam a fonte Sour Gummy do app e o ícone é o mesmo `AppIcon`.

## Visualizar localmente

```sh
python3 -m http.server 4173 --directory site
```

Depois, abra `http://localhost:4173`.

## Publicar (Cloudflare Pages)

O site usa a mesma conta Cloudflare do Worker de convites (`cloudflare/invite-links/`). Na raiz do repositório:

```sh
npx wrangler pages deploy site --project-name mora-app
```

Na primeira execução, o Wrangler cria o projeto `mora-app` e o site fica em `https://mora-app.pages.dev`. Os cabeçalhos de segurança ficam em `_headers`.

## Manutenção da política de privacidade

O texto de `privacidade/index.html` descreve o tratamento de dados definido no modelo de dados (`docs/05-modelo-de-dados.md`) e na exclusão de conta (SPEC-022). Quando o app passar a coletar um dado novo, usar outro fornecedor ou mudar a retenção, atualize a política e a data de vigência no mesmo PR.
