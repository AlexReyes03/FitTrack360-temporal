/**
 * Puerto para comprobar si la base de datos responde. HealthService depende de
 * esta abstracción y no de Prisma, para poder probarlo con sondas falsas.
 */
export abstract class DatabaseProbe {
  abstract isUp(): Promise<boolean>;
}
