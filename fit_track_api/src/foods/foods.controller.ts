import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiQuery,
  ApiServiceUnavailableResponse,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { FoodItemDto, UsdaUnavailableDto } from './dto/food-item.dto';
import { FoodSearchQueryDto } from './dto/food-search-query.dto';
import { UsdaFoodService } from './usda-food.service';

@ApiTags('foods')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('foods')
export class FoodsController {
  constructor(private readonly usdaFoodService: UsdaFoodService) {}

  @Get('search')
  @ApiOperation({
    summary: 'Busca alimentos en USDA FDC mediante el proxy',
    description:
      'Llama a USDA FoodData Central con timeout de 5 s y devuelve como máximo 20 alimentos con kcal, proteína, carbohidratos y grasa por 100 g. Si USDA no responde, la key no está configurada o la petición no es válida, la respuesta no es 200 y Flutter abre captura manual. La API key no sale en esta respuesta.',
  })
  @ApiQuery({
    name: 'q',
    required: true,
    description: 'Término de búsqueda (1 a 120 caracteres)',
    example: 'oats',
  })
  @ApiOkResponse({
    description:
      'Alimentos normalizados. Lista vacía si USDA no tiene coincidencias.',
    type: [FoodItemDto],
  })
  @ApiBadRequestResponse({
    description:
      'q ausente, vacío, no textual o mayor a 120 caracteres (400). Flutter abre captura manual.',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  @ApiServiceUnavailableResponse({
    description:
      'Timeout de 5 s, USDA caído, cuota agotada o USDA_FDC_API_KEY ausente (503). Flutter abre captura manual.',
    type: UsdaUnavailableDto,
  })
  search(@Query() query: FoodSearchQueryDto): Promise<FoodItemDto[]> {
    return this.usdaFoodService.search(query.q);
  }
}
