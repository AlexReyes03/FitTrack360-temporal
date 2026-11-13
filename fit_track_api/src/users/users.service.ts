import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  assertValidGoals,
  assertValidPreferences,
  DEFAULT_SETTINGS,
} from './domain/profile-rules';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UserResponseDto } from './dto/user-response.dto';

/** Vista de los ajustes vigentes: fila guardada o valores por defecto. */
interface Settings {
  dailyCalorieGoal: number;
  proteinGoalG: number;
  carbsGoalG: number;
  fatGoalG: number;
  weightUnit: string;
  distanceUnit: string;
  restSeconds: number;
  notificationsEnabled: boolean;
  biometricEnabled: boolean;
}

const PROFILE_SELECT = {
  id: true,
  email: true,
  username: true,
  displayName: true,
} as const;

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  /** Perfil del usuario del JWT con sus metas y preferencias vigentes. */
  async findMe(userId: string): Promise<UserResponseDto> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: PROFILE_SELECT,
    });
    if (!user) {
      throw new UnauthorizedException('Token invalido');
    }
    const settings = await this.prisma.userSettings.findUnique({
      where: { userId },
    });
    return toResponse(user, settings ?? DEFAULT_SETTINGS);
  }

  /**
   * Actualiza el perfil del usuario del JWT. Solo toca filas cuyo id o userId
   * es el del token: no existe forma de editar el perfil de otra persona.
   */
  async updateMe(
    userId: string,
    dto: UpdateProfileDto,
  ): Promise<UserResponseDto> {
    assertValidGoals(dto.goals);
    assertValidPreferences(dto.preferences);

    const current = await this.prisma.user.findUnique({
      where: { id: userId },
      select: PROFILE_SELECT,
    });
    if (!current) {
      throw new UnauthorizedException('Token invalido');
    }

    const user =
      dto.displayName === undefined
        ? current
        : await this.prisma.user.update({
            where: { id: userId },
            data: { displayName: dto.displayName },
            select: PROFILE_SELECT,
          });

    const changes = { ...dto.goals, ...dto.preferences };
    const settings =
      Object.keys(changes).length === 0
        ? await this.prisma.userSettings.findUnique({ where: { userId } })
        : await this.prisma.userSettings.upsert({
            where: { userId },
            create: { ...DEFAULT_SETTINGS, ...changes, userId },
            update: changes,
          });

    return toResponse(user, settings ?? DEFAULT_SETTINGS);
  }
}

function toResponse(
  user: { id: string; email: string; username: string; displayName: string },
  settings: Settings,
): UserResponseDto {
  return {
    id: user.id,
    email: user.email,
    username: user.username,
    displayName: user.displayName,
    goals: {
      dailyCalorieGoal: settings.dailyCalorieGoal,
      proteinGoalG: settings.proteinGoalG,
      carbsGoalG: settings.carbsGoalG,
      fatGoalG: settings.fatGoalG,
    },
    preferences: {
      weightUnit: settings.weightUnit,
      distanceUnit: settings.distanceUnit,
      restSeconds: settings.restSeconds,
      notificationsEnabled: settings.notificationsEnabled,
      biometricEnabled: settings.biometricEnabled,
    },
  };
}
