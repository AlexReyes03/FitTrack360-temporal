import { ApiPropertyOptional } from '@nestjs/swagger';
import { DistanceUnit, WeightUnit } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import {
  DISTANCE_UNITS,
  REST_SECONDS_MAX,
  REST_SECONDS_MIN,
  WEIGHT_UNITS,
} from '../domain/profile-rules';

/** Metas diarias editables; todas opcionales para permitir PATCH parcial. */
export class UpdateGoalsDto {
  @ApiPropertyOptional({ minimum: 1, example: 2000 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20000)
  dailyCalorieGoal?: number;

  @ApiPropertyOptional({ minimum: 0, example: 150 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2000)
  proteinGoalG?: number;

  @ApiPropertyOptional({ minimum: 0, example: 250 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2000)
  carbsGoalG?: number;

  @ApiPropertyOptional({ minimum: 0, example: 65 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2000)
  fatGoalG?: number;
}

/** Preferencias de la app; todas opcionales para permitir PATCH parcial. */
export class UpdatePreferencesDto {
  @ApiPropertyOptional({ enum: WEIGHT_UNITS })
  @IsOptional()
  @IsEnum(WeightUnit)
  weightUnit?: WeightUnit;

  @ApiPropertyOptional({ enum: DISTANCE_UNITS })
  @IsOptional()
  @IsEnum(DistanceUnit)
  distanceUnit?: DistanceUnit;

  @ApiPropertyOptional({
    minimum: REST_SECONDS_MIN,
    maximum: REST_SECONDS_MAX,
    example: 90,
  })
  @IsOptional()
  @IsInt()
  @Min(REST_SECONDS_MIN)
  @Max(REST_SECONDS_MAX)
  restSeconds?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  notificationsEnabled?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  biometricEnabled?: boolean;
}

/**
 * Cuerpo de PATCH /users/me. No acepta id, email, username ni contraseña:
 * el ValidationPipe global (forbidNonWhitelisted) responde 400 ante ellos.
 */
export class UpdateProfileDto {
  @ApiPropertyOptional({ maxLength: 80, example: 'Ana Pérez' })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  displayName?: string;

  @ApiPropertyOptional({ type: UpdateGoalsDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => UpdateGoalsDto)
  goals?: UpdateGoalsDto;

  @ApiPropertyOptional({ type: UpdatePreferencesDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => UpdatePreferencesDto)
  preferences?: UpdatePreferencesDto;
}
