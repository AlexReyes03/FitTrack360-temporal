/**
 * Almacén en memoria que sustituye a Prisma para el resumen del día.
 * Implementa solo los filtros que usa DashboardService (userId y rangos).
 */

/** Alimento con macros congelados al registrarlo (M-02). */
export interface FakeMealItem {
  kcal: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
}

export interface FakeMeal {
  id: string;
  userId: string;
  eatenAt: Date;
  mealType: string;
  items?: FakeMealItem[];
}

export interface FakeMetric {
  id: string;
  userId: string;
  measuredAt: Date;
  weightKg: number | null;
  bodyFatPercent: number | null;
  waistCm: number | null;
}

export interface FakeSession {
  id: string;
  userId: string;
  startedAt: Date;
  endedAt: Date | null;
  notes: string | null;
}

export interface FakeSettings {
  userId: string;
  dailyCalorieGoal: number;
  proteinGoalG: number;
  carbsGoalG: number;
  fatGoalG: number;
}

/** Usuario sincronizado con Firebase: lo resuelve FirebaseAuthGuard. */
export interface FakeUser {
  id: string;
  firebaseUid: string;
  email: string;
}

type DateRange = { gte?: Date; lt?: Date };

// Como Prisma: un where sin userId no filtra por dueño. Así una consulta que
// olvide el userId sí trae datos ajenos y las pruebas de aislamiento fallan.
const ownedBy = (rowUserId: string, userId: string | undefined) =>
  userId === undefined || rowUserId === userId;

const inRange = (value: Date, range: DateRange | undefined) =>
  (!range?.gte || value >= range.gte) && (!range?.lt || value < range.lt);

export function createDashboardStore(seed: {
  meals?: FakeMeal[];
  sessions?: FakeSession[];
  settings?: FakeSettings[];
  users?: FakeUser[];
  metrics?: FakeMetric[];
}) {
  const meals = seed.meals ?? [];
  const sessions = seed.sessions ?? [];
  const settings = seed.settings ?? [];
  const users = seed.users ?? [];
  const metrics = seed.metrics ?? [];

  return {
    user: {
      findUnique: ({ where }: { where: { firebaseUid?: string } }) =>
        Promise.resolve(
          users.find((u) => u.firebaseUid === where.firebaseUid) ?? null,
        ),
    },
    mealLog: {
      findMany: ({
        where,
        include,
      }: {
        where: { userId?: string; eatenAt?: DateRange };
        include?: { items?: unknown };
      }) =>
        Promise.resolve(
          meals
            .filter(
              (m) =>
                ownedBy(m.userId, where.userId) &&
                inRange(m.eatenAt, where.eatenAt),
            )
            // Como Prisma: los items solo llegan si se piden con include.
            .map((m) => ({
              ...m,
              items: include?.items ? (m.items ?? []) : undefined,
            })),
        ),
    },
    bodyMetric: {
      findFirst: ({
        where,
        orderBy,
      }: {
        where: { userId?: string; measuredAt?: DateRange };
        orderBy?: { measuredAt: 'asc' | 'desc' };
      }) => {
        const found = metrics
          .filter(
            (m) =>
              ownedBy(m.userId, where.userId) &&
              inRange(m.measuredAt, where.measuredAt),
          )
          .sort((a, b) =>
            orderBy?.measuredAt === 'desc'
              ? b.measuredAt.getTime() - a.measuredAt.getTime()
              : a.measuredAt.getTime() - b.measuredAt.getTime(),
          );
        return Promise.resolve(found[0] ?? null);
      },
    },
    workoutSession: {
      findFirst: ({
        where,
        orderBy,
      }: {
        where: { userId?: string; startedAt?: DateRange };
        orderBy?: { startedAt: 'asc' | 'desc' };
      }) => {
        const found = sessions
          .filter(
            (s) =>
              ownedBy(s.userId, where.userId) &&
              inRange(s.startedAt, where.startedAt),
          )
          .sort((a, b) =>
            orderBy?.startedAt === 'desc'
              ? b.startedAt.getTime() - a.startedAt.getTime()
              : a.startedAt.getTime() - b.startedAt.getTime(),
          );
        return Promise.resolve(found[0] ?? null);
      },
    },
    userSettings: {
      findUnique: ({ where }: { where: { userId: string } }) =>
        Promise.resolve(
          settings.find((s) => s.userId === where.userId) ?? null,
        ),
    },
  };
}
