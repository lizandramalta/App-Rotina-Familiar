import { generateKeyPairSync } from 'node:crypto';
import { EventEmitter } from 'node:events';
import http2 from 'node:http2';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApnsPushGateway } from '../../src/integrations/apple/apns-push-gateway.js';

function transport(status: number) {
  const stream = Object.assign(new EventEmitter(), {
    setTimeout: vi.fn(),
    close: vi.fn(),
    end: vi.fn((_body: string) => {
      stream.emit('response', { ':status': status });
      stream.emit('data', Buffer.from('{"reason":"Unregistered"}'));
      stream.emit('end');
    }),
  });
  const client = Object.assign(new EventEmitter(), {
    close: vi.fn(),
    request: vi.fn(() => stream),
  });
  const connect = vi
    .spyOn(http2, 'connect')
    .mockReturnValue(client as unknown as ReturnType<typeof http2.connect>);
  const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const gateway = new ApnsPushGateway({
    keyId: 'TESTKEY123',
    teamId: 'TESTTEAM12',
    topic: 'test.family',
    privateKey: privateKey.export({ format: 'pem', type: 'pkcs8' }).toString(),
  });
  return { gateway, connect, client, stream };
}

describe('SPEC-020 CA-06 — APNs payload and provider response', () => {
  afterEach(() => vi.restoreAllMocks());
  it('sends only the recognition type/ID, localization key and stable notification ID', async () => {
    const { gateway, connect, client, stream } = transport(200);
    const id = '11111111-2222-4333-8444-555555555555';
    expect(await gateway.sendRecognition('device-token', 'development', id)).toBe(200);
    expect(connect).toHaveBeenCalledWith('https://api.sandbox.push.apple.com');
    expect(client.request).toHaveBeenCalledWith(
      expect.objectContaining({
        'apns-id': id,
        'apns-collapse-id': id,
        'apns-topic': 'test.family',
      }),
    );
    expect(JSON.parse(stream.end.mock.calls[0]![0])).toEqual({
      aps: { alert: { 'loc-key': 'recognition.notification' }, sound: 'default' },
      type: 'weeklyRecognition',
      recognitionId: id,
    });
    expect(client.close).toHaveBeenCalledOnce();
  });
  it('consumes error responses and reports APNs rejection without calling it delivery', async () => {
    const { gateway, connect, client } = transport(410);
    expect(
      await gateway.sendRecognition(
        'device-token',
        'production',
        '11111111-2222-4333-8444-555555555555',
      ),
    ).toBe(410);
    expect(connect).toHaveBeenCalledWith('https://api.push.apple.com');
    expect(client.close).toHaveBeenCalledOnce();
  });
  it('preserves the existing family applause payload', async () => {
    const { gateway, stream } = transport(200);
    await gateway.send(
      'device-token',
      'development',
      '11111111-2222-4333-8444-555555555555',
      'Alex',
    );
    expect(JSON.parse(stream.end.mock.calls[0]![0])).toEqual({
      aps: {
        alert: { title: 'Parabéns!', body: 'Alex bateu palmas para você!' },
        sound: 'default',
      },
      applauseId: '11111111-2222-4333-8444-555555555555',
    });
  });
});
