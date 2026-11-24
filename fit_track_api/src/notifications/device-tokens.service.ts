import { Injectable, NotFoundException } from '@nestjs/common';
import type { DevicePlatform, DeviceToken } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import type { DeviceTokenResponseDto } from './dto/device-token-response.dto';
import type { RegisterDeviceTokenDto } from './dto/register-device-token.dto';

function toDeviceTokenResponse(record: DeviceToken): DeviceTokenResponseDto {
  return {
    id: record.id,
    platform: record.platform,
    label: record.deviceLabel,
    lastSeenAt: record.lastSeenAt.toISOString(),
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}

@Injectable()
export class DeviceTokensService {
  constructor(private readonly prisma: PrismaService) {}

  async register(
    userId: string,
    dto: RegisterDeviceTokenDto,
  ): Promise<DeviceTokenResponseDto> {
    const now = new Date();

    const device = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.deviceToken.findUnique({
        where: { token: dto.token },
        select: { userId: true },
      });
      const reassigned = existing !== null && existing.userId !== userId;

      const updateData: {
        userId: string;
        platform: DevicePlatform;
        lastSeenAt: Date;
        deviceLabel?: string | null;
      } = {
        userId,
        platform: dto.platform,
        lastSeenAt: now,
      };

      if (dto.label !== undefined) {
        updateData.deviceLabel = dto.label;
      } else if (reassigned) {
        updateData.deviceLabel = null;
      }

      const upserted = await tx.deviceToken.upsert({
        where: { token: dto.token },
        create: {
          userId,
          token: dto.token,
          platform: dto.platform,
          deviceLabel: dto.label ?? null,
          lastSeenAt: now,
        },
        update: updateData,
      });

      if (dto.previousToken && dto.previousToken !== dto.token) {
        await tx.deviceToken.deleteMany({
          where: {
            token: dto.previousToken,
            userId,
          },
        });
      }

      return upserted;
    });

    return toDeviceTokenResponse(device);
  }

  async findAll(userId: string): Promise<DeviceTokenResponseDto[]> {
    const devices = await this.prisma.deviceToken.findMany({
      where: { userId },
      orderBy: { lastSeenAt: 'desc' },
    });
    return devices.map(toDeviceTokenResponse);
  }

  async findOne(userId: string, id: string): Promise<DeviceTokenResponseDto> {
    const device = await this.prisma.deviceToken.findFirst({
      where: { id, userId },
    });
    if (!device) {
      throw new NotFoundException('Dispositivo no encontrado');
    }
    return toDeviceTokenResponse(device);
  }

  async removeById(userId: string, id: string): Promise<void> {
    const deleted = await this.prisma.deviceToken.deleteMany({
      where: { id, userId },
    });
    if (deleted.count === 0) {
      throw new NotFoundException('Dispositivo no encontrado');
    }
  }

  async revokeByToken(userId: string, token: string): Promise<void> {
    await this.prisma.deviceToken.deleteMany({
      where: { token, userId },
    });
  }
}
