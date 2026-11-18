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
import { BodyMetricResponseDto } from './dto/body-metric-response.dto';
import { CreateBodyMetricDto } from './dto/create-body-metric.dto';
import { UpdateBodyMetricDto } from './dto/update-body-metric.dto';
import { ProgressService } from './progress.service';

@UseGuards(JwtAuthGuard)
@Controller('progress')
export class ProgressController {
  constructor(private readonly progressService: ProgressService) {}

  @Post()
  create(
    @Req() req: AuthenticatedRequest,
    @Body() createBodyMetricDto: CreateBodyMetricDto,
  ): Promise<BodyMetricResponseDto> {
    const userId = this.getUserId(req);
    return this.progressService.create(userId, createBodyMetricDto);
  }

  @Get()
  findAll(@Req() req: AuthenticatedRequest): Promise<BodyMetricResponseDto[]> {
    const userId = this.getUserId(req);
    return this.progressService.findAll(userId);
  }

  @Get(':id')
  findOne(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<BodyMetricResponseDto> {
    const userId = this.getUserId(req);
    return this.progressService.findOne(userId, id);
  }

  @Patch(':id')
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
