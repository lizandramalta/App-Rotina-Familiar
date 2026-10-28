import { createPrivateKey, sign } from 'node:crypto';
import http2 from 'node:http2';

interface Credentials {
  keyId: string;
  teamId: string;
  topic: string;
  privateKey: string;
}

function base64url(input: Buffer | string): string {
  return Buffer.from(input).toString('base64url');
}

export class ApnsPushGateway {
  private token?: { value: string; validUntil: number };

  constructor(private readonly credentials: Credentials) {}

  private bearer(): string {
    if (this.token && Date.now() < this.token.validUntil) return this.token.value;
    const issuedAt = Math.floor(Date.now() / 1000);
    const unsigned = `${base64url(JSON.stringify({ alg: 'ES256', kid: this.credentials.keyId }))}.${base64url(JSON.stringify({ iss: this.credentials.teamId, iat: issuedAt }))}`;
    const signature = sign('sha256', Buffer.from(unsigned), {
      key: createPrivateKey(this.credentials.privateKey.replace(/\\n/g, '\n')),
      dsaEncoding: 'ieee-p1363',
    });
    const value = `${unsigned}.${base64url(signature)}`;
    this.token = { value, validUntil: Date.now() + 45 * 60 * 1000 };
    return value;
  }

  async send(
    deviceToken: string,
    environment: string,
    applauseId: string,
    senderName: string,
  ): Promise<number> {
    const host =
      environment === 'production'
        ? 'https://api.push.apple.com'
        : 'https://api.sandbox.push.apple.com';
    const client = http2.connect(host);
    return new Promise<number>((resolve, reject) => {
      let settled = false;
      const finish = (error: Error | null, status?: number) => {
        if (settled) return;
        settled = true;
        client.close();
        if (error) reject(error);
        else resolve(status ?? 500);
      };
      client.on('error', (error) => finish(error));
      const stream = client.request({
        ':method': 'POST',
        ':path': `/3/device/${deviceToken}`,
        authorization: `bearer ${this.bearer()}`,
        'apns-topic': this.credentials.topic,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'apns-id': applauseId,
      });
      let status = 500;
      stream.on('response', (headers) => {
        status = Number(headers[':status'] ?? 500);
      });
      stream.on('error', (error) => finish(error));
      stream.on('end', () => finish(null, status));
      stream.setTimeout(10_000, () => {
        stream.close();
        finish(new Error('APNs timeout'));
      });
      stream.end(
        JSON.stringify({
          aps: {
            alert: { title: 'Parabéns!', body: `${senderName} bateu palmas para você!` },
            sound: 'default',
          },
          applauseId,
        }),
      );
    });
  }
}
