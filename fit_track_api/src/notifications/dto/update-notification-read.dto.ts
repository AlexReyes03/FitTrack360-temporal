import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean } from 'class-validator';

export class UpdateNotificationReadDto {
  @ApiProperty()
  @IsBoolean()
  isRead!: boolean;
}
