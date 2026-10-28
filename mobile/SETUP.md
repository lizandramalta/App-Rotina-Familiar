# Configuração do mobile

O aplicativo fica em `mobile/` e usa SwiftUI para iOS/iPadOS 26 ou posterior.
O passo a passo completo de onboarding do repositório está no
[README principal](../README.md#como-executar-localmente-onboarding-rápido);
este documento detalha a parte mobile.

## Pré-requisitos

- Xcode 26 ou superior, com o simulador iOS correspondente ao target 26.0.
- Xcode completo selecionado para as ferramentas de linha de comando
  (`sudo xcode-select -s /Applications/Xcode.app`).

## Primeiro uso

1. Crie os arquivos locais de ambiente a partir dos templates:

   ```sh
   cp Configuration/Development.xcconfig.example Configuration/Development.xcconfig
   cp Configuration/Production.xcconfig.example Configuration/Production.xcconfig
   ```

2. Preencha `API_BASE_URL` com o endpoint apropriado ao ambiente. Com o backend rodando
   localmente conforme o README, use `http://localhost:3000/v1` no simulador — em
   dispositivo físico, troque `localhost` pelo IP da máquina na mesma rede. O template
   `Production.xcconfig.example` já aponta o build Release para
   `https://app-rotina-familiar.onrender.com/v1`. Para ingressar
   por convite via Universal Link, configure `INVITE_LINK_HOST` e `INVITE_LINK_BASE_URL`
   com o mesmo domínio HTTPS de `INVITE_LINK_BASE_URL` no backend. Esse domínio precisa
   servir o arquivo de associação do aplicativo (AASA) e corresponder ao entitlement
   `applinks`. O host configurado é `convites.rotina-familiar.workers.dev`;
   o Worker e seu código estão em `cloudflare/invite-links/`.
   Esses arquivos são ignorados pelo Git; não inclua segredos, pois o app não armazena
   credenciais de infraestrutura.

   Para testar um convite real no simulador com o backend publicado, configure
   `API_BASE_URL = https:/$()/app-rotina-familiar.onrender.com/v1` no arquivo local
   `Development.xcconfig`. Esse build Debug passa a usar os dados do ambiente de
   produção no Render; ao voltar a testar o backend local, restaure a URL local.
3. Abra `mobile.xcodeproj` no Xcode, escolha o scheme `FamilyRoutine` e um simulador iOS/iPadOS 26.
4. Execute o aplicativo ou os testes pelo Xcode.

## Linha de comando

Compilar para simulador, sem exigir assinatura de código (igual ao que a CI faz):

```sh
xcodebuild build \
  -project mobile.xcodeproj \
  -scheme FamilyRoutine \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Rodar os `FoundationTests` em um simulador concreto:

```sh
xcrun simctl list devices available        # veja os simuladores instalados
xcodebuild test \
  -project mobile.xcodeproj \
  -scheme FamilyRoutine \
  -destination 'platform=iOS Simulator,name=<simulador instalado>'
```

O nome do simulador varia por máquina e por versão do Xcode, por isso a CI resolve o UDID
do primeiro iPhone disponível em vez de fixar um modelo.

## Primeira distribuição TestFlight

A branch `release-testflight` mostra Mutua para perfis adultos. O ícone está em
`AppIcon`, e o recorte da release está em
[docs/releases/testflight-1.md](../docs/releases/testflight-1.md). Antes de
arquivar, confira o `Production.xcconfig` local, a API beta e a assinatura.
