import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
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
import { ConsentDto } from './dto/consent.dto';
import { UserExportResponseDto } from './dto/user-export.dto';
import { PrivacyService } from './privacy.service';

@ApiTags('privacy')
@Controller('privacy')
export class PrivacyController {
  constructor(private readonly privacy: PrivacyService) {}

  private user(req: AuthenticatedRequest): string {
    if (!req.user?.sub) throw new UnauthorizedException('Token requerido');
    return req.user.sub;
  }

  @Get('notice')
  @ApiOperation({ summary: 'Aviso de privacidad público' })
  @ApiOkResponse({ description: 'Versión y secciones del aviso' })
  notice() {
    return this.privacy.notice();
  }

  @Post(':userId/consent')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Registra el consentimiento del propio usuario' })
  @ApiParam({ name: 'userId' })
  @ApiOkResponse({ description: 'Consentimiento registrado' })
  @ApiNotFoundResponse({
    description: 'Usuario ajeno o versión inválida (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  consent(
    @Req() req: AuthenticatedRequest,
    @Param('userId') userId: string,
    @Body() dto: ConsentDto,
  ) {
    return this.privacy.consent(this.user(req), userId, dto);
  }

  @Get(':userId/export')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Exporta los datos del propio usuario' })
  @ApiParam({ name: 'userId' })
  @ApiOkResponse({ type: UserExportResponseDto })
  @ApiNotFoundResponse({
    description: 'Usuario ajeno o inexistente (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  exportData(
    @Req() req: AuthenticatedRequest,
    @Param('userId') userId: string,
  ): Promise<UserExportResponseDto> {
    return this.privacy.exportData(
      this.user(req),
      userId,
    ) as Promise<UserExportResponseDto>;
  }

  @Delete(':userId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Elimina la cuenta propia (ARCO)' })
  @ApiParam({ name: 'userId' })
  @ApiNoContentResponse({ description: 'Cuenta eliminada' })
  @ApiNotFoundResponse({
    description: 'Usuario ajeno o inexistente (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  remove(@Req() req: AuthenticatedRequest, @Param('userId') userId: string) {
    return this.privacy.removeAccount(this.user(req), userId);
  }
}

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users/me')
export class MePrivacyController {
  constructor(private readonly privacy: PrivacyService) {}

  @Get('export')
  @ApiOperation({
    summary: 'Exporta los datos del usuario autenticado sin secretos',
  })
  @ApiOkResponse({ type: UserExportResponseDto })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  exportData(@Req() req: AuthenticatedRequest): Promise<UserExportResponseDto> {
    const userId = req.user?.sub;
    if (!userId) throw new UnauthorizedException('Token requerido');
    return this.privacy.exportData(
      userId,
      userId,
    ) as Promise<UserExportResponseDto>;
  }

  @Delete()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Elimina la cuenta del usuario autenticado' })
  @ApiNoContentResponse({ description: 'Cuenta eliminada' })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  remove(@Req() req: AuthenticatedRequest) {
    const userId = req.user?.sub;
    if (!userId) throw new UnauthorizedException('Token requerido');
    return this.privacy.removeAccount(userId, userId);
  }
}
