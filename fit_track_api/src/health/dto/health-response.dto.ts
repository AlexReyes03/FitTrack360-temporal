import { ApiProperty } from '@nestjs/swagger';
import type { DatabaseStatus, HealthReport } from '../health-report';

/** Respuesta pública de GET /api/v1/health. */
export class HealthResponseDto implements HealthReport {
  @ApiProperty({ enum: ['ok'], example: 'ok' })
  status: 'ok';

  @ApiProperty({ enum: ['up', 'down'], example: 'up' })
  db: DatabaseStatus;
}
