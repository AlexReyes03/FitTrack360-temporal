import {
  Body,
  Controller,
  Headers,
  HttpCode,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { AuthUserDto } from './dto/auth-response.dto';
import { RegisterDto } from './dto/register.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @HttpCode(201)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Sincroniza un usuario nuevo de Firebase Auth con PostgreSQL (Bearer = ID token)',
  })
  @ApiOkResponse({ type: AuthUserDto })
  register(
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: RegisterDto,
  ): Promise<AuthUserDto> {
    return this.authService.register(this.extractBearer(authorization), dto);
  }

  @Post('session')
  @HttpCode(200)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Resuelve el User de PostgreSQL tras login Firebase (Bearer = ID token)',
  })
  @ApiOkResponse({ type: AuthUserDto })
  session(
    @Headers('authorization') authorization: string | undefined,
  ): Promise<AuthUserDto> {
    return this.authService.session(this.extractBearer(authorization));
  }

  @Post('logout')
  @HttpCode(204)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Revoca refresh tokens de Firebase para el UID del Bearer',
  })
  @ApiNoContentResponse()
  logout(
    @Headers('authorization') authorization: string | undefined,
  ): Promise<void> {
    return this.authService.logout(this.extractBearer(authorization));
  }

  private extractBearer(authorization: string | undefined): string {
    if (!authorization?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Token requerido');
    }
    return authorization.slice('Bearer '.length);
  }
}
