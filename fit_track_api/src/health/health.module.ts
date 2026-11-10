import { Module } from '@nestjs/common';
import { DatabaseProbe } from './database.probe';
import { HealthController } from './health.controller';
import { HealthService } from './health.service';
import { PrismaDatabaseProbe } from './prisma-database.probe';

/** Endpoint de salud; PrismaService llega del PrismaModule global. */
@Module({
  controllers: [HealthController],
  providers: [
    HealthService,
    { provide: DatabaseProbe, useClass: PrismaDatabaseProbe },
  ],
})
export class HealthModule {}
