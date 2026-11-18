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
import { WorkoutResponseDto } from '../workouts/dto/workout-response.dto';
import { RoutineResponseDto } from './dto/routine-response.dto';
import {
  CreateRoutineDto,
  StartRoutineDto,
  UpdateRoutineDto,
} from './dto/routine.dto';
import { RoutinesService } from './routines.service';

@ApiTags('routines')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('routines')
export class RoutinesController {
  constructor(private readonly routines: RoutinesService) {}

  private user(req: AuthenticatedRequest): string {
    if (!req.user?.sub) throw new UnauthorizedException('Token requerido');
    return req.user.sub;
  }

  @Post()
  @ApiOperation({ summary: 'Crea una rutina con ejercicios ordenados' })
  @ApiCreatedResponse({ type: RoutineResponseDto })
  @ApiBadRequestResponse({
    description: 'Nombre o ejercicios inválidos (400)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  create(
    @Req() req: AuthenticatedRequest,
    @Body() dto: CreateRoutineDto,
  ): Promise<RoutineResponseDto> {
    return this.routines.create(
      this.user(req),
      dto,
    ) as Promise<RoutineResponseDto>;
  }

  @Get()
  @ApiOperation({ summary: 'Lista las rutinas del usuario autenticado' })
  @ApiOkResponse({ type: [RoutineResponseDto] })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  findAll(@Req() req: AuthenticatedRequest): Promise<RoutineResponseDto[]> {
    return this.routines.findAll(this.user(req)) as Promise<
      RoutineResponseDto[]
    >;
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtiene el detalle de una rutina propia' })
  @ApiParam({ name: 'id' })
  @ApiOkResponse({ type: RoutineResponseDto })
  @ApiNotFoundResponse({
    description: 'Rutina no encontrada o ajena (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  findOne(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<RoutineResponseDto> {
    return this.routines.findOne(
      this.user(req),
      id,
    ) as Promise<RoutineResponseDto>;
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Actualiza una rutina propia' })
  @ApiParam({ name: 'id' })
  @ApiOkResponse({ type: RoutineResponseDto })
  @ApiBadRequestResponse({
    description: 'Nombre o ejercicios inválidos (400)',
  })
  @ApiNotFoundResponse({
    description: 'Rutina no encontrada o ajena (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  update(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateRoutineDto,
  ): Promise<RoutineResponseDto> {
    return this.routines.update(
      this.user(req),
      id,
      dto,
    ) as Promise<RoutineResponseDto>;
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Elimina una rutina propia' })
  @ApiParam({ name: 'id' })
  @ApiNoContentResponse({ description: 'Rutina eliminada' })
  @ApiNotFoundResponse({
    description: 'Rutina no encontrada o ajena (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  remove(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    return this.routines.remove(this.user(req), id);
  }

  @Post(':id/duplicate')
  @ApiOperation({ summary: 'Duplica una rutina propia' })
  @ApiParam({ name: 'id' })
  @ApiCreatedResponse({ type: RoutineResponseDto })
  @ApiNotFoundResponse({
    description: 'Rutina no encontrada o ajena (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  duplicate(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<RoutineResponseDto> {
    return this.routines.duplicate(
      this.user(req),
      id,
    ) as Promise<RoutineResponseDto>;
  }

  @Post(':id/start')
  @ApiOperation({
    summary: 'Inicia una sesión de entrenamiento a partir de la rutina',
  })
  @ApiParam({ name: 'id' })
  @ApiCreatedResponse({ type: WorkoutResponseDto })
  @ApiBadRequestResponse({ description: 'Datos de sesión inválidos (400)' })
  @ApiNotFoundResponse({
    description: 'Rutina no encontrada o ajena (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  start(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: StartRoutineDto,
  ): Promise<WorkoutResponseDto> {
    return this.routines.start(
      this.user(req),
      id,
      dto.startedAt,
    ) as Promise<WorkoutResponseDto>;
  }
}
