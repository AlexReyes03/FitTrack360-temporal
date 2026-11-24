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
  ApiTags,
} from '@nestjs/swagger';
import {
  FirebaseAuthGuard,
  type AuthenticatedRequest,
} from '../auth/firebase-auth.guard';
import { DeviceTokensService } from './device-tokens.service';
import { DeviceTokenResponseDto } from './dto/device-token-response.dto';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { RevokeDeviceTokenDto } from './dto/revoke-device-token.dto';

@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(FirebaseAuthGuard)
@Controller('notifications/devices')
export class DeviceTokensController {
  constructor(private readonly deviceTokens: DeviceTokensService) {}

  private requireUserId(req: AuthenticatedRequest): string {
    if (!req.user?.sub) {
      throw new UnauthorizedException('Token requerido');
    }
    return req.user.sub;
  }

  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Registra, reasigna o rota un token FCM para el usuario autenticado',
  })
  @ApiOkResponse({ type: DeviceTokenResponseDto })
  register(
    @Req() req: AuthenticatedRequest,
    @Body() dto: RegisterDeviceTokenDto,
  ): Promise<DeviceTokenResponseDto> {
    return this.deviceTokens.register(this.requireUserId(req), dto);
  }

  @Post('revoke')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary:
      'Revoca un token FCM por valor en el cuerpo si pertenece al usuario autenticado',
  })
  @ApiNoContentResponse({
    description:
      'Operación idempotente: elimina el token si pertenece al actor sin revelar existencia.',
  })
  revokeByToken(
    @Req() req: AuthenticatedRequest,
    @Body() dto: RevokeDeviceTokenDto,
  ): Promise<void> {
    return this.deviceTokens.revokeByToken(this.requireUserId(req), dto.token);
  }

  @Get()
  @ApiOperation({
    summary: 'Lista los dispositivos push registrados del usuario autenticado',
  })
  @ApiOkResponse({ type: [DeviceTokenResponseDto] })
  findAll(@Req() req: AuthenticatedRequest): Promise<DeviceTokenResponseDto[]> {
    return this.deviceTokens.findAll(this.requireUserId(req));
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Obtiene un dispositivo registrado del usuario autenticado',
  })
  @ApiOkResponse({ type: DeviceTokenResponseDto })
  @ApiNotFoundResponse({
    description: 'Dispositivo no encontrado o perteneciente a otro usuario',
  })
  findOne(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<DeviceTokenResponseDto> {
    return this.deviceTokens.findOne(this.requireUserId(req), id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary: 'Revoca un dispositivo por id verificando propiedad del actor',
  })
  @ApiNoContentResponse({
    description: 'Dispositivo revocado correctamente.',
  })
  @ApiNotFoundResponse({
    description: 'Dispositivo no encontrado o perteneciente a otro usuario',
  })
  removeById(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    return this.deviceTokens.removeById(this.requireUserId(req), id);
  }
}
