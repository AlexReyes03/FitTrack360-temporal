import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
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
import { ConsentDto } from './dto/consent.dto';
import { PrivacyService } from './privacy.service';
@ApiTags('privacy')
@Controller('privacy')
export class PrivacyController {
  constructor(private readonly privacy: PrivacyService) {}
  private user(req: AuthenticatedRequest): string {
    if (!req.user?.sub) throw new UnauthorizedException('Token requerido');
    return req.user.sub;
  }
  @Get('notice') notice() {
    return this.privacy.notice();
  }
  @Post(':userId/consent') @ApiBearerAuth() @UseGuards(JwtAuthGuard) consent(
    @Req() req: AuthenticatedRequest,
    @Param('userId') userId: string,
    @Body() dto: ConsentDto,
  ) {
    return this.privacy.consent(this.user(req), userId, dto);
  }
  @Get(':userId/export') @ApiBearerAuth() @UseGuards(JwtAuthGuard) exportData(
    @Req() req: AuthenticatedRequest,
    @Param('userId') userId: string,
  ) {
    return this.privacy.exportData(this.user(req), userId);
  }
  @Delete(':userId')
  @HttpCode(204)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  remove(@Req() req: AuthenticatedRequest, @Param('userId') userId: string) {
    return this.privacy.removeAccount(this.user(req), userId);
  }
}

@ApiTags('privacy')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users/me')
export class MePrivacyController {
  constructor(private readonly privacy: PrivacyService) {}
  @Get('export') exportData(@Req() req: AuthenticatedRequest) {
    const userId = req.user?.sub;
    if (!userId) throw new UnauthorizedException('Token requerido');
    return this.privacy.exportData(userId, userId);
  }
  @Delete() @HttpCode(204) remove(@Req() req: AuthenticatedRequest) {
    const userId = req.user?.sub;
    if (!userId) throw new UnauthorizedException('Token requerido');
    return this.privacy.removeAccount(userId, userId);
  }
}
