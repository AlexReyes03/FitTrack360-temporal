import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

export const NOTIFICATION_TYPES = [
  'new_login',
  'password_changed',
  'reminder',
  'system',
] as const;
export type NotificationTypeQuery = (typeof NOTIFICATION_TYPES)[number];

export class NotificationQueryDto {
  @ApiPropertyOptional({ type: Boolean })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) => {
    if (value === 'true') return true;
    if (value === 'false') return false;
    return value;
  })
  @IsBoolean()
  isRead?: boolean;

  @ApiPropertyOptional({ enum: NOTIFICATION_TYPES })
  @IsOptional()
  @IsIn(NOTIFICATION_TYPES)
  type?: NotificationTypeQuery;

  @ApiPropertyOptional({ minimum: 1, maximum: 1000000, default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1000000)
  page?: number;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize?: number;
}
