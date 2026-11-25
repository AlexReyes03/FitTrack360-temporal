import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { DeviceTokensController } from './device-tokens.controller';
import { DeviceTokensService } from './device-tokens.service';
import { createPushMessagingClient } from './push/push-messaging.factory';
import { PUSH_MESSAGING_CLIENT } from './push/push-messaging.client';
import { NotificationPushService } from './push/notification-push.service';

@Module({
  imports: [AuthModule, PrismaModule, ConfigModule],
  controllers: [DeviceTokensController],
  providers: [
    DeviceTokensService,
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
