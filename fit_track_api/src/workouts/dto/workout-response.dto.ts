import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import type { WorkoutSession } from '@prisma/client';

export class WorkoutResponseDto {
  @ApiProperty({
    description: 'Identificador único UUID de la sesión de entrenamiento',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  id!: string;

  @ApiProperty({
    description: 'Identificador UUID del usuario propietario de la sesión',
    example: 'e2b3c4d5-6789-4abc-def0-123456789abc',
  })
  userId!: string;

  @ApiProperty({
    description: 'Fecha y hora de inicio de la sesión en formato ISO 8601',
    example: '2026-11-04T10:00:00.000Z',
  })
  startedAt!: Date;

  @ApiPropertyOptional({
    description:
      'Fecha y hora de término de la sesión (null si sigue en curso)',
    example: '2026-11-04T11:15:00.000Z',
    nullable: true,
  })
  endedAt!: Date | null;

  @ApiPropertyOptional({
    description: 'Notas u observaciones personales sobre la sesión',
    example: 'Buen progreso en sentadillas, descanso de 90s entre series.',
    nullable: true,
  })
  notes!: string | null;

  @ApiProperty({
    description: 'Fecha de creación del registro en el sistema',
    example: '2026-11-04T10:00:00.000Z',
  })
  createdAt!: Date;

  @ApiProperty({
    description: 'Fecha de última actualización del registro',
    example: '2026-11-04T11:15:00.000Z',
  })
  updatedAt!: Date;

  static fromEntity(session: WorkoutSession): WorkoutResponseDto {
    const dto = new WorkoutResponseDto();
    dto.id = session.id;
    dto.userId = session.userId;
    dto.startedAt = session.startedAt;
    dto.endedAt = session.endedAt;
    dto.notes = session.notes;
    dto.createdAt = session.createdAt;
    dto.updatedAt = session.updatedAt;
    return dto;
  }
}
