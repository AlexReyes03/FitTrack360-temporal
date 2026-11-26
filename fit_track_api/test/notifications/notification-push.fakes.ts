import {
  createDeviceTokensStore,
  sampleUsers,
  type StoredUser,
} from './device-tokens.fakes';

/**
 * Compone el almacén de DeviceToken y agrega `userSettings.findUnique`
 * para probar el gate `notificationsEnabled` del despacho push.
 * `settings` solo contiene filas existentes: sin fila equivale a `false`.
 */
export function createNotificationPushStore(
  users: StoredUser[] = sampleUsers(),
) {
  const base = createDeviceTokensStore(users);
  const settings = new Map<string, { notificationsEnabled: boolean }>();

  const store = Object.assign(base, {
    settings,
    userSettings: {
      findUnique: ({ where }: { where: { userId: string } }) => {
        const row = settings.get(where.userId);
        return Promise.resolve(row ? { ...row } : null);
      },
    },
  });

  return store;
}
