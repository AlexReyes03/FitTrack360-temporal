import { ApiProperty } from '@nestjs/swagger';

export class UserExportResponseDto {
  @ApiProperty({ description: 'Momento de la exportación en ISO 8601' })
  exportedAt!: string;

  @ApiProperty({
    description:
      'Datos personales exportables sin secretos (sin passwordHash ni firebaseUid)',
    type: 'object',
    additionalProperties: true,
  })
  data!: Record<string, unknown>;
}
