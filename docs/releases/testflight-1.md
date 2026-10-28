# Mutua — primeira distribuição no TestFlight

**Versão:** 1.6
**Data:** 2026-10-28  
**Branch:** `release-testflight`, criada de `origin/develop` (`e2af94a`)

## Escopo

Esta distribuição se chama **Mutua** e atende Administradores e Membros adultos:
acesso Apple/convites, família, membros adultos, perfil sem fotos, tarefas únicas,
rotinas, conclusão/reabertura e consultas pessoais/familiares. A carga familiar
e o incentivo “Parabenizar” permanecem quando já disponíveis.

Ficam adiados: criação e uso de perfis Kids, sinalização/validação Kids,
missões, recompensas coletivas, badges, relatório PDF e upload de fotos via R2.
Sessões Kids antigas
recebem uma tela de indisponibilidade com ação **Sair**, sem acesso a operações
protegidas. O canal `RELEASE_CHANNEL=testflight` retira as rotas adiadas da
API, rejeita novo papel Kids e bloqueia sessões Kids antigas. Nesta branch,
`NODE_ENV=production` usa esse canal por padrão; `development` e `test` usam
`full`. As migrations e os dados antigos são preservados.

O bundle ID do app e dos testes passou a usar `com.lizandramalta.mutua`.
Esta troca exige registrar um novo App ID na Apple e alinhar a configuração
do backend de produção (`APPLE_CLIENT_ID`), a associação de Universal Links
no Worker (`55Z24S2H7V.com.lizandramalta.mutua`) e, se APNs estiver ativo,
o tópico de push. Até esses vínculos serem atualizados, o build novo não
consegue concluir o acesso Apple nem abrir convites por Universal Link.
O serviço do Keychain do app também passou a usar o novo identificador; a
instalação nova não reaproveita a sessão local da instalação antiga.

Esta é uma decisão de **escopo de distribuição**; a base funcional e as specs
aprovadas continuam a descrever o produto completo. Rastreabilidade afetada:
RN21–24, RN38, RN42, RN53–58, RN62–64; RF23–24, RF34, RF48, RF55–56,
RF61–66; UC03, UC05–06, UC10, UC15–18; SPEC/UX-003, 006, 007,
009–017 e 019. O corte afeta a navegação, o perfil, a família, TEL-011 e o
contrato HTTP `/v1`.

## Critérios da branch

- **CA-01 — API:** em `testflight`, recursos adiados não aparecem no OpenAPI
  nem respondem; tarefas e membros adultos permanecem registrados.
- **CA-02 — Papéis:** criação/transição para Kids é recusada; sessão Kids
  antiga não acessa recursos protegidos e pode encerrar a sessão.
- **CA-03 — App:** o build mostra Mutua e o ícone fornecido, com abas adultas
  Tarefas, Família e Perfil; não oferece missões, recompensas, badges,
  confirmação Kids nem PDF.
- **CA-04 — Convites:** bundle ID, Team ID, entitlement e AASA devem concordar;
  a página de fallback e a mensagem de convite mostram Mutua.
- **CA-05 — Release:** um arquivo iOS Release assinado abre em dispositivo,
  usa a API publicada e completa Apple → família → convite → tarefa →
  rotina → conclusão/reabertura antes do upload.

## Verificado localmente

- Backend: typecheck, lint, build e testes unitários; o teste
  `testflight-release-routes.test.ts` cobre CA-01/02.
- Mobile: build `Release` para iOS Simulator e 348 testes unitários aprovados
  com Xcode 27 e assinatura desativada; testes de interface confirmaram a
  entrada Mutua e a ausência de fotos no onboarding e no perfil.
- Ícone 1024×1024 sem canal alfa integrado ao catálogo `AppIcon`.
- O mobile não oferece captura ou seleção de foto, não envia mídia no
  onboarding e não baixa fotos de perfil. A permissão de câmera foi removida.
- Em 2026-10-28, `/health/live` e `/health/ready` do Render responderam `200`
  (banco saudável). O AASA público declarava apenas o ID antigo
  `55Z24S2H7V.com.lizandramalta.familyroutine` para `/invite/*`.
  O Worker existente foi publicado em 2026-10-28 com os dois IDs. O AASA
  público atualizado e a página de fallback Mutua foram conferidos após o
  deploy; respostas em cache podem continuar mostrando o ID antigo por até
  uma hora. O domínio de produção segue ativo e as URLs de prévia estão
  desativadas.
- Em 2026-10-28, `APPLE_CLIENT_ID=com.lizandramalta.mutua` foi salvo no
  serviço de produção existente no Render. O deploy
  `dep-dbh2ekm7bikc73ei9st0` terminou como **Live**; nenhuma migration nova
  foi aplicada. Após o deploy, a usuária confirmou que conseguiu entrar no
  app Mutua com o login Apple.

## Antes de convidar testadores

1. Usar a API de produção existente, já configurada com
   `APPLE_CLIENT_ID=com.lizandramalta.mutua`; o login Apple foi confirmado
   pela usuária. O canal `RELEASE_CHANNEL=testflight`
   desta branch só passa a valer se o código backend for implantado no serviço
   existente; até lá, as rotas adiadas continuam disponíveis na API.
2. Atualizar o Worker existente para incluir o novo App ID no AASA e testar
   o convite real em iPhone/iPad com o build assinado. Não é necessário criar
   outro Worker ou domínio.
3. Registrar o App ID `com.lizandramalta.mutua` no time `55Z24S2H7V` com
   Sign in with Apple, Associated Domains e Push Notifications quando usado;
   gerar assinatura de distribuição.
   Este Mac ainda não tem uma identidade de assinatura válida instalada.
4. Criar ou conferir o registro **Mutua** no App Store Connect com o bundle
   ID existente. Confirmar versão `1.0`, aumentar o build number se `1` já
   tiver sido enviado, arquivar em Release e validar em dispositivo físico.
5. Preencher descrição beta, o que testar e e-mail de feedback. Para teste
   externo, preencher os dados de revisão beta, dar instruções de acesso
   por convite e submeter o primeiro build à revisão. Responder à declaração
   de criptografia/export compliance.
6. Fazer QA em iPhone e iPad: Apple Sign In, onboarding, convite, sessão,
   tarefa, recorrência, perfil sem foto, rede intermitente e isolamento entre
   famílias. Confirmar a ausência dos recursos adiados no app e na API beta.

Fontes da Apple: [registro do app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/),
[upload de builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/),
[dados de teste](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/),
[testadores externos](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)
e [export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/).
