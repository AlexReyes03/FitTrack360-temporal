import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import {
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { AuthResponseDto } from './dto/auth-response.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { LoginDto } from './dto/login.dto';
import { LogoutDto } from './dto/logout.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterDto } from './dto/register.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @HttpCode(201)
  @ApiOperation({ summary: 'Registra un usuario y emite tokens' })
  @ApiOkResponse({ type: AuthResponseDto })
  register(@Body() dto: RegisterDto): Promise<AuthResponseDto> {
    return this.authService.register(dto);
  }

  @Post('login')
  @HttpCode(200)
  @ApiOperation({ summary: 'Inicia sesion y emite tokens' })
  @ApiOkResponse({ type: AuthResponseDto })
  login(@Body() dto: LoginDto): Promise<AuthResponseDto> {
    return this.authService.login(dto);
  }

  @Post('refresh')
  @HttpCode(200)
  @ApiOperation({ summary: 'Rota el refresh token y emite un par nuevo' })
  @ApiOkResponse({ type: AuthResponseDto })
  refresh(@Body() dto: RefreshDto): Promise<AuthResponseDto> {
    return this.authService.refresh(dto);
  }

  @Post('logout')
  @HttpCode(204)
  @ApiOperation({ summary: 'Revoca el refresh token recibido' })
  @ApiNoContentResponse()
  logout(@Body() dto: LogoutDto): Promise<void> {
    return this.authService.logout(dto);
  }

  @Post('password/forgot')
  @HttpCode(200)
  @ApiOperation({ summary: 'Solicita un codigo de recuperacion por correo' })
  @ApiOkResponse({
    description: 'Respuesta uniforme aunque el correo no exista',
  })
  forgotPassword(@Body() dto: ForgotPasswordDto): Promise<{ message: string }> {
    return this.authService.forgotPassword(dto);
  }

  @Post('password/reset')
  @HttpCode(200)
  @ApiOperation({ summary: 'Restablece la contraseña con un codigo vigente' })
  @ApiOkResponse({ description: 'contraseña actualizada' })
  resetPassword(@Body() dto: ResetPasswordDto): Promise<{ message: string }> {
    return this.authService.resetPassword(dto);
  }
}
