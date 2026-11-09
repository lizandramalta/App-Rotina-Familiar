# Mutua — segunda distribuição no TestFlight

**Data:** 2026-11-09  
**Branch:** `chore/testflight-mutua-config`, criada de `develop` (`98fd7b3`)  
**Build:** `1.0 (3)` — o último build no App Store Connect é `1.0 (2)`

## Escopo

Esta distribuição leva o **produto completo** de `develop`. O recorte da
[primeira distribuição](testflight-1.md) deixa de valer: Kids, sinalização e
validação Kids, missões, recompensas, reconhecimento semanal com
compartilhamento e fotos de perfil voltam a ficar disponíveis no app.

A decisão é de escopo de distribuição. A base funcional (RN 1.26, RF 1.25,
UC 1.25) e as specs aprovadas já descrevem o produto completo e não mudam.

## O que foi trazido da `release-testflight`

- **Identidade Mutua:** bundle ID `com.lizandramalta.mutua` no app e nos
  testes, `CFBundleDisplayName` Mutua, ícone `Mutua.png`, serviço do Keychain
  `com.lizandramalta.mutua.access` e textos de boas-vindas e de convite com o
  nome Mutua.
- **Backend:** valores padrão de `APPLE_CLIENT_ID` e `APNS_TOPIC` alinhados ao
  bundle ID Mutua, sem mudança de rota ou contrato.
- **Worker de convites:** AASA com os App IDs antigo e Mutua, página de
  fallback Mutua e `preview_urls: false`, iguais ao que já está publicado.
- **Correções do primeiro TestFlight (PR #39):** renovação silenciosa do token
  de acesso antes da expiração, uma renovação e nova tentativa após um 401
  inesperado em Tarefas e Família, confirmação transitória após criar tarefa
  ou rotina e card de falha da Família apenas quando não há dados na tela.

## O que não foi trazido

- O corte de escopo (telas removidas, tela de indisponibilidade para Kids,
  remoção da câmera e do WhatsApp).
- A retirada dos aplausos recebidos da checklist. Ela contraria o
  comportamento vigente de `develop` e do SCRUM-103; continua fora até ser
  decidida e registrada em spec.

## Permissões e serviços

- O app volta a declarar a câmera (`NSCameraUsageDescription`) e a consulta ao
  WhatsApp (`LSApplicationQueriesSchemes`).
- Fotos dependem do R2 configurado no backend de produção.
- Push de aplausos e de reconhecimento semanal depende do APNs com
  `APNS_TOPIC=com.lizandramalta.mutua` e da capacidade Push Notifications no
  App ID.

## Antes do upload

1. Confirmar que o backend de produção está na versão de `develop`, com as
   migrations `0016_create_weekly_recognitions`,
   `0016_mission_reward_acceptance` e `0017_index_weekly_recognition_credits`
   aplicadas, e com R2 e APNs configurados.
2. Arquivar em Release com o `Production.xcconfig` local e conferir o build
   `1.0 (3)`.
3. Em dispositivo: Apple → família → convite → tarefa → rotina →
   conclusão/reabertura; perfil Kids, sinalização e validação; missão e
   recompensa; reconhecimento semanal; foto de perfil; e sessão aberta por
   mais de 15 minutos sem perder o acesso.
4. Atualizar “O que testar” no App Store Connect com os recursos novos.

A política de privacidade fica fora desta entrega. O build interno não exige a
URL; para o grupo externo, a revisão beta pode solicitá-la, já que o app passa
a tratar fotos e dados de crianças.
