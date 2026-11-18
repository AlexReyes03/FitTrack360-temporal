import { ApiProperty } from '@nestjs/swagger';

/** Perfil sincronizado tras register/session (sin tokens: el Bearer es Firebase). */
export class AuthUserDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  email!: string;

  @ApiProperty()
  username!: string;

  @ApiProperty()
  displayName!: string;

  @ApiProperty({ description: 'UID de Firebase Auth' })
  firebaseUid!: string;
}
