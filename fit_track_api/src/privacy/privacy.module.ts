import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { StorageModule } from '../storage/storage.module';
import { MePrivacyController, PrivacyController } from './privacy.controller';
import { PrivacyService } from './privacy.service';
@Module({
  imports: [AuthModule, StorageModule],
  controllers: [PrivacyController, MePrivacyController],
  providers: [PrivacyService],
})
export class PrivacyModule {}
