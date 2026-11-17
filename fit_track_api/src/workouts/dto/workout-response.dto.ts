import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  compareWithPrevious,
  durationSeconds,
  lastMarksForSession,
  sessionVolume,
  setVolume,
  type LastMark,
  type SessionComparison,
  type WorkoutSessionSnapshot,
  type WorkoutSetSnapshot,
} from '../domain/workout-metrics';

export class WorkoutSetResponseDto {
  @ApiProperty({ example: '7c9e6679-7425-40de-944b-e07fc1f90ae7' })
  id!: string;

  @ApiProperty({ example: '3fa85f64-5717-4562-b3fc-2c963f66afa6' })
  sessionId!: string;

  @ApiProperty({ example: '0001' })
  exerciseId!: string;

  @ApiPropertyOptional({
    description: 'Nombre del ejercicio en el catálogo',
    example: 'Sentadilla',
    nullable: true,
  })
  exerciseName!: string | null;

  @ApiProperty({ example: 1 })
  order!: number;

  @ApiProperty({ description: 'Peso en kilogramos', example: 80 })
  weight!: number;

  @ApiProperty({
    description: 'Mismo peso, con el nombre que ya consume el cliente',
    example: 80,
  })
  weightKg!: number;

  @ApiProperty({ example: 10 })
  reps!: number;

  @ApiProperty({
    description: 'Volumen de la serie: peso × repeticiones',
    example: 800,
  })
  volume!: number;

  @ApiPropertyOptional({ example: 8, nullable: true })
  rpe!: number | null;

  @ApiPropertyOptional({ example: 2, nullable: true })
  rir!: number | null;

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;

  static fromSnapshot(set: WorkoutSetSnapshot): WorkoutSetResponseDto {
    const dto = new WorkoutSetResponseDto();
    dto.id = set.id;
    dto.sessionId = set.sessionId;
    dto.exerciseId = set.exerciseId;
    dto.exerciseName = set.exerciseName;
    dto.order = set.order;
    dto.weight = set.weight;
    dto.weightKg = set.weight;
    dto.reps = set.reps;
    dto.volume = setVolume(set.weight, set.reps);
    dto.rpe = set.rpe;
    dto.rir = set.rir;
    dto.createdAt = set.createdAt;
    dto.updatedAt = set.updatedAt;
    return dto;
  }
}

export class LastMarkResponseDto {
  @ApiProperty({ example: '0001' })
  exerciseId!: string;

  @ApiPropertyOptional({ nullable: true, example: 'Sentadilla' })
  exerciseName!: string | null;

  @ApiProperty()
  sessionId!: string;

  @ApiProperty()
  startedAt!: Date;

  @ApiProperty({ example: 3 })
  order!: number;

  @ApiProperty({ example: 60 })
  weight!: number;

  @ApiProperty({ example: 60 })
  weightKg!: number;

  @ApiProperty({ example: 10 })
  reps!: number;

  @ApiProperty({ example: 600 })
  volume!: number;

  static fromMark(mark: LastMark): LastMarkResponseDto {
    const dto = new LastMarkResponseDto();
    dto.exerciseId = mark.exerciseId;
    dto.exerciseName = mark.exerciseName;
    dto.sessionId = mark.sessionId;
    dto.startedAt = mark.startedAt;
    dto.order = mark.order;
    dto.weight = mark.weight;
    dto.weightKg = mark.weight;
    dto.reps = mark.reps;
    dto.volume = mark.volume;
    return dto;
  }
}

export class WorkoutComparisonResponseDto {
  @ApiProperty()
  previousSessionId!: string;

  @ApiProperty()
  previousStartedAt!: Date;

  @ApiProperty({ description: 'Volumen de esta sesión' })
  volume!: number;

  @ApiProperty()
  previousVolume!: number;

  @ApiProperty({
    description: 'Volumen actual menos volumen de la sesión anterior',
  })
  volumeDelta!: number;

  @ApiPropertyOptional({ nullable: true })
  durationSeconds!: number | null;

  @ApiPropertyOptional({ nullable: true })
  previousDurationSeconds!: number | null;

  @ApiPropertyOptional({
    nullable: true,
    description: 'Null si alguna de las dos sesiones no tiene fin',
  })
  durationDeltaSeconds!: number | null;

  @ApiProperty()
  setCount!: number;

  @ApiProperty()
  previousSetCount!: number;

  @ApiProperty()
  setCountDelta!: number;

  static fromComparison(
    comparison: SessionComparison,
  ): WorkoutComparisonResponseDto {
    const dto = new WorkoutComparisonResponseDto();
    dto.previousSessionId = comparison.previousSessionId;
    dto.previousStartedAt = comparison.previousStartedAt;
    dto.volume = comparison.volume;
    dto.previousVolume = comparison.previousVolume;
    dto.volumeDelta = comparison.volumeDelta;
    dto.durationSeconds = comparison.durationSeconds;
    dto.previousDurationSeconds = comparison.previousDurationSeconds;
    dto.durationDeltaSeconds = comparison.durationDeltaSeconds;
    dto.setCount = comparison.setCount;
    dto.previousSetCount = comparison.previousSetCount;
    dto.setCountDelta = comparison.setCountDelta;
    return dto;
  }
}

export class WorkoutResponseDto {
  @ApiPropertyOptional({ nullable: true })
  routineId!: string | null;
  @ApiProperty({ example: '3fa85f64-5717-4562-b3fc-2c963f66afa6' })
  id!: string;

  @ApiProperty()
  userId!: string;

  @ApiProperty()
  startedAt!: Date;

  @ApiPropertyOptional({ nullable: true })
  endedAt!: Date | null;

  @ApiPropertyOptional({
    nullable: true,
    description: 'Zona o ubicación escrita. Null si no se capturó.',
  })
  location!: string | null;

  @ApiPropertyOptional({ nullable: true })
  notes!: string | null;

  @ApiProperty({ type: [WorkoutSetResponseDto] })
  sets!: WorkoutSetResponseDto[];

  @ApiProperty({
    description: 'Suma de peso × repeticiones de todas las series',
    example: 2400,
  })
  volume!: number;

  @ApiPropertyOptional({
    nullable: true,
    description:
      'Segundos entre startedAt y endedAt. Null si la sesión sigue abierta.',
  })
  durationSeconds!: number | null;

  @ApiProperty({
    type: [LastMarkResponseDto],
    description:
      'Última serie previa de cada ejercicio de esta sesión, solo del mismo usuario',
  })
  lastMarks!: LastMarkResponseDto[];

  @ApiPropertyOptional({
    type: WorkoutComparisonResponseDto,
    nullable: true,
    description:
      'Comparación con la sesión anterior del mismo usuario. Null si no hay una.',
  })
  comparison!: WorkoutComparisonResponseDto | null;

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;

  static fromSnapshot(
    session: WorkoutSessionSnapshot,
    history: WorkoutSessionSnapshot[],
  ): WorkoutResponseDto {
    const dto = new WorkoutResponseDto();
    dto.id = session.id;
    dto.userId = session.userId;
    dto.routineId = session.routineId ?? null;
    dto.startedAt = session.startedAt;
    dto.endedAt = session.endedAt;
    dto.location = session.location;
    dto.notes = session.notes;
    dto.sets = [...session.sets]
      .sort((a, b) => a.order - b.order)
      .map((set) => WorkoutSetResponseDto.fromSnapshot(set));
    dto.volume = sessionVolume(session.sets);
    dto.durationSeconds = durationSeconds(session.startedAt, session.endedAt);
    dto.lastMarks = lastMarksForSession(history, session).map((mark) =>
      LastMarkResponseDto.fromMark(mark),
    );
    const comparison = compareWithPrevious(history, session);
    dto.comparison = comparison
      ? WorkoutComparisonResponseDto.fromComparison(comparison)
      : null;
    dto.createdAt = session.createdAt;
    dto.updatedAt = session.updatedAt;
    return dto;
  }
}
