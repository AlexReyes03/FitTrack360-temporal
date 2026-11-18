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
import {
  CreateMetricDto,
  MetricResponseDto,
  UpdateMetricDto,
} from './dto/metric.dto';
import { ProgressService } from './progress.service';

@ApiTags('progress')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('progress/metrics')
export class ProgressController {
  constructor(private readonly progress: ProgressService) {}

  @Post()
  @ApiOperation({ summary: 'Registra una métrica corporal del usuario' })
  @ApiCreatedResponse({ type: MetricResponseDto })
  @ApiBadRequestResponse({ description: 'Payload inválido (400)' })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  create(
    @Req() req: AuthenticatedRequest,
    @Body() dto: CreateMetricDto,
  ): Promise<MetricResponseDto> {
    return this.progress.create(this.userId(req), dto);
  }

  @Get()
  @ApiOperation({ summary: 'Lista las métricas corporales del usuario' })
  @ApiOkResponse({ type: [MetricResponseDto] })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  findAll(@Req() req: AuthenticatedRequest): Promise<MetricResponseDto[]> {
    return this.progress.findAll(this.userId(req));
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtiene una métrica corporal por id' })
  @ApiParam({ name: 'id' })
  @ApiOkResponse({ type: MetricResponseDto })
  @ApiNotFoundResponse({
    description: 'Métrica no encontrada o ajena (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  findOne(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<MetricResponseDto> {
    return this.progress.findOne(this.userId(req), id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Actualiza una métrica corporal propia' })
  @ApiParam({ name: 'id' })
  @ApiOkResponse({ type: MetricResponseDto })
  @ApiBadRequestResponse({ description: 'Payload inválido (400)' })
  @ApiNotFoundResponse({
    description: 'Métrica no encontrada o ajena (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  update(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateMetricDto,
  ): Promise<MetricResponseDto> {
    return this.progress.update(this.userId(req), id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Elimina una métrica corporal propia' })
  @ApiParam({ name: 'id' })
  @ApiNoContentResponse({ description: 'Métrica eliminada' })
  @ApiNotFoundResponse({
    description: 'Métrica no encontrada o ajena (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  async remove(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    await this.progress.remove(this.userId(req), id);
  }

  private userId(req: AuthenticatedRequest): string {
    if (!req.user?.sub) {
      throw new UnauthorizedException('Token requerido');
    }
    return req.user.sub;
  }
}
