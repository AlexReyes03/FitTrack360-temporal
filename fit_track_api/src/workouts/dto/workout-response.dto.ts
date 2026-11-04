import type { WorkoutSession } from '@prisma/client';

export class WorkoutResponseDto {
  id!: string;
  userId!: string;
  startedAt!: Date;
  endedAt!: Date | null;
  notes!: string | null;
  createdAt!: Date;
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
