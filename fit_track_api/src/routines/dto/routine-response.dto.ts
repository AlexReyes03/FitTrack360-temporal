import { ApiProperty } from '@nestjs/swagger';

export class RoutineExerciseResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  routineId!: string;

  @ApiProperty()
  exerciseId!: string;

  @ApiProperty()
  position!: number;

  @ApiProperty()
  targetSets!: number;

  @ApiProperty()
  targetReps!: number;
}

export class RoutineResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  userId!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;

  @ApiProperty({ type: [RoutineExerciseResponseDto] })
  exercises!: RoutineExerciseResponseDto[];
}
