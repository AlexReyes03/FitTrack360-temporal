import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FoodsController } from './foods.controller';
import { FetchUsdaHttpClient, UsdaHttpClient } from './usda-http.client';
import { UsdaFoodService } from './usda-food.service';

@Module({
  imports: [AuthModule],
  controllers: [FoodsController],
  providers: [
    UsdaFoodService,
    { provide: UsdaHttpClient, useClass: FetchUsdaHttpClient },
  ],
  exports: [UsdaFoodService],
})
export class FoodsModule {}
