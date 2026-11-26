import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { DeviceTokensController } from './device-tokens.controller';
import { DeviceTokensService } from './device-tokens.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { NotificationPushService } from './push/notification-push.service';
import { PUSH_MESSAGING_CLIENT } from './push/push-messaging.client';
import { createPushMessagingClient } from './push/push-messaging.factory';

@Module({
  imports: [AuthModule, PrismaModule, ConfigModule],
  controllers: [DeviceTokensController, NotificationsController],
  providers: [
    DeviceTokensService,
    NotificationsService,
    NotificationPushService,
    {
      provide: PUSH_MESSAGING_CLIENT,
      inject: [ConfigService],
      useFactory: createPushMessagingClient,
    },
  ],
  exports: [
    DeviceTokensService,
    NotificationPushService,
    PUSH_MESSAGING_CLIENT,
  ],
})
export class NotificationsModule {}
