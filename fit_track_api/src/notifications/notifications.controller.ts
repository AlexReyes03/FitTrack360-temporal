import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Query,
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
import { NotificationQueryDto } from './dto/notification-query.dto';
import {
  NotificationCountDto,
  NotificationPageDto,
  NotificationResponseDto,
} from './dto/notification-response.dto';
import { UpdateNotificationReadDto } from './dto/update-notification-read.dto';
import { NotificationsService } from './notifications.service';

@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(FirebaseAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  private userId(req: AuthenticatedRequest): string {
    if (!req.user?.sub) throw new UnauthorizedException('Token requerido');
    return req.user.sub;
  }

  @Get()
  @ApiOperation({ summary: 'Lista paginada de notificaciones propias' })
  @ApiOkResponse({ type: NotificationPageDto })
  findAll(
    @Req() req: AuthenticatedRequest,
    @Query() query: NotificationQueryDto,
  ) {
    return this.notifications.findAll(this.userId(req), query);
  }

  @Get('unread-count')
  @ApiOkResponse({ type: NotificationCountDto })
  unreadCount(@Req() req: AuthenticatedRequest) {
    return this.notifications.unreadCount(this.userId(req));
  }

  @Patch('read-all')
  @ApiOkResponse({ type: NotificationCountDto })
  readAll(@Req() req: AuthenticatedRequest) {
    return this.notifications.readAll(this.userId(req));
  }

  @Delete()
  @ApiOkResponse({ type: NotificationCountDto })
  removeAll(@Req() req: AuthenticatedRequest) {
    return this.notifications.removeAll(this.userId(req));
  }

  @Get(':id')
  @ApiOkResponse({ type: NotificationResponseDto })
  @ApiNotFoundResponse({ description: 'Notificación inexistente o ajena' })
  findOne(@Req() req: AuthenticatedRequest, @Param('id') id: string) {
    return this.notifications.findOne(this.userId(req), id);
  }

  @Patch(':id/read')
  @ApiOkResponse({ type: NotificationResponseDto })
  @ApiNotFoundResponse({ description: 'Notificación inexistente o ajena' })
  updateRead(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateNotificationReadDto,
  ) {
    return this.notifications.updateRead(this.userId(req), id, dto.isRead);
  }

  @Delete(':id')
  @HttpCode(204)
  @ApiNoContentResponse()
  @ApiNotFoundResponse({ description: 'Notificación inexistente o ajena' })
  remove(@Req() req: AuthenticatedRequest, @Param('id') id: string) {
    return this.notifications.remove(this.userId(req), id);
  }
}
