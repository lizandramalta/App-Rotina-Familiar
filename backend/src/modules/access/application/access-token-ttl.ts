/**
 * Validade do access token (BA-10). Vive fora dos casos de uso porque a emissão
 * no login e na renovação têm de usar o mesmo valor: duplicá-lo deixaria as duas
 * janelas divergirem na primeira alteração.
 */
export const ACCESS_TOKEN_TTL_MS = 15 * 60 * 1000;
