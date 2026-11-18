import { NotFoundException } from '@nestjs/common';
import { ProgressService } from '../../src/progress/progress.service';
import { PrismaService } from '../../src/prisma/prisma.service';

describe('ProgressService (W12-08)', () => {
  const metrics: Array<{
    id: string;
    userId: string;
    measuredAt: Date;
    weightKg: number | null;
    bodyFatPercent: number | null;
    waistCm: number | null;
  }> = [];

  const prisma = {
    bodyMetric: {
      create: ({ data }: { data: (typeof metrics)[number] }) => {
        const row = { ...data, id: `metric-${metrics.length + 1}` };
        metrics.push(row);
        return Promise.resolve(row);
      },
      findMany: ({ where }: { where: { userId: string } }) =>
        Promise.resolve(metrics.filter((m) => m.userId === where.userId)),
      findFirst: ({ where }: { where: { id: string; userId: string } }) =>
        Promise.resolve(
          metrics.find((m) => m.id === where.id && m.userId === where.userId) ??
            null,
        ),
      update: ({
        where,
        data,
      }: {
        where: { id: string };
        data: Partial<(typeof metrics)[number]>;
      }) => {
        const row = metrics.find((m) => m.id === where.id);
        if (!row) throw new Error('missing');
        Object.assign(row, data);
        return Promise.resolve(row);
      },
      delete: ({ where }: { where: { id: string } }) => {
        const idx = metrics.findIndex((m) => m.id === where.id);
        const [removed] = metrics.splice(idx, 1);
        return Promise.resolve(removed);
      },
    },
  };

  const service = new ProgressService(prisma as unknown as PrismaService);

  beforeEach(() => {
    metrics.length = 0;
  });

  it('crea una métrica del usuario', async () => {
    const created = await service.create('user-a', {
      measuredAt: '2026-11-18T12:00:00.000Z',
      weightKg: 80,
    });
    expect(created.userId).toBe('user-a');
    expect(created.weightKg).toBe(80);
  });

  it('responde 404 ante métrica ajena (S4)', async () => {
    const created = await service.create('user-a', {
      measuredAt: '2026-11-18T12:00:00.000Z',
      weightKg: 80,
    });
    await expect(service.findOne('user-b', created.id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(
      service.update('user-b', created.id, { weightKg: 70 }),
    ).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.remove('user-b', created.id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
