import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DatabaseProbe } from './database.probe';

/** Sonda real: ejecuta SELECT 1 contra Postgres mediante Prisma. */
@Injectable()
export class PrismaDatabaseProbe extends DatabaseProbe {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async isUp(): Promise<boolean> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return true;
    } catch {
      return false;
    }
  }
}
