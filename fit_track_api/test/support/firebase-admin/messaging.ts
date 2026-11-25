/** Sustituto de `firebase-admin/messaging` solo para Jest; ver ./app.ts. */

export type MulticastMessage = {
  tokens: string[];
  notification?: unknown;
  data?: Record<string, string>;
};

export type BatchResponse = {
  responses: Array<{ success: boolean; error?: { code: string } }>;
  successCount: number;
  failureCount: number;
};

type SendEachForMulticast = (
  message: MulticastMessage,
) => Promise<BatchResponse>;

const defaultSendEachForMulticast: SendEachForMulticast = () => {
  throw new Error('firebase-admin no está disponible en pruebas');
};

let sendEachForMulticastImpl: SendEachForMulticast =
  defaultSendEachForMulticast;

/** Configura el comportamiento de sendEachForMulticast en pruebas del adaptador FCM. */
export function __setSendEachForMulticast(impl: SendEachForMulticast): void {
  sendEachForMulticastImpl = impl;
}

export function __resetFirebaseAdminMessaging(): void {
  sendEachForMulticastImpl = defaultSendEachForMulticast;
}

export const getMessaging = (_app?: unknown) => ({
  sendEachForMulticast: (message: MulticastMessage) =>
    sendEachForMulticastImpl(message),
});
