import { ApiProperty } from '@nestjs/swagger';
import { DISTANCE_UNITS, WEIGHT_UNITS } from '../domain/profile-rules';

/** Metas diarias de calorías (kcal) y macros (gramos). */
export class UserGoalsDto {
  @ApiProperty({ example: 2000 })
  dailyCalorieGoal!: number;

  @ApiProperty({ example: 150 })
  proteinGoalG!: number;

  @ApiProperty({ example: 250 })
  carbsGoalG!: number;

  @ApiProperty({ example: 65 })
  fatGoalG!: number;
}

/** Preferencias de unidades, descanso, notificaciones y biometría. */
export class UserPreferencesDto {
  @ApiProperty({ enum: WEIGHT_UNITS, example: 'kg' })
  weightUnit!: string;

  @ApiProperty({ enum: DISTANCE_UNITS, example: 'km' })
  distanceUnit!: string;

  @ApiProperty({
    example: 90,
    description: 'Descanso entre series, en segundos',
  })
  restSeconds!: number;

  @ApiProperty()
  notificationsEnabled!: boolean;

  @ApiProperty()
  biometricEnabled!: boolean;
}

/** Perfil del usuario autenticado. Nunca incluye passwordHash. */
export class UserResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  email!: string;

  @ApiProperty()
  username!: string;

  @ApiProperty()
  displayName!: string;

  @ApiProperty({ type: UserGoalsDto })
  goals!: UserGoalsDto;

  @ApiProperty({ type: UserPreferencesDto })
  preferences!: UserPreferencesDto;
}
