import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { WorkoutsModule } from '../workouts/workouts.module';
import { RoutinesController } from './routines.controller';
import { RoutinesService } from './routines.service';
@Module({
  imports: [AuthModule, WorkoutsModule],
  controllers: [RoutinesController],
  providers: [RoutinesService],
})
export class RoutinesModule {}
