import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
import { CreateMealDto } from './dto/create-meal.dto';
import {
  DailyNutritionSummaryDto,
  DailySummaryQueryDto,
} from './dto/daily-nutrition-summary.dto';
import { UpdateMealDto } from './dto/update-meal.dto';
import { MealResponseDto } from './dto/meal-response.dto';
import { MealsService } from './meals.service';

@ApiTags('meals')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('meals')
export class MealsController {
  constructor(private readonly mealsService: MealsService) {}

  @Post()
  @ApiOperation({
    summary:
      'Crea un nuevo registro de comida con alimentos anidados y macros congelados',
  })
  @ApiCreatedResponse({
    description:
      'Comida registrada exitosamente con sus alimentos y totales calculados',
    type: MealResponseDto,
  })
  @ApiBadRequestResponse({
    description:
      'Datos inválidos, mealType incorrecto o macros negativos (400)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  create(
    @Req() req: AuthenticatedRequest,
    @Body() createMealDto: CreateMealDto,
  ): Promise<MealResponseDto> {
    const userId = this.getUserId(req);
    return this.mealsService.create(userId, createMealDto);
  }

  @Get()
  @ApiOperation({
    summary: 'Obtiene todos los registros de comida del usuario autenticado',
  })
  @ApiOkResponse({
    description: 'Lista de comidas pertenecientes al usuario autenticado',
    type: [MealResponseDto],
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  findAll(@Req() req: AuthenticatedRequest): Promise<MealResponseDto[]> {
    const userId = this.getUserId(req);
    return this.mealsService.findAll(userId);
  }

  @Get('summary')
  @ApiOperation({
    summary:
      'Obtiene el resumen diario o por rango de fechas de calorías y macronutrientes desglosado por tipo de comida',
  })
  @ApiOkResponse({
    description: 'Resumen nutricional del usuario autenticado',
    type: DailyNutritionSummaryDto,
  })
  @ApiBadRequestResponse({
    description: 'Parámetros de fecha inválidos (400)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  getDailySummary(
    @Req() req: AuthenticatedRequest,
    @Query() query: DailySummaryQueryDto,
  ): Promise<DailyNutritionSummaryDto> {
    const userId = this.getUserId(req);
    return this.mealsService.getDailySummary(userId, query);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Obtiene el detalle de un registro de comida por ID',
  })
  @ApiOkResponse({
    description: 'Registro de comida encontrado',
    type: MealResponseDto,
  })
  @ApiNotFoundResponse({
    description:
      'Comida no encontrada o no pertenece al usuario autenticado (404)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  findOne(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<MealResponseDto> {
    const userId = this.getUserId(req);
    return this.mealsService.findOne(userId, id);
  }

  @Patch(':id')
  @ApiOperation({
    summary:
      'Actualiza un registro de comida perteneciente al usuario autenticado',
  })
  @ApiOkResponse({
    description: 'Comida actualizada exitosamente',
    type: MealResponseDto,
  })
  @ApiBadRequestResponse({
    description: 'Datos inválidos o mealType incorrecto (400)',
  })
  @ApiNotFoundResponse({
    description:
      'Comida no encontrada o no pertenece al usuario autenticado (404)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  update(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() updateMealDto: UpdateMealDto,
  ): Promise<MealResponseDto> {
    const userId = this.getUserId(req);
    return this.mealsService.update(userId, id, updateMealDto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary:
      'Elimina un registro de comida perteneciente al usuario autenticado',
  })
  @ApiNoContentResponse({ description: 'Comida eliminada exitosamente' })
  @ApiNotFoundResponse({
    description:
      'Comida no encontrada o no pertenece al usuario autenticado (404)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  async remove(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    const userId = this.getUserId(req);
    await this.mealsService.remove(userId, id);
  }

  private getUserId(req: AuthenticatedRequest): string {
    const userId = req.user?.sub;
    if (!userId) {
      throw new UnauthorizedException('Token requerido');
    }
    return userId;
  }
}
