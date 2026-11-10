import { DatabaseProbe } from '../../src/health/database.probe';
import {
  DEFAULT_DB_PROBE_TIMEOUT_MS,
  HealthService,
} from '../../src/health/health.service';

/** Sonda falsa en memoria: responde según la función que se le pase. */
class FakeDatabaseProbe extends DatabaseProbe {
  calls = 0;

  constructor(private readonly answer: () => Promise<boolean>) {
    super();
  }

  isUp(): Promise<boolean> {
    this.calls += 1;
    return this.answer();
  }
}

describe('HealthService (W8-09)', () => {
  it('reporta db "up" cuando la sonda responde true', async () => {
    const probe = new FakeDatabaseProbe(() => Promise.resolve(true));
    const service = new HealthService(probe);

    await expect(service.check()).resolves.toEqual({ status: 'ok', db: 'up' });
    expect(probe.calls).toBe(1);
  });

  it('reporta db "down" cuando la sonda responde false', async () => {
    const service = new HealthService(
      new FakeDatabaseProbe(() => Promise.resolve(false)),
    );

    await expect(service.check()).resolves.toEqual({
      status: 'ok',
      db: 'down',
    });
  });

  it('degrada a "down" sin lanzar cuando la sonda falla', async () => {
    const service = new HealthService(
      new FakeDatabaseProbe(() => Promise.reject(new Error('sin conexión'))),
    );

    await expect(service.check()).resolves.toEqual({
      status: 'ok',
      db: 'down',
    });
  });

  it('degrada a "down" cuando la sonda no responde antes del timeout', async () => {
    const hanging = new FakeDatabaseProbe(() => new Promise<boolean>(() => {}));
    const service = new HealthService(hanging, 50);

    const startedAt = Date.now();
    await expect(service.check()).resolves.toEqual({
      status: 'ok',
      db: 'down',
    });
    expect(Date.now() - startedAt).toBeLessThan(1000);
  });

  it('usa un timeout corto por defecto (1.5 s)', () => {
    expect(DEFAULT_DB_PROBE_TIMEOUT_MS).toBe(1500);
  });
});
