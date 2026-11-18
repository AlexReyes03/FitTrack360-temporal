/**
 * Almacén en memoria que sustituye a Prisma para las pruebas de perfil.
 * Solo implementa las operaciones que usa UsersService y FirebaseAuthGuard.
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

export function createUsersStore(
  users: StoredUser[],
  workoutSessions: StoredWorkoutSession[] = [],
) {
  const settings: StoredSettings[] = [];

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
