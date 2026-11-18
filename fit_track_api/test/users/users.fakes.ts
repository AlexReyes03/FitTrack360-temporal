/**
 * Almacén en memoria que sustituye a Prisma para las pruebas de perfil.
 * Solo implementa las operaciones que usa UsersService y FirebaseAuthGuard.
 *
 * `$transaction` modela la atomicidad de Prisma: toma una instantánea de
 * usuarios y ajustes y, si el callback falla, la restaura. `faults` permite
 * simular el fallo de una operación concreta (p. ej. el upsert de ajustes).
 */
export interface StoredUser {
  id: string;
  firebaseUid: string;
  email: string;
  username: string;
  displayName: string;
  passwordHash: string | null;
}

export type StoredSettings = Record<string, unknown> & { userId: string };

/** Sesión de entrenamiento mínima: solo importa a quién pertenece. */
export interface StoredWorkoutSession {
  id: string;
  userId: string;
}

export interface StoreFaults {
  /** Si se define, `userSettings.upsert` rechaza con este error. */
  settingsUpsert?: Error;
}

export function createUsersStore(
  users: StoredUser[],
  workoutSessions: StoredWorkoutSession[] = [],
) {
  const settings: StoredSettings[] = [];
  const faults: StoreFaults = {};
  const transactions = { started: 0, rolledBack: 0 };

  const pick = (user: StoredUser) => ({
    id: user.id,
    firebaseUid: user.firebaseUid,
    email: user.email,
    username: user.username,
    displayName: user.displayName,
  });

  const store = {
    users,
    settings,
    workoutSessions,
    /** Llamadas a workoutSession.count, para comprobar que no se lista. */
    countCalls: [] as unknown[],
    faults,
    transactions,
    /** Solo la forma interactiva, que es la que usa UsersService. */
    $transaction: async <T>(fn: (tx: unknown) => Promise<T>): Promise<T> => {
      transactions.started += 1;
      const usersSnapshot = structuredClone(users);
      const settingsSnapshot = structuredClone(settings);
      try {
        return await fn(store);
      } catch (error) {
        transactions.rolledBack += 1;
        users.splice(0, users.length, ...usersSnapshot);
        settings.splice(0, settings.length, ...settingsSnapshot);
        throw error;
      }
    },
    user: {
      findUnique: ({
        where,
      }: {
        where: {
          id?: string;
          firebaseUid?: string;
          email?: string;
          username?: string;
        };
      }) => {
        const user = users.find(
          (u) =>
            (where.id !== undefined && u.id === where.id) ||
            (where.firebaseUid !== undefined &&
              u.firebaseUid === where.firebaseUid) ||
            (where.email !== undefined && u.email === where.email) ||
            (where.username !== undefined && u.username === where.username),
        );
        return Promise.resolve(user ? pick(user) : null);
      },
      update: ({
        where,
        data,
      }: {
        where: { id: string };
        data: { displayName?: string };
      }) => {
        const user = users.find((u) => u.id === where.id);
        if (!user) {
          return Promise.reject(new Error('Registro no encontrado'));
        }
        Object.assign(user, data);
        return Promise.resolve(pick(user));
      },
    },
    workoutSession: {
      // Igual que Prisma: sin `where` cuenta todas las filas de la tabla.
      count(args?: { where?: { userId?: string } }) {
        store.countCalls.push(args);
        const userId = args?.where?.userId;
        return Promise.resolve(
          workoutSessions.filter(
            (s) => userId === undefined || s.userId === userId,
          ).length,
        );
      },
    },
    userSettings: {
      findUnique: ({ where }: { where: { userId: string } }) =>
        Promise.resolve(
          settings.find((s) => s.userId === where.userId) ?? null,
        ),
      upsert: ({
        where,
        create,
        update,
      }: {
        where: { userId: string };
        create: StoredSettings;
        update: Record<string, unknown>;
      }) => {
        if (faults.settingsUpsert) {
          return Promise.reject(faults.settingsUpsert);
        }
        const existing = settings.find((s) => s.userId === where.userId);
        if (existing) {
          Object.assign(existing, update);
          return Promise.resolve(existing);
        }
        const row = { ...create };
        settings.push(row);
        return Promise.resolve(row);
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
      passwordHash: null,
    },
    {
      id: 'user-beto',
      firebaseUid: 'firebase-beto',
      email: 'beto@test.com',
      username: 'beto',
      displayName: 'Beto',
      passwordHash: null,
    },
  ];
}

/** Token mock aceptado por MockFirebaseTokenVerifier. */
export function mockIdToken(firebaseUid: string, email: string): string {
  return `mock:${firebaseUid}:${email}`;
}
