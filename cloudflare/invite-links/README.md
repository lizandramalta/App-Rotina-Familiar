# Hospedagem dos convites

O Worker `convites` serve `https://convites.rotina-familiar.workers.dev` na conta Cloudflare do projeto. Ele publica:

- `/.well-known/apple-app-site-association`, com o identificador do app iOS e a rota `/invite/*`;
- `/invite/<token>`, página neutra para quem abriu o convite sem o app instalado.

O Worker não consulta nem consome o convite. A senha é solicitada apenas dentro do app. A página não insere o token no HTML, não usa scripts externos e impede cache e envio do link como referer.

O backend emite links com `INVITE_LINK_BASE_URL=https://convites.rotina-familiar.workers.dev`. Os builds mobile usam `INVITE_LINK_HOST=convites.rotina-familiar.workers.dev` e o `INVITE_LINK_BASE_URL` correspondente. Para atualizar a hospedagem, use `wrangler deploy` nesta pasta com acesso à mesma conta Cloudflare. A instalação via App Store ainda depende da publicação do app; até lá, quem recebe o convite precisa instalar a versão de teste distribuída pela equipe e reabrir o link.

Na branch `release-testflight`, a página de fallback usa o nome Mutua. O app
agora usa `com.lizandramalta.mutua`, mas o AASA publicado ainda declara apenas
`55Z24S2H7V.com.lizandramalta.familyroutine`. Atualizar o Worker existente
para incluir `55Z24S2H7V.com.lizandramalta.mutua` é uma etapa pendente antes
de testar os Universal Links.
