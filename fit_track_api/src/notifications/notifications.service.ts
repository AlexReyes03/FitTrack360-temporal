import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, Notification } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationQueryDto } from './dto/notification-query.dto';
import {
  NotificationPageDto,
  NotificationResponseDto,
  prismaNotificationType,
} from './dto/notification-response.dto';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(
    userId: string,
    query: NotificationQueryDto,
  ): Promise<NotificationPageDto> {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? 20;
    const where: Prisma.NotificationWhereInput = {
      userId,
      ...(query.isRead === undefined ? {} : { isRead: query.isRead }),
      ...(query.type === undefined
        ? {}
        : { type: prismaNotificationType(query.type) }),
    };
    const [items, total] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.notification.count({ where }),
    ]);
    return {
      items: items.map(NotificationResponseDto.fromRow),
      total,
      page,
      pageSize,
    };
  }

  async unreadCount(userId: string): Promise<{ count: number }> {
    return {
      count: await this.prisma.notification.count({
        where: { userId, isRead: false },
      }),
    };
  }

  private async owned(userId: string, id: string): Promise<Notification> {
    const row = await this.prisma.notification.findFirst({
      where: { id, userId },
    });
    if (!row) throw new NotFoundException('Notificación no encontrada');
    return row;
  }

  async findOne(userId: string, id: string): Promise<NotificationResponseDto> {
    return NotificationResponseDto.fromRow(await this.owned(userId, id));
  }

  async updateRead(
    userId: string,
    id: string,
    isRead: boolean,
  ): Promise<NotificationResponseDto> {
    const result = await this.prisma.notification.updateMany({
      where: { id, userId },
      data: { isRead, readAt: isRead ? new Date() : null },
    });
    if (!result.count)
      throw new NotFoundException('Notificación no encontrada');
    return this.findOne(userId, id);
  }

  async readAll(userId: string): Promise<{ count: number }> {
    return this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async remove(userId: string, id: string): Promise<void> {
    const result = await this.prisma.notification.deleteMany({
      where: { id, userId },
    });
    if (!result.count)
      throw new NotFoundException('Notificación no encontrada');
  }

  async removeAll(userId: string): Promise<{ count: number }> {
    return this.prisma.notification.deleteMany({ where: { userId } });
  }
}
