import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class RoutineExerciseDto {
  @ApiProperty() @IsString() @IsNotEmpty() exerciseId!: string;
  @ApiProperty({ minimum: 1 }) @IsInt() @Min(1) position!: number;
  @ApiProperty({ minimum: 1, maximum: 100 })
  @IsInt()
  @Min(1)
  @Max(100)
  targetSets!: number;
  @ApiProperty({ minimum: 1 }) @IsInt() @Min(1) targetReps!: number;
}
export class CreateRoutineDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @Matches(/\S/)
  @MaxLength(120)
  name!: string;
  @ApiProperty({ type: [RoutineExerciseDto] })
  @IsArray()
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => RoutineExerciseDto)
  exercises!: RoutineExerciseDto[];
}
export class UpdateRoutineDto extends PartialType(CreateRoutineDto) {}
export class StartRoutineDto {
  @ApiPropertyOptional({
    description: 'Inicio ISO 8601; si se omite se usa la fecha actual.',
  })
  @IsOptional()
  @IsDateString()
  startedAt?: string;
}
