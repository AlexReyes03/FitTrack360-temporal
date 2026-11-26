import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { DeviceTokensController } from './device-tokens.controller';
import { DeviceTokensService } from './device-tokens.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [DeviceTokensController, NotificationsController],
  providers: [DeviceTokensService, NotificationsService],
  exports: [DeviceTokensService],
})
export class NotificationsModule {}
