export const PUSH_MESSAGING_CLIENT = Symbol('PUSH_MESSAGING_CLIENT');

export interface PushMessage {
  /** Tokens FCM destino (1..n). */
  tokens: string[];
  title: string;
  body: string;
  /** FCM exige que todos los valores sean string. */
  data: Record<string, string>;
}

export interface PushSendResult {
  token: string;
  ok: boolean;
  /** Por ejemplo `messaging/registration-token-not-registered`. */
  errorCode?: string;
}

export interface PushMessagingClient {
  /**
   * Devuelve un resultado por token, en el mismo orden.
   * Lanza `PushMessagingUnavailableError` si no hay configuracion.
   */
  send(message: PushMessage): Promise<PushSendResult[]>;
}

/** Codigos de FCM que indican que el token ya no sirve y debe borrarse. */
export const INVALID_TOKEN_ERROR_CODES: ReadonlySet<string> = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

export class PushMessagingUnavailableError extends Error {}
