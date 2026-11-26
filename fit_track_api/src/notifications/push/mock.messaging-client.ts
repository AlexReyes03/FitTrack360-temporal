import type {
  PushMessage,
  PushMessagingClient,
  PushSendResult,
} from './push-messaging.client';

/** Cliente en memoria para CI y e2e: sin red ni firebase-admin. */
export class MockPushMessagingClient implements PushMessagingClient {
  readonly sent: PushMessage[] = [];
  private readonly failures = new Map<string, string>();
  private nextSendError: Error | null = null;

  send(message: PushMessage): Promise<PushSendResult[]> {
    if (this.nextSendError) {
      const error = this.nextSendError;
      this.nextSendError = null;
      return Promise.reject(error);
    }

    this.sent.push({
      ...message,
      tokens: [...message.tokens],
      data: { ...message.data },
    });

    return Promise.resolve(
      message.tokens.map((token): PushSendResult => {
        const errorCode = this.failures.get(token);
        return errorCode === undefined
          ? { token, ok: true }
          : { token, ok: false, errorCode };
      }),
    );
  }

  /** Simula un error de FCM para un token concreto. */
  failWith(token: string, errorCode: string): void {
    this.failures.set(token, errorCode);
  }

  /** Simula una caida de red o un 5xx en la siguiente llamada a `send`. */
  failNextSend(error: Error): void {
    this.nextSendError = error;
  }

  reset(): void {
    this.sent.length = 0;
    this.failures.clear();
    this.nextSendError = null;
  }
}

/** Modo `disabled`: no envia nada y no falla. */
export class DisabledPushMessagingClient implements PushMessagingClient {
  send(): Promise<PushSendResult[]> {
    return Promise.resolve([]);
  }
}
