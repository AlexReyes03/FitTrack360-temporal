import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class PhotoResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  mimeType!: string;

  @ApiProperty()
  sizeBytes!: number;

  @ApiProperty()
  width!: number;

  @ApiProperty()
  height!: number;

  @ApiPropertyOptional({ nullable: true })
  mealId!: string | null;

  @ApiPropertyOptional({ nullable: true })
  metricId!: string | null;

  @ApiProperty()
  createdAt!: Date;
}
