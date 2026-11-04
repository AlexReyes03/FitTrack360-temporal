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
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
import { CreateWorkoutDto } from './dto/create-workout.dto';
import { UpdateWorkoutDto } from './dto/update-workout.dto';
import { WorkoutResponseDto } from './dto/workout-response.dto';
import { WorkoutsService } from './workouts.service';

@UseGuards(JwtAuthGuard)
@Controller('workouts')
export class WorkoutsController {
  constructor(private readonly workoutsService: WorkoutsService) {}

  @Post()
  create(
    @Req() req: AuthenticatedRequest,
    @Body() createWorkoutDto: CreateWorkoutDto,
  ): Promise<WorkoutResponseDto> {
    const userId = this.getUserId(req);
    return this.workoutsService.create(userId, createWorkoutDto);
  }

  @Get()
  findAll(@Req() req: AuthenticatedRequest): Promise<WorkoutResponseDto[]> {
    const userId = this.getUserId(req);
    return this.workoutsService.findAll(userId);
  }

  @Get(':id')
  findOne(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<WorkoutResponseDto> {
    const userId = this.getUserId(req);
    return this.workoutsService.findOne(userId, id);
  }

  @Patch(':id')
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
