/** Estado de la base de datos visto desde la sonda de salud. */
export type DatabaseStatus = 'up' | 'down';

/** Reporte de salud del API. status es 'ok' mientras el proceso responda. */
export interface HealthReport {
  status: 'ok';
  db: DatabaseStatus;
}
