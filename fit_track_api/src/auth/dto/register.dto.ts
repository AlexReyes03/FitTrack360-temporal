import { ApiProperty } from '@nestjs/swagger';
import {
  Equals,
  IsBoolean,
  IsNotEmpty,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

/**
 * Registro de perfil en PostgreSQL tras crear la cuenta en Firebase Auth.
 * El correo y el uid salen del ID token (Bearer), no del body.
 */
export class RegisterDto {
  @ApiProperty({ example: 'ana_torres', minLength: 3, maxLength: 30 })
  @IsString()
  @MinLength(3)
  @MaxLength(30)
  @Matches(/^[a-zA-Z0-9_]+$/)
  username!: string;

  @ApiProperty({ example: 'Ana Torres', minLength: 1, maxLength: 80 })
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  displayName!: string;

  @ApiProperty({ example: true })
  @IsBoolean()
  @Equals(true)
  privacyConsent!: boolean;

  @ApiProperty({ example: '1' })
  @IsString()
  @IsNotEmpty()
  privacyNoticeVersion!: string;
}
