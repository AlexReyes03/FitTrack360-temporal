import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiParam,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ExerciseQueryDto } from './dto/exercise-query.dto';
import {
  ExercisePageResponseDto,
  ExerciseResponseDto,
} from './dto/exercise-response.dto';
import { ExercisesService } from './exercises.service';

@ApiTags('exercises')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('exercises')
export class ExercisesController {
  constructor(private readonly exercisesService: ExercisesService) {}

  @Get()
  @ApiOperation({
    summary: 'Catálogo de ejercicios con filtros, búsqueda, paginación y orden',
  })
  @ApiOkResponse({
    description:
      'Página del catálogo. total cuenta todas las coincidencias, no solo esta página',
    type: ExercisePageResponseDto,
  })
  @ApiBadRequestResponse({
    description: 'Paginación, orden o filtros inválidos (400)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  findAll(@Query() query: ExerciseQueryDto): Promise<ExercisePageResponseDto> {
    return this.exercisesService.findAll(query);
  }

  @Get(':id')
  @ApiOperation({
    summary:
      'Detalle de un ejercicio: instrucciones, pasos, músculos, media y atribución',
  })
  @ApiParam({
    name: 'id',
    description: 'Identificador del catálogo (ej. 0001)',
    example: '0001',
  })
  @ApiOkResponse({
    description: 'Ejercicio encontrado',
    type: ExerciseResponseDto,
  })
  @ApiNotFoundResponse({
    description: 'No existe un ejercicio con ese id (404)',
  })
  @ApiUnauthorizedResponse({
    description: 'Token no proporcionado o inválido (401)',
  })
  findOne(@Param('id') id: string): Promise<ExerciseResponseDto> {
    return this.exercisesService.findOne(id);
  }
}
