import { ApiProperty } from '@nestjs/swagger';

export class StoredFileDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  originalName!: string;

  @ApiProperty()
  mimeType!: string;

  @ApiProperty()
  size!: number;
}
