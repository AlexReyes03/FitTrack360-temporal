import { randomUUID } from 'node:crypto';
import type { BodyMetric } from '@prisma/client';

export interface FakeUser {
  id: string;
  firebaseUid: string;
  email: string;
}

type DateFilter = { gte?: Date; lte?: Date };

const matchesOwner = (rowUserId: string, userId: string | undefined): boolean =>
  userId === undefined || rowUserId === userId;

const matchesRange = (value: Date, range: DateFilter | undefined): boolean =>
  (!range?.gte || value >= range.gte) && (!range?.lte || value <= range.lte);

export function createProgressStore(seed: {
  users: FakeUser[];
  metrics?: BodyMetric[];
}) {
  const users = [...seed.users];
  const metrics: BodyMetric[] = [...(seed.metrics ?? [])];

  return {
    metrics,
    user: {
      findUnique: ({ where }: { where: { firebaseUid?: string } }) =>
        Promise.resolve(
          users.find((u) => u.firebaseUid === where.firebaseUid) ?? null,
        ),
    },
    bodyMetric: {
      create: ({
        data,
      }: {
        data: {
          userId: string;
          measuredAt: Date;
          weightKg: number | null;
          bodyFatPercent: number | null;
          waistCm: number | null;
        };
      }): Promise<BodyMetric> => {
        const record: BodyMetric = {
          id: randomUUID(),
          userId: data.userId,
          measuredAt: data.measuredAt,
          weightKg: data.weightKg,
          bodyFatPercent: data.bodyFatPercent,
          waistCm: data.waistCm,
        };
        metrics.push(record);
        return Promise.resolve({ ...record });
      },

      findMany: ({
        where,
        orderBy,
      }: {
        where?: { userId?: string; measuredAt?: DateFilter };
        orderBy?: { measuredAt: 'asc' | 'desc' };
      }): Promise<BodyMetric[]> => {
        const result = metrics
          .filter(
            (m) =>
              matchesOwner(m.userId, where?.userId) &&
              matchesRange(m.measuredAt, where?.measuredAt),
          )
          .sort((a, b) =>
            orderBy?.measuredAt === 'asc'
              ? a.measuredAt.getTime() - b.measuredAt.getTime()
              : b.measuredAt.getTime() - a.measuredAt.getTime(),
          )
          .map((m) => ({ ...m }));
        return Promise.resolve(result);
      },

      findFirst: ({
        where,
        orderBy,
      }: {
        where?: { id?: string; userId?: string; measuredAt?: DateFilter };
        orderBy?: { measuredAt: 'asc' | 'desc' };
      }): Promise<BodyMetric | null> => {
        const result = metrics
          .filter(
            (m) =>
              (!where?.id || m.id === where.id) &&
              matchesOwner(m.userId, where?.userId) &&
              matchesRange(m.measuredAt, where?.measuredAt),
          )
          .sort((a, b) =>
            orderBy?.measuredAt === 'asc'
              ? a.measuredAt.getTime() - b.measuredAt.getTime()
              : b.measuredAt.getTime() - a.measuredAt.getTime(),
          );
        return Promise.resolve(result[0] ? { ...result[0] } : null);
      },

      update: ({
        where,
        data,
      }: {
        where: { id: string };
        data: {
          measuredAt?: Date;
          weightKg?: number | null;
          bodyFatPercent?: number | null;
          waistCm?: number | null;
        };
      }): Promise<BodyMetric> => {
        const record = metrics.find((m) => m.id === where.id);
        if (!record) {
          throw new Error('Record not found');
        }
        if (data.measuredAt !== undefined) record.measuredAt = data.measuredAt;
        if (data.weightKg !== undefined) record.weightKg = data.weightKg;
        if (data.bodyFatPercent !== undefined) {
          record.bodyFatPercent = data.bodyFatPercent;
        }
        if (data.waistCm !== undefined) record.waistCm = data.waistCm;
        return Promise.resolve({ ...record });
      },

      delete: ({ where }: { where: { id: string } }): Promise<BodyMetric> => {
        const index = metrics.findIndex((m) => m.id === where.id);
        if (index === -1) {
          throw new Error('Record not found');
        }
        const [removed] = metrics.splice(index, 1);
        return Promise.resolve({ ...removed });
      },
    },
  };
}
