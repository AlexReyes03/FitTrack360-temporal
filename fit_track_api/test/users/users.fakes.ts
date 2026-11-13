/**
 * Almacén en memoria que sustituye a Prisma para las pruebas de perfil.
 * Solo implementa las operaciones que usa UsersService.
 */
export interface StoredUser {
  id: string;
  email: string;
  username: string;
  displayName: string;
  passwordHash: string;
}

export type StoredSettings = Record<string, unknown> & { userId: string };

export function createUsersStore(users: StoredUser[]) {
  const settings: StoredSettings[] = [];

  const pick = (user: StoredUser) => ({
    id: user.id,
    email: user.email,
    username: user.username,
    displayName: user.displayName,
  });

  return {
    users,
    settings,
    user: {
      findUnique: ({ where }: { where: { id: string } }) => {
        const user = users.find((u) => u.id === where.id);
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
}

export function sampleUsers(): StoredUser[] {
  return [
    {
      id: 'user-ana',
      email: 'ana@test.com',
      username: 'ana',
      displayName: 'Ana',
      passwordHash: 'hash-secreto-ana',
    },
    {
      id: 'user-beto',
      email: 'beto@test.com',
      username: 'beto',
      displayName: 'Beto',
      passwordHash: 'hash-secreto-beto',
    },
  ];
}
