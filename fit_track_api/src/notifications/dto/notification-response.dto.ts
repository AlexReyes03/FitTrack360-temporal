import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Notification, NotificationType } from '@prisma/client';

export class NotificationResponseDto {
  @ApiProperty() id!: string;
  @ApiProperty({
    enum: ['new_login', 'password_changed', 'reminder', 'system'],
  })
  type!: string;
  @ApiProperty() title!: string;
  @ApiProperty() body!: string;
  @ApiProperty() isRead!: boolean;
  @ApiPropertyOptional({ nullable: true }) readAt!: Date | null;
  @ApiPropertyOptional({ nullable: true }) targetRoute!: string | null;
  @ApiProperty() createdAt!: Date;

  static fromRow(row: Notification): NotificationResponseDto {
    return {
      id: row.id,
      type: row.type.toLowerCase(),
      title: row.title,
      body: row.body,
      isRead: row.isRead,
      readAt: row.readAt,
      targetRoute: row.targetRoute,
      createdAt: row.createdAt,
    };
  }
}

export const prismaNotificationType = (value: string): NotificationType =>
  value.toUpperCase() as NotificationType;

export class NotificationPageDto {
  @ApiProperty({ type: [NotificationResponseDto] })
  items!: NotificationResponseDto[];
  @ApiProperty() total!: number;
  @ApiProperty() page!: number;
  @ApiProperty() pageSize!: number;
}

export class NotificationCountDto {
  @ApiProperty() count!: number;
}
