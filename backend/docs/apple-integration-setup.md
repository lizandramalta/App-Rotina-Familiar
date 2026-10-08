# Configuração do Sign in with Apple no backend

**Situação:** guia operacional de setup
**Rastreabilidade:** BA-01, BA-04, [SPEC-001](../../specs/SPEC-001-autenticar-com-apple.md)

Este guia descreve como obter as credenciais da Apple e injetá-las no backend.
Ele cobre apenas a preparação da configuração: a rota `POST /access/apple` e a
emissão de sessão são entregas posteriores.

## 1. O que o backend precisa

| Variável            | Origem                   | Formato                     | Obrigatória        |
| ------------------- | ------------------------ | --------------------------- | ------------------ |
| `APPLE_CLIENT_ID`   | Bundle ID do app iOS     | identificador reverso       | sim (tem default)  |
| `APPLE_TEAM_ID`     | Membership details       | 10 caracteres alfanuméricos | só em `production` |
| `APPLE_KEY_ID`      | Chave Sign in with Apple | 10 caracteres alfanuméricos | só em `production` |
| `APPLE_PRIVATE_KEY` | Arquivo `.p8`            | PEM                         | só em `production` |
| `APPLE_ISSUER`      | Apple                    | URL                         | sim (tem default)  |
| `APPLE_JWKS_URL`    | Apple                    | URL                         | sim (tem default)  |
| `APPLE_TOKEN_URL`   | Apple                    | URL                         | sim (tem default)  |

Em `development` e `test` o backend sobe sem `APPLE_TEAM_ID`, `APPLE_KEY_ID` e
`APPLE_PRIVATE_KEY`, para não bloquear quem não tem acesso à conta Apple
Developer. Quando informadas, o formato é validado em qualquer ambiente. Em
`production` a ausência ou o formato inválido derruba o boot imediatamente
(fail-fast), antes de a API aceitar tráfego.

A validação da chave privada não olha apenas os delimitadores `-----BEGIN/END-----`:
o backend pede ao Node para interpretar a chave, então um `.p8` truncado ou com
base64 corrompido é recusado no boot, e não na primeira tentativa de assinatura.

`APPLE_ISSUER`, `APPLE_JWKS_URL` e `APPLE_TOKEN_URL` podem apontar para um stub em
`development` e `test`. Em `production` precisam ser exatamente os endpoints
canônicos da Apple listados acima — conferir a prova de identidade contra outra
origem invalidaria a autenticação.

## 2. Obter o Team ID

1. Acesse o [Apple Developer Portal](https://developer.apple.com/account) com a
   conta da organização.
2. Abra **Membership details**.
3. Copie o **Team ID** (10 caracteres alfanuméricos) para `APPLE_TEAM_ID`.

## 3. Habilitar a capability no App ID

1. Em **Certificates, Identifiers & Profiles > Identifiers**, selecione o App ID
   do aplicativo (ou crie um do tipo _App IDs > App_).
2. Confirme que o **Bundle ID** é exatamente o valor usado em
   `APPLE_CLIENT_ID`. Ele é a audiência (`aud`) esperada no `identityToken`; uma
   divergência faz toda autenticação ser recusada.
3. Marque a capability **Sign in with Apple** e salve.

## 4. Criar a chave e baixar o arquivo `.p8`

1. Em **Certificates, Identifiers & Profiles > Keys**, crie uma nova chave.
2. Dê um nome que identifique o uso (por exemplo, `FamilyRoutine Sign in with Apple`).
3. Marque **Sign in with Apple**, associe ao App ID do passo anterior e
   confirme.
4. Copie o **Key ID** exibido para `APPLE_KEY_ID`.
5. Baixe o arquivo `AuthKey_<KEY_ID>.p8`.

> O download é **único**. A Apple não disponibiliza o arquivo novamente. Guarde-o
> em um gerenciador de segredos antes de sair da página. Se o arquivo for
> perdido, a única saída é revogar a chave e criar outra (seção 7).

## 5. Formatar a chave para o ambiente

O arquivo `.p8` é um PEM com quebras de linha reais:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
-----END PRIVATE KEY-----
```

Arquivos `.env` não guardam quebras de linha. Converta para uma linha única com
`\n` literal, entre aspas:

```bash
# Imprime o valor pronto para colar no .env
awk 'BEGIN { ORS="\\n" } { print }' AuthKey_ABC1234567.p8
```

Resultado no `.env`:

```dotenv
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49...\n-----END PRIVATE KEY-----"
```

O backend normaliza `\n` literal para quebras reais e remove aspas externas
antes de usar a chave, de modo que plataformas que injetam o PEM com quebras
reais também funcionam sem ajuste.

## 6. Verificar a configuração

```bash
cd backend
npm run dev
```

O boot falha com mensagem indicando a variável e o problema quando algo está
inválido. As mensagens de erro nunca incluem o valor da chave, nem o detalhe da
exceção criptográfica.

Para conferir o comportamento estrito de produção sem publicar nada, rode a
suíte unitária, que cobre os cenários de `development`, `test` e `production`:

```bash
npm run test
```

## 7. Rotação e revogação de credenciais

A chave privada da Apple não expira, mas deve ser rotacionada quando houver
suspeita de exposição, saída de pessoa com acesso ou política interna de prazo.

1. Crie uma **nova** chave seguindo a seção 4, sem revogar a atual.
2. Atualize `APPLE_KEY_ID` e `APPLE_PRIVATE_KEY` no gerenciador de segredos de
   cada ambiente e reinicie os processos.
3. Confirme que a autenticação funciona com a nova chave.
4. Só então revogue a chave antiga em **Keys > (chave) > Revoke**.

Revogar antes de confirmar a nova chave interrompe o login de todos os usuários.

## 8. Regras de segurança

- Nunca versione o arquivo `.p8`, o PEM ou qualquer credencial real. `.env.example`
  usa apenas placeholders.
- Credenciais vêm do ambiente ou de um gerenciador de segredos, nunca do código.
- `identityToken`, `authorizationCode`, `rawNonce`, o client secret assinado e a
  chave privada são sanitizados como `[REDACTED]` pelo logger estruturado e não
  aparecem em logs, telemetria ou mensagens de erro (RNF08, RNF16).
- Em caso de exposição confirmada, trate como incidente: rotacione a chave
  (seção 7) e revogue a anterior imediatamente após a troca.

## Referências

- [Sign in with Apple REST API](https://developer.apple.com/documentation/signinwithapplerestapi)
- [Generate and validate tokens](https://developer.apple.com/documentation/signinwithapplerestapi/generate_and_validate_tokens)
- [Fetch Apple's public key](https://developer.apple.com/documentation/signinwithapplerestapi/fetch_apple_s_public_key_for_verifying_token_signature)
