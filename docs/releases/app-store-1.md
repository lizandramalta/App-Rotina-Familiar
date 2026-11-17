# Mora — preparação da primeira publicação na App Store

**Data:** 2026-11-16  
**Branch:** `chore/mora-app-icon`, criada de `develop` (`cd909a3`)  
**Build:** `1.0 (4)`. O último build enviado ao App Store Connect é o `1.0 (3)`, do
[segundo TestFlight](testflight-2.md).

## Escopo

O nome público do app passa de Mutua para **Mora**, e o bundle ID
`com.lizandramalta.mutua` continua o mesmo. É uma decisão de identidade e de
distribuição: a base funcional (regras, requisitos e casos de uso) não muda.
O nome leva artigo masculino nos textos: “o Mora”.

## O que muda

- `CFBundleDisplayName` passa a ser `Mora`.
- Ícone provisório próprio, `Mora.png` (1024×1024, sem transparência), no lugar
  de `Mutua.png`. O ícone anterior reproduzia um SF Symbol, e a licença dos SF
  Symbols proíbe esse uso em ícone de app.
- Textos de boas-vindas (“Bem-vindo ao Mora”) e da mensagem de convite (“no
  Mora”), além do título da galeria do Design System.
- `ITSAppUsesNonExemptEncryption = NO` no `Info.plist`: o app usa apenas a
  criptografia padrão do sistema (HTTPS e Keychain).
- `CURRENT_PROJECT_VERSION` passa para `4`.
- O app fica disponível só em iPhone e iPad: `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD`,
  `SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD` e `SUPPORTS_MACCATALYST` passam a `NO`.
  No App Store Connect, em Preço e disponibilidade, desmarque também a
  disponibilidade em Mac e Apple Vision Pro.
- A página de fallback do Worker de convites passa a exibir o nome Mora.

## O que não muda

- O bundle ID `com.lizandramalta.mutua` e o App ID `55Z24S2H7V.com.lizandramalta.mutua`
  no AASA.
- O serviço do Keychain `com.lizandramalta.mutua.access`. Se ele mudar, as
  sessões abertas se perdem.
- `APPLE_CLIENT_ID` e `APNS_TOPIC` no backend.
- Os domínios da API e dos convites, além dos nomes internos de target e
  projeto (`FamilyRoutine`).

## Pendências antes do envio para revisão

1. **Exclusão de conta dentro do app** (diretriz 5.1.1(v) da App Store), com
   revogação do Sign in with Apple. Em especificação na SPEC-022 / UX-022.
2. **Política de privacidade e URL de suporte**, ambas obrigatórias na App
   Store. O site estático em `site/` tem a landing, a política
   (`/privacidade/`) e o suporte (`/suporte/`). Antes de publicar com
   `npx wrangler pages deploy site --project-name mora-app`, confirmar que a
   política reflete a SPEC-022 implementada e, de preferência, passar por
   revisão jurídica, já que o app trata fotos e dados de crianças. Também
   faltam os questionários de privacidade (App Privacy) e de classificação
   etária no App Store Connect.
3. **Nome na loja:** confirmar no App Store Connect que “Mora” está disponível.
4. **Capturas de tela** de iPhone 6,9" e iPad 13", porque o app aceita iPad.
5. **Notas para a revisão:** como testar os perfis Kids e Membro (convite e
   senha) e confirmar que o backend de produção responde sem atraso de
   inicialização.
6. **Worker de convites:** publicar a página de fallback com o nome Mora usando
   `wrangler deploy` em `cloudflare/invite-links/`.
