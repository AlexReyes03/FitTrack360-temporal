import {
  Controller,
  Get,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
import { DashboardService } from './dashboard.service';
import { DashboardQueryDto } from './dto/dashboard-query.dto';
import { DashboardTodayDto } from './dto/dashboard-response.dto';

@ApiTags('dashboard')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  @Get('today')
  @ApiOperation({
    summary:
      'Resumen del día: comidas contra metas, sesión de hoy o la última y última métrica',
  })
  @ApiOkResponse({ type: DashboardTodayDto })
  @ApiBadRequestResponse({ description: 'date o utcOffsetMinutes inválidos' })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido' })
  today(
    @Req() request: AuthenticatedRequest,
    @Query() query: DashboardQueryDto,
  ): Promise<DashboardTodayDto> {
    const userId = request.user?.sub;
    if (!userId) {
      throw new UnauthorizedException('Token requerido');
    }
    return this.dashboardService.today(userId, query);
  }
}
