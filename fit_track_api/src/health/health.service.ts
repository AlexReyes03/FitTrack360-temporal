import { Inject, Injectable, Optional } from '@nestjs/common';
import { DatabaseProbe } from './database.probe';
import type { HealthReport } from './health-report';

/** Tiempo máximo que se espera a la base de datos antes de reportarla caída. */
export const DEFAULT_DB_PROBE_TIMEOUT_MS = 1500;

/** Token opcional para sobrescribir el timeout de la sonda. */
export const DB_PROBE_TIMEOUT_MS = Symbol('DB_PROBE_TIMEOUT_MS');

@Injectable()
export class HealthService {
  constructor(
    private readonly databaseProbe: DatabaseProbe,
    @Optional()
    @Inject(DB_PROBE_TIMEOUT_MS)
    private readonly timeoutMs: number = DEFAULT_DB_PROBE_TIMEOUT_MS,
  ) {}

  /**
   * Construye el reporte de salud. Nunca lanza: si la sonda falla o tarda más
   * que el timeout, degrada el campo db a 'down' y el proceso sigue sirviendo.
   */
  async check(): Promise<HealthReport> {
    const dbUp = await this.probeDatabase();
    return { status: 'ok', db: dbUp ? 'up' : 'down' };
  }

  private async probeDatabase(): Promise<boolean> {
    let timer: NodeJS.Timeout | undefined;
    const timeout = new Promise<boolean>((resolve) => {
      timer = setTimeout(() => resolve(false), this.timeoutMs);
      timer.unref();
    });
    try {
      return await Promise.race([this.databaseProbe.isUp(), timeout]);
    } catch {
      return false;
    } finally {
      clearTimeout(timer);
    }
  }
}
