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
  ApiParam,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
import { BodyMetricResponseDto } from './dto/body-metric-response.dto';
import { CreateBodyMetricDto } from './dto/create-body-metric.dto';
import { ProgressRangeQueryDto } from './dto/progress-query.dto';
import {
  LatestBodyMetricResponseDto,
  ProgressSeriesResponseDto,
} from './dto/progress-series-response.dto';
import { UpdateBodyMetricDto } from './dto/update-body-metric.dto';
import { ProgressService } from './progress.service';

@ApiTags('progress')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('progress')
export class ProgressController {
  constructor(private readonly progressService: ProgressService) {}

  @Post()
  @ApiOperation({
    summary:
      'Registra una nueva medición biométrica para el usuario autenticado',
  })
  @ApiCreatedResponse({
    description: 'Medición biométrica registrada exitosamente',
    type: BodyMetricResponseDto,
  })
  @ApiBadRequestResponse({
    description:
      'Peso no positivo, campos opcionales negativos o fecha futura (400)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  create(
    @Req() req: AuthenticatedRequest,
    @Body() createBodyMetricDto: CreateBodyMetricDto,
  ): Promise<BodyMetricResponseDto> {
    const userId = this.getUserId(req);
    return this.progressService.create(userId, createBodyMetricDto);
  }

  @Get()
  @ApiOperation({
    summary:
      'Obtiene el historial de métricas biométricas del usuario autenticado, filtrable por rango de fechas (from/to)',
    description:
      'Los filtros from/to en formato solo-fecha (YYYY-MM-DD) operan en UTC (00:00:00.000Z para from y 23:59:59.999Z para to). Devuelve como máximo 1000 registros ordenados del más reciente al más antiguo.',
  })
  @ApiOkResponse({
    description:
      'Historial de métricas del usuario ordenado de la más reciente a la más antigua',
    type: [BodyMetricResponseDto],
  })
  @ApiBadRequestResponse({
    description: 'Parámetros de rango de fechas inválidos o invertidos (400)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  findAll(
    @Req() req: AuthenticatedRequest,
    @Query() query: ProgressRangeQueryDto,
  ): Promise<BodyMetricResponseDto[]> {
    const userId = this.getUserId(req);
    return this.progressService.findAll(userId, query);
  }

  @Get('latest')
  @ApiOperation({
    summary:
      'Obtiene la última medición biométrica registrada por el usuario autenticado',
  })
  @ApiOkResponse({
    description: 'Última medición biométrica del usuario (o null si no existe)',
    type: LatestBodyMetricResponseDto,
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  findLatest(
    @Req() req: AuthenticatedRequest,
  ): Promise<LatestBodyMetricResponseDto> {
    const userId = this.getUserId(req);
    return this.progressService.findLatest(userId);
  }

  @Get('series')
  @ApiOperation({
    summary:
      'Obtiene una serie cronológica ascendente de métricas biométricas lista para graficar en Flutter',
    description:
      'Los filtros from/to en formato solo-fecha (YYYY-MM-DD) operan en UTC (00:00:00.000Z para from y 23:59:59.999Z para to). Devuelve como máximo 1000 puntos ordenados cronológicamente.',
  })
  @ApiOkResponse({
    description: 'Serie biométrica ordenada cronológicamente por measuredAt',
    type: ProgressSeriesResponseDto,
  })
  @ApiBadRequestResponse({
    description: 'Parámetros de rango de fechas inválidos o invertidos (400)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  getSeries(
    @Req() req: AuthenticatedRequest,
    @Query() query: ProgressRangeQueryDto,
  ): Promise<ProgressSeriesResponseDto> {
    const userId = this.getUserId(req);
    return this.progressService.getSeries(userId, query);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Obtiene el detalle de una medición biométrica por ID',
  })
  @ApiParam({
    name: 'id',
    description: 'Identificador UUID de la medición biométrica',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  @ApiOkResponse({
    description: 'Medición biométrica encontrada',
    type: BodyMetricResponseDto,
  })
  @ApiNotFoundResponse({
    description:
      'Métrica no encontrada o no pertenece al usuario autenticado (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  findOne(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<BodyMetricResponseDto> {
    const userId = this.getUserId(req);
    return this.progressService.findOne(userId, id);
  }

  @Patch(':id')
  @ApiOperation({
    summary:
      'Actualiza parcialmente una medición biométrica perteneciente al usuario autenticado',
  })
  @ApiParam({
    name: 'id',
    description: 'Identificador UUID de la medición biométrica',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  @ApiOkResponse({
    description: 'Medición biométrica actualizada exitosamente',
    type: BodyMetricResponseDto,
  })
  @ApiBadRequestResponse({
    description:
      'Peso no positivo, campos opcionales negativos o fecha futura (400)',
  })
  @ApiNotFoundResponse({
    description:
      'Métrica no encontrada o no pertenece al usuario autenticado (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  update(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() updateBodyMetricDto: UpdateBodyMetricDto,
  ): Promise<BodyMetricResponseDto> {
    const userId = this.getUserId(req);
    return this.progressService.update(userId, id, updateBodyMetricDto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary:
      'Elimina una medición biométrica perteneciente al usuario autenticado',
  })
  @ApiParam({
    name: 'id',
    description: 'Identificador UUID de la medición biométrica',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  @ApiNoContentResponse({
    description: 'Medición biométrica eliminada exitosamente',
  })
  @ApiNotFoundResponse({
    description:
      'Métrica no encontrada o no pertenece al usuario autenticado (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  async remove(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    const userId = this.getUserId(req);
    await this.progressService.remove(userId, id);
  }

  private getUserId(req: AuthenticatedRequest): string {
    const userId = req.user?.sub;
    if (!userId) {
      throw new UnauthorizedException('Token requerido');
    }
    return userId;
  }
}
