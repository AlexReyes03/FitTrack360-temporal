import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
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
  @Post() create(
    @Req() req: AuthenticatedRequest,
    @Body() dto: CreateRoutineDto,
  ) {
    return this.routines.create(this.user(req), dto);
  }
  @Get() findAll(@Req() req: AuthenticatedRequest) {
    return this.routines.findAll(this.user(req));
  }
  @Get(':id') findOne(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ) {
    return this.routines.findOne(this.user(req), id);
  }
  @Patch(':id') update(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateRoutineDto,
  ) {
    return this.routines.update(this.user(req), id, dto);
  }
  @Delete(':id') @HttpCode(204) remove(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ) {
    return this.routines.remove(this.user(req), id);
  }
  @Post(':id/duplicate') duplicate(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ) {
    return this.routines.duplicate(this.user(req), id);
  }
  @Post(':id/start') start(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: StartRoutineDto,
  ) {
    return this.routines.start(this.user(req), id, dto.startedAt);
  }
}
