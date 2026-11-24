import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsNotEmpty,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import {
  DEVICE_TOKEN_MAX_LENGTH,
  DEVICE_TOKEN_MIN_LENGTH,
  DEVICE_TOKEN_PATTERN,
} from './register-device-token.dto';

function trimString({ value }: { value: unknown }): unknown {
  return typeof value === 'string' ? value.trim() : value;
}

/**
 * Payload para revocar un token FCM del usuario autenticado por valor en body.
 * Nunca se expone el token en la URL ni en mensajes de error (I-02).
 */
export class RevokeDeviceTokenDto {
  @ApiProperty({
    description: 'Token FCM a revocar para el usuario autenticado.',
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
}
