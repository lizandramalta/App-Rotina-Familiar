# Mutua — primeira distribuição no TestFlight

**Versão:** 1.0  
**Data:** 2026-10-28  
**Branch:** `release-testflight`, criada de `origin/develop` (`e2af94a`)

## Escopo

Esta distribuição se chama **Mutua** e atende Administradores e Membros adultos:
acesso Apple/convites, família, membros adultos, perfil, tarefas únicas,
rotinas, conclusão/reabertura e consultas pessoais/familiares. A carga familiar
e o incentivo “Parabenizar” permanecem quando já disponíveis.

Ficam adiados: criação e uso de perfis Kids, sinalização/validação Kids,
missões, recompensas coletivas, badges e relatório PDF. Sessões Kids antigas
recebem uma tela de indisponibilidade com ação **Sair**, sem acesso a operações
protegidas. O canal `RELEASE_CHANNEL=testflight` retira as rotas adiadas da
API, rejeita novo papel Kids e bloqueia sessões Kids antigas. Nesta branch,
`NODE_ENV=production` usa esse canal por padrão; `development` e `test` usam
`full`. As migrations e os dados antigos são preservados.

O bundle ID técnico continua `com.lizandramalta.familyroutine` para manter
Sign in with Apple, assinatura, Universal Links e APNs. A mudança do nome de
exibição não exige trocar o identificador.

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
- **CA-04 — Convites:** bundle ID, Team ID, entitlement e AASA concordam;
  a página de fallback e a mensagem de convite mostram Mutua.
- **CA-05 — Release:** um arquivo iOS Release assinado abre em dispositivo,
  usa a API publicada e completa Apple → família → convite → tarefa →
  rotina → conclusão/reabertura antes do upload.

## Verificado localmente

- Backend: typecheck, lint, build e testes unitários; o teste
  `testflight-release-routes.test.ts` cobre CA-01/02.
- Mobile: build `Release` para iOS Simulator e 345 testes unitários aprovados
  com Xcode 27 e assinatura desativada; o teste de interface da entrada
  confirmou o título Mutua e a ação de acesso com Apple.
- Ícone 1024×1024 sem canal alfa integrado ao catálogo `AppIcon`.
- Em 2026-10-28, `/health/live` e `/health/ready` do Render responderam `200`
  (banco saudável), e
  o AASA público declarou `55Z24S2H7V.com.lizandramalta.familyroutine`
  para `/invite/*`. Isso não confirma a versão do código implantado.

## Antes de convidar testadores

1. Implantar o backend desta branch, conferir `RELEASE_CHANNEL=testflight`,
   migrations e `/health/ready`. Se outros clientes usam as rotas adiadas,
   publicar a API beta em serviço separado e apontar o `Production.xcconfig`
   para ele. Conferir R2, credenciais Apple e URL de convite.
2. Publicar a nova cópia do Worker e testar o convite real em iPhone/iPad
   com o build assinado. O AASA publicado já tem o identificador correto.
3. Confirmar App ID do time `55Z24S2H7V` com Sign in with Apple,
   Associated Domains e Push Notifications; gerar assinatura de distribuição.
   Este Mac ainda não tem uma identidade de assinatura válida instalada.
4. Criar ou conferir o registro **Mutua** no App Store Connect com o bundle
   ID existente. Confirmar versão `1.0`, aumentar o build number se `1` já
   tiver sido enviado, arquivar em Release e validar em dispositivo físico.
5. Preencher descrição beta, o que testar e e-mail de feedback. Para teste
   externo, preencher os dados de revisão beta, dar instruções de acesso
   por convite e submeter o primeiro build à revisão. Responder à declaração
   de criptografia/export compliance.
6. Fazer QA em iPhone e iPad: Apple Sign In, onboarding, convite, sessão,
   tarefa, recorrência, perfil/foto, rede intermitente e isolamento entre
   famílias. Confirmar a ausência dos recursos adiados no app e na API beta.

Fontes da Apple: [registro do app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/),
[upload de builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/),
[dados de teste](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/),
[testadores externos](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)
e [export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/).
