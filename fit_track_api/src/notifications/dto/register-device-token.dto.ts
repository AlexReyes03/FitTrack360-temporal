import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { DevicePlatform } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

export const DEVICE_TOKEN_MIN_LENGTH = 1;
export const DEVICE_TOKEN_MAX_LENGTH = 512;
export const DEVICE_LABEL_MAX_LENGTH = 100;
export const DEVICE_TOKEN_PATTERN = /^\S+$/;

function trimString({ value }: { value: unknown }): unknown {
  return typeof value === 'string' ? value.trim() : value;
}

/**
 * Payload para registrar o rotar un token FCM del usuario autenticado.
 * Los mensajes de validación omiten el valor recibido para evitar fugas (I-02).
 */
export class RegisterDeviceTokenDto {
  @ApiProperty({
    description: 'Token de registro FCM emitido para el dispositivo.',
    minLength: DEVICE_TOKEN_MIN_LENGTH,
    maxLength: DEVICE_TOKEN_MAX_LENGTH,
    example: 'fcm-token-placeholder',
  })
  @Transform(trimString)
  @IsString({
    message: 'El token de dispositivo debe ser una cadena válida.',
  })
  @IsNotEmpty({
    message: 'El token de dispositivo es obligatorio.',
  })
  @MinLength(DEVICE_TOKEN_MIN_LENGTH, {
    message: 'El token de dispositivo no cumple la longitud mínima permitida.',
  })
  @MaxLength(DEVICE_TOKEN_MAX_LENGTH, {
    message: 'El token de dispositivo excede la longitud máxima permitida.',
  })
  @Matches(DEVICE_TOKEN_PATTERN, {
    message: 'El token de dispositivo tiene un formato inválido.',
  })
  token!: string;

  @ApiProperty({
    description: 'Plataforma del dispositivo móvil.',
    enum: DevicePlatform,
    enumName: 'DevicePlatform',
    example: DevicePlatform.android,
  })
  @IsEnum(DevicePlatform, {
    message: 'La plataforma debe ser android o ios.',
  })
  platform!: DevicePlatform;

  @ApiPropertyOptional({
    description: 'Etiqueta opcional para identificar el dispositivo.',
    maxLength: DEVICE_LABEL_MAX_LENGTH,
    example: 'Pixel 8',
  })
  @IsOptional()
  @Transform(trimString)
  @IsString({
    message: 'La etiqueta del dispositivo debe ser una cadena válida.',
  })
  @IsNotEmpty({
    message: 'La etiqueta del dispositivo no puede estar vacía.',
  })
  @MaxLength(DEVICE_LABEL_MAX_LENGTH, {
    message: 'La etiqueta del dispositivo excede la longitud máxima permitida.',
  })
  label?: string;

  @ApiPropertyOptional({
    description:
      'Token FCM anterior del mismo usuario a revocar atómicamente al rotar.',
    minLength: DEVICE_TOKEN_MIN_LENGTH,
    maxLength: DEVICE_TOKEN_MAX_LENGTH,
    example: 'fcm-previous-token-placeholder',
  })
  @IsOptional()
  @Transform(trimString)
  @IsString({
    message: 'El token anterior debe ser una cadena válida.',
  })
  @IsNotEmpty({
    message: 'El token anterior no puede estar vacío.',
  })
  @MinLength(DEVICE_TOKEN_MIN_LENGTH, {
    message: 'El token anterior no cumple la longitud mínima permitida.',
  })
  @MaxLength(DEVICE_TOKEN_MAX_LENGTH, {
    message: 'El token anterior excede la longitud máxima permitida.',
  })
  @Matches(DEVICE_TOKEN_PATTERN, {
    message: 'El token anterior tiene un formato inválido.',
  })
  previousToken?: string;
}
