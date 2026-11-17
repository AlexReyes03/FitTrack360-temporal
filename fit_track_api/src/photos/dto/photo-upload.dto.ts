import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, IsUUID } from 'class-validator';
export class PhotoUploadDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @IsUUID() mealId?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @IsUUID() metricId?: string;
}
