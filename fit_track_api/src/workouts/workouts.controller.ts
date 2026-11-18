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
import { CreateWorkoutDto } from './dto/create-workout.dto';
import { UpdateWorkoutDto } from './dto/update-workout.dto';
import { WorkoutResponseDto } from './dto/workout-response.dto';
import { WorkoutsService } from './workouts.service';

@ApiTags('workouts')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('workouts')
export class WorkoutsController {
  constructor(private readonly workoutsService: WorkoutsService) {}

  @Post()
  @ApiOperation({
    summary:
      'Crea una sesión con series, volumen, duración y comparación del mismo usuario',
  })
  @ApiCreatedResponse({
    description: 'Sesión creada con sus series',
    type: WorkoutResponseDto,
  })
  @ApiBadRequestResponse({
    description:
      'Fechas inválidas, series mal formadas o ejercicio inexistente (400)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  create(
    @Req() req: AuthenticatedRequest,
    @Body() createWorkoutDto: CreateWorkoutDto,
  ): Promise<WorkoutResponseDto> {
    const userId = this.getUserId(req);
    return this.workoutsService.create(userId, createWorkoutDto);
  }

  @Get()
  @ApiOperation({
    summary:
      'Obtiene todas las sesiones de entrenamiento del usuario autenticado',
  })
  @ApiOkResponse({
    description: 'Lista de sesiones de entrenamiento pertenecientes al usuario',
    type: [WorkoutResponseDto],
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  findAll(@Req() req: AuthenticatedRequest): Promise<WorkoutResponseDto[]> {
    const userId = this.getUserId(req);
    return this.workoutsService.findAll(userId);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Obtiene el detalle de una sesión de entrenamiento por ID',
  })
  @ApiParam({
    name: 'id',
    description: 'Identificador UUID de la sesión de entrenamiento',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  @ApiOkResponse({
    description: 'Sesión de entrenamiento encontrada',
    type: WorkoutResponseDto,
  })
  @ApiNotFoundResponse({
    description:
      'Sesión no encontrada o no pertenece al usuario autenticado (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  findOne(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<WorkoutResponseDto> {
    const userId = this.getUserId(req);
    return this.workoutsService.findOne(userId, id);
  }

  @Patch(':id')
  @ApiOperation({
    summary:
      'Actualiza una sesión de entrenamiento perteneciente al usuario autenticado',
  })
  @ApiParam({
    name: 'id',
    description: 'Identificador UUID de la sesión de entrenamiento',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  @ApiOkResponse({
    description: 'Sesión actualizada exitosamente',
    type: WorkoutResponseDto,
  })
  @ApiBadRequestResponse({
    description:
      'Fechas inválidas, series mal formadas o ejercicio inexistente (400)',
  })
  @ApiNotFoundResponse({
    description:
      'Sesión no encontrada o no pertenece al usuario autenticado (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  update(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() updateWorkoutDto: UpdateWorkoutDto,
  ): Promise<WorkoutResponseDto> {
    const userId = this.getUserId(req);
    return this.workoutsService.update(userId, id, updateWorkoutDto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary:
      'Elimina una sesión de entrenamiento perteneciente al usuario autenticado',
  })
  @ApiParam({
    name: 'id',
    description: 'Identificador UUID de la sesión de entrenamiento',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  @ApiNoContentResponse({ description: 'Sesión eliminada exitosamente' })
  @ApiNotFoundResponse({
    description:
      'Sesión no encontrada o no pertenece al usuario autenticado (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  async remove(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    const userId = this.getUserId(req);
    await this.workoutsService.remove(userId, id);
  }

  private getUserId(req: AuthenticatedRequest): string {
    const userId = req.user?.sub;
    if (!userId) {
      throw new UnauthorizedException('Token requerido');
    }
    return userId;
  }
}
