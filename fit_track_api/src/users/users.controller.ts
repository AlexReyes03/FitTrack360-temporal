import {
  Body,
  Controller,
  Get,
  Patch,
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
} from '@nestjs/swagger';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UserResponseDto } from './dto/user-response.dto';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Devuelve el perfil del usuario autenticado' })
  @ApiOkResponse({ type: UserResponseDto })
  me(@Req() request: AuthenticatedRequest): Promise<UserResponseDto> {
    const userId = request.user?.sub;
    if (!userId) {
      throw new UnauthorizedException('Token requerido');
    }
    return this.usersService.findMe(userId);
  }

  @Patch('me')
  @ApiOperation({
    summary:
      'Actualiza perfil, metas (calorías y macros) y preferencias del usuario autenticado',
  })
  @ApiOkResponse({ type: UserResponseDto })
  @ApiBadRequestResponse({
    description:
      'Meta no positiva, macro negativo, unidad inválida o campo no permitido',
  })
  updateMe(
    @Req() request: AuthenticatedRequest,
    @Body() dto: UpdateProfileDto,
  ): Promise<UserResponseDto> {
    const userId = request.user?.sub;
    if (!userId) {
      throw new UnauthorizedException('Token requerido');
    }
    return this.usersService.updateMe(userId, dto);
  }
}
