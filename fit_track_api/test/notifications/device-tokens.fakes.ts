import { randomUUID } from 'node:crypto';
import type { DevicePlatform, DeviceToken } from '@prisma/client';

export interface StoredUser {
  id: string;
  firebaseUid: string;
  email: string;
  username: string;
  displayName: string;
}

/**
 * Almacén Prisma en memoria para pruebas de DeviceToken (sin llamadas a FCM).
 * Modela la unicidad de `token`, el aislamiento por `userId` y `$transaction`.
 */
export function createDeviceTokensStore(users: StoredUser[] = sampleUsers()) {
  const deviceTokens: DeviceToken[] = [];

  const store = {
    users,
    deviceTokens,
    $transaction: async <T>(fn: (tx: unknown) => Promise<T>): Promise<T> => {
      const snapshot = deviceTokens.map((row) => ({ ...row }));
      try {
        return await fn(store);
      } catch (error) {
        deviceTokens.splice(0, deviceTokens.length, ...snapshot);
        throw error;
      }
    },
    user: {
      findUnique: ({
        where,
      }: {
        where: { id?: string; firebaseUid?: string };
      }) => {
        const user = users.find(
          (u) =>
            (where.id !== undefined && u.id === where.id) ||
            (where.firebaseUid !== undefined &&
              u.firebaseUid === where.firebaseUid),
        );
        return Promise.resolve(user ? { ...user } : null);
      },
    },
    deviceToken: {
      findUnique: ({
        where,
        select,
      }: {
        where: { id?: string; token?: string };
        select?: Partial<Record<keyof DeviceToken, boolean>>;
      }) => {
        const match = deviceTokens.find(
          (row) =>
            (where.id !== undefined && row.id === where.id) ||
            (where.token !== undefined && row.token === where.token),
        );
        if (!match) {
          return Promise.resolve(null);
        }
        if (!select) {
          return Promise.resolve({ ...match });
        }
        const projected: Partial<DeviceToken> = {};
        for (const [key, enabled] of Object.entries(select)) {
          if (enabled) {
            const k = key as keyof DeviceToken;
            (projected as Record<string, unknown>)[k] = match[k];
          }
        }
        return Promise.resolve(projected);
      },
      findFirst: ({ where }: { where: { id?: string; userId?: string } }) => {
        const match = deviceTokens.find(
          (row) =>
            (where.id === undefined || row.id === where.id) &&
            (where.userId === undefined || row.userId === where.userId),
        );
        return Promise.resolve(match ? { ...match } : null);
      },
      findMany: ({
        where,
        orderBy,
      }: {
        where?: { userId?: string };
        orderBy?: { lastSeenAt?: 'asc' | 'desc' };
      } = {}) => {
        const filtered = deviceTokens
          .filter(
            (row) => where?.userId === undefined || row.userId === where.userId,
          )
          .map((row) => ({ ...row }));

        if (orderBy?.lastSeenAt === 'desc') {
          filtered.sort(
            (a, b) => b.lastSeenAt.getTime() - a.lastSeenAt.getTime(),
          );
        } else if (orderBy?.lastSeenAt === 'asc') {
          filtered.sort(
            (a, b) => a.lastSeenAt.getTime() - b.lastSeenAt.getTime(),
          );
        }
        return Promise.resolve(filtered);
      },
      upsert: ({
        where,
        create,
        update,
      }: {
        where: { token: string };
        create: {
          userId: string;
          token: string;
          platform: DevicePlatform;
          deviceLabel?: string | null;
          lastSeenAt?: Date;
        };
        update: {
          userId?: string;
          platform?: DevicePlatform;
          deviceLabel?: string | null;
          lastSeenAt?: Date;
        };
      }) => {
        const now = new Date();
        const existing = deviceTokens.find((row) => row.token === where.token);
        if (existing) {
          if (update.userId !== undefined) {
            existing.userId = update.userId;
          }
          if (update.platform !== undefined) {
            existing.platform = update.platform;
          }
          if (update.deviceLabel !== undefined) {
            existing.deviceLabel = update.deviceLabel;
          }
          if (update.lastSeenAt !== undefined) {
            existing.lastSeenAt = update.lastSeenAt;
          }
          existing.updatedAt = now;
          return Promise.resolve({ ...existing });
        }

        const created: DeviceToken = {
          id: randomUUID(),
          userId: create.userId,
          token: create.token,
          platform: create.platform,
          deviceLabel: create.deviceLabel ?? null,
          lastSeenAt: create.lastSeenAt ?? now,
          createdAt: now,
          updatedAt: now,
        };
        deviceTokens.push(created);
        return Promise.resolve({ ...created });
      },
      deleteMany: ({
        where,
      }: {
        where: { id?: string; token?: string; userId?: string };
      }) => {
        let count = 0;
        for (let i = deviceTokens.length - 1; i >= 0; i -= 1) {
          const row = deviceTokens[i];
          const matchesId = where.id === undefined || row.id === where.id;
          const matchesToken =
            where.token === undefined || row.token === where.token;
          const matchesUser =
            where.userId === undefined || row.userId === where.userId;
          if (matchesId && matchesToken && matchesUser) {
            deviceTokens.splice(i, 1);
            count += 1;
          }
        }
        return Promise.resolve({ count });
      },
    },
  };

  return store;
}

export function sampleUsers(): StoredUser[] {
  return [
    {
      id: 'user-ana',
      firebaseUid: 'firebase-ana',
      email: 'ana@test.com',
      username: 'ana',
      displayName: 'Ana',
    },
    {
      id: 'user-beto',
      firebaseUid: 'firebase-beto',
      email: 'beto@test.com',
      username: 'beto',
      displayName: 'Beto',
    },
  ];
}

export function mockIdToken(firebaseUid: string, email: string): string {
  return `mock:${firebaseUid}:${email}`;
}
