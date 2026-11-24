import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { DevicePlatform } from '@prisma/client';

/**
 * Representación pública de un dispositivo registrado.
 * Omite el valor crudo del token FCM para evitar exposiciones innecesarias (I-02).
 */
export class DeviceTokenResponseDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ enum: DevicePlatform, enumName: 'DevicePlatform' })
  platform!: DevicePlatform;

  @ApiPropertyOptional({ type: String, nullable: true, example: 'Pixel 8' })
  label!: string | null;

  @ApiProperty({ format: 'date-time' })
  lastSeenAt!: string;

  @ApiProperty({ format: 'date-time' })
  createdAt!: string;

  @ApiProperty({ format: 'date-time' })
  updatedAt!: string;
}
