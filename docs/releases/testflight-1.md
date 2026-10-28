# Mutua — primeira distribuição no TestFlight

**Versão:** 1.10
**Data:** 2026-10-28  
**Branch:** `release-testflight`, criada de `origin/develop` (`e2af94a`)

## Escopo

Esta distribuição se chama **Mutua** e atende Administradores e Membros adultos:
acesso Apple/convites, família, membros adultos, perfil sem fotos, tarefas únicas,
rotinas, conclusão/reabertura e consultas pessoais/familiares. A carga familiar
e o incentivo “Parabenizar” permanecem quando já disponíveis.

Ficam adiados: criação e uso de perfis Kids, sinalização/validação Kids,
missões, recompensas coletivas, badges, relatório PDF e upload de fotos via R2.
O recorte é exclusivo do app Mutua: suas telas não oferecem esses recursos nem
acionam suas rotas. Se receber uma sessão Kids, o app mostra uma tela de
indisponibilidade com ação **Sair**. A API de produção continua compartilhada
com o desenvolvimento, com as mesmas rotas, permissões e dados; não há canal
de backend para TestFlight nem deploy de backend exigido por este recorte.

O bundle ID do app e dos testes passou a usar `com.lizandramalta.mutua`.
Esta troca exige registrar um novo App ID na Apple e alinhar a configuração
do backend de produção (`APPLE_CLIENT_ID`), a associação de Universal Links
no Worker (`55Z24S2H7V.com.lizandramalta.mutua`) e, se APNs estiver ativo,
o tópico de push. Até esses vínculos serem atualizados, o build novo não
consegue concluir o acesso Apple nem abrir convites por Universal Link.
O serviço do Keychain do app também passou a usar o novo identificador; a
instalação nova não reaproveita a sessão local da instalação antiga.
O Render aceita o `APPLE_CLIENT_ID` do Mutua. A usuária confirmou que não é
necessário manter login Apple para o bundle ID antigo; a versão de
desenvolvimento será atualizada depois para o novo nome/identificador.

Esta é uma decisão de **escopo de distribuição**; a base funcional e as specs
aprovadas continuam a descrever o produto completo. Rastreabilidade afetada:
RN21–24, RN38, RN42, RN53–58, RN62–64; RF23–24, RF34, RF48, RF55–56,
RF61–66; UC03, UC05–06, UC10, UC15–18; SPEC/UX-003, 006, 007,
009–017 e 019. O corte afeta a navegação, o perfil, a família, TEL-011 e o
uso das rotas HTTP `/v1` pelo app, sem alterar o contrato da API.

## Critérios da branch

- **CA-01 — API compartilhada:** o backend e seu OpenAPI permanecem iguais aos
  de `develop`; a distribuição Mutua não registra nem exige um canal próprio.
- **CA-02 — Papéis na interface:** o app não oferece criação/transição para
  Kids nem sua navegação; ao receber uma sessão Kids, mostra indisponibilidade
  com ação **Sair**.
- **CA-03 — App:** o build mostra Mutua e o ícone fornecido, com abas adultas
  Tarefas, Família e Perfil; não oferece missões, recompensas, badges,
  confirmação Kids nem PDF.
- **CA-04 — Convites:** bundle ID, Team ID, entitlement e AASA devem concordar;
  a página de fallback e a mensagem de convite mostram Mutua.
- **CA-05 — Release:** um arquivo iOS Release assinado abre em dispositivo,
  usa a API publicada e completa Apple → família → convite → tarefa →
  rotina → conclusão/reabertura antes do upload.

## Verificado localmente

- Backend: o código da branch é igual ao de `origin/develop`; não há teste ou
  configuração de rotas exclusivos do TestFlight.
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
- A usuária confirmou que o link de convite abre no app Mutua e que o ingresso
  na família pelo convite foi concluído.
- A usuária confirmou o QA do fluxo principal e a ausência dos recursos
  adiados antes do envio. O Xcode concluiu o upload do arquivo iOS `1.0 (1)`
  em 2026-10-28 às 14:02 BRT. O App Store Connect recebeu a compilação com
  status **Processando**; a liberação para testadores depende do fim desse
  processamento e das informações de teste exigidas pela Apple.

## Antes de convidar testadores

1. Usar a API de produção existente, já configurada com
   `APPLE_CLIENT_ID=com.lizandramalta.mutua`; o login Apple foi confirmado
   pela usuária. A API mantém todas as rotas de `develop`; o app Mutua não
   apresenta nem chama as capacidades adiadas.
2. O Worker existente já inclui o novo App ID no AASA; o link abre no app
   Mutua e a usuária confirmou o ingresso pelo convite. Não é necessário
   criar outro Worker ou domínio.
3. O App ID `com.lizandramalta.mutua` foi registrado no time `55Z24S2H7V`;
   a usuária informou que a validação da assinatura passou. Confirmar Push
   Notifications se o app usar APNs nesta distribuição.
4. O registro **Mutua** foi criado no App Store Connect, o arquivo passou na
   validação e o build `1.0 (1)` foi enviado. Acompanhar o processamento da
   Apple e conferir se há erros ou avisos antes de atribuí-lo a um grupo.
5. Preencher descrição beta, o que testar e e-mail de feedback. Para teste
   externo, preencher os dados de revisão beta, dar instruções de acesso
   por convite e submeter o primeiro build à revisão. Responder à declaração
   de criptografia/export compliance.
6. A usuária confirmou o QA do fluxo principal e a ausência dos recursos
   adiados no app. Antes de convidar outros testadores, conferir também em
   iPhone e iPad a rede intermitente e o isolamento entre famílias, se esses
   cenários ainda não estiverem cobertos pela validação realizada.

Fontes da Apple: [registro do app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/),
[upload de builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/),
[dados de teste](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/),
[testadores externos](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)
e [export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/).
