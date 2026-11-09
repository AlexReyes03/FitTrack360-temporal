import { ConfigModule } from '@nestjs/config';
import type { DynamicModule } from '@nestjs/common';
import { AppModule } from '../../src/app.module';
import { HealthModule } from '../../src/health/health.module';

describe('AppModule (W8-08)', () => {
  it('registra ConfigModule como módulo global', async () => {
    // ConfigModule.forRoot devuelve una Promise<DynamicModule> en @nestjs/config 12.
    const imports = await Promise.all(
      Reflect.getMetadata('imports', AppModule) as unknown[],
    );
    const configModule = imports.find(
      (entry): entry is DynamicModule =>
        typeof entry === 'object' &&
        entry !== null &&
        (entry as DynamicModule).module === ConfigModule,
    );

    expect(configModule).toBeDefined();
    expect(configModule?.global).toBe(true);
  });

  it('registra HealthModule (W8-09)', () => {
    const imports = Reflect.getMetadata('imports', AppModule) as unknown[];
    expect(imports).toContain(HealthModule);
  });
});
