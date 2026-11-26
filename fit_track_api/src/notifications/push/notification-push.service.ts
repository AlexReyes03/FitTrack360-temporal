import { Inject, Injectable, Logger } from '@nestjs/common';
import { NotificationType, type Notification } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { DeviceTokensService } from '../device-tokens.service';
import {
  INVALID_TOKEN_ERROR_CODES,
  PUSH_MESSAGING_CLIENT,
  type PushMessagingClient,
  type PushSendResult,
} from './push-messaging.client';

export interface PushNotificationEvent {
  userId: string;
  notificationId: string;
  type: NotificationType;
  title: string;
  body: string;
  targetRoute?: string | null;
}

export type PushDispatchStatus =
  /** Al menos un token acepto el mensaje. */
  | 'sent'
  /** Gate de `notificationsEnabled` cerrado. */
  | 'skipped_preferences'
  | 'skipped_no_tokens'
  /** Todos los tokens fallaron o el cliente lanzo / no esta configurado. */
  | 'failed';

export interface PushDispatchResult {
  status: PushDispatchStatus;
  sent: number;
  failed: number;
  removedInvalidTokens: number;
}

/** Alertas de seguridad: se envian aunque el usuario haya apagado las notificaciones. */
const SECURITY_TYPES: ReadonlySet<NotificationType> = new Set([
  NotificationType.NEW_LOGIN,
  NotificationType.PASSWORD_CHANGED,
]);

const EMPTY_RESULT: Omit<PushDispatchResult, 'status'> = {
  sent: 0,
  failed: 0,
  removedInvalidTokens: 0,
};

/** Solo expone un codigo estable: el mensaje del SDK puede incluir tokens. */
function safeErrorCode(error: unknown): string {
  if (error instanceof Error) {
    const { code } = error as Error & { code?: unknown };
    return typeof code === 'string' ? code : error.constructor.name;
  }
  return 'unknown';
}

@Injectable()
export class NotificationPushService {
  private readonly logger = new Logger(NotificationPushService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly deviceTokens: DeviceTokensService,
    @Inject(PUSH_MESSAGING_CLIENT)
    private readonly client: PushMessagingClient,
  ) {}

  /** Envia el push a los dispositivos del usuario. Nunca rechaza. */
  async dispatch(event: PushNotificationEvent): Promise<PushDispatchResult> {
    try {
      return await this.run(event);
    } catch (error) {
      this.logger.warn('Push no enviado', {
        userId: event.userId,
        notificationId: event.notificationId,
        code: safeErrorCode(error),
      });
      return { status: 'failed', ...EMPTY_RESULT };
    }
  }

  /** Atajo para disparadores que acaban de crear la fila `Notification`. */
  dispatchNotification(
    notification: Pick<
      Notification,
      'id' | 'userId' | 'type' | 'title' | 'body' | 'targetRoute'
    >,
  ): Promise<PushDispatchResult> {
    return this.dispatch({
      userId: notification.userId,
      notificationId: notification.id,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      targetRoute: notification.targetRoute,
    });
  }

  private async run(event: PushNotificationEvent): Promise<PushDispatchResult> {
    if (!(await this.isAllowedByPreferences(event))) {
      return { status: 'skipped_preferences', ...EMPTY_RESULT };
    }

    const rows = await this.prisma.deviceToken.findMany({
      where: { userId: event.userId },
      select: { token: true },
    });
    if (rows.length === 0) {
      return { status: 'skipped_no_tokens', ...EMPTY_RESULT };
    }

    let results: PushSendResult[];
    try {
      results = await this.client.send({
        tokens: rows.map((row) => row.token),
        title: event.title,
        body: event.body,
        data: this.buildData(event),
      });
    } catch (error) {
      this.logger.warn('Push no enviado', {
        userId: event.userId,
        notificationId: event.notificationId,
        code: safeErrorCode(error),
      });
      return { status: 'failed', ...EMPTY_RESULT };
    }

    const removedInvalidTokens = await this.removeInvalidTokens(
      event.userId,
      results,
    );
    const sent = results.filter((result) => result.ok).length;
    const failed = results.length - sent;

    this.logger.debug(
      `Push procesado notificationId=${event.notificationId} sent=${sent} failed=${failed} removed=${removedInvalidTokens}`,
    );

    return {
      status: sent > 0 ? 'sent' : 'failed',
      sent,
      failed,
      removedInvalidTokens,
    };
  }

  private async isAllowedByPreferences(
    event: PushNotificationEvent,
  ): Promise<boolean> {
    if (SECURITY_TYPES.has(event.type)) return true;

    const settings = await this.prisma.userSettings.findUnique({
      where: { userId: event.userId },
      select: { notificationsEnabled: true },
    });
    return settings?.notificationsEnabled === true;
  }

  private buildData(event: PushNotificationEvent): Record<string, string> {
    const data: Record<string, string> = {
      notificationId: event.notificationId,
      type: event.type,
    };
    if (event.targetRoute) {
      data.targetRoute = event.targetRoute;
    }
    return data;
  }

  private async removeInvalidTokens(
    userId: string,
    results: PushSendResult[],
  ): Promise<number> {
    let removed = 0;
    for (const result of results) {
      if (
        result.ok ||
        !result.errorCode ||
        !INVALID_TOKEN_ERROR_CODES.has(result.errorCode)
      ) {
        continue;
      }
      try {
        await this.deviceTokens.revokeByToken(userId, result.token);
        removed += 1;
      } catch (error) {
        this.logger.warn('Token FCM invalido no se pudo borrar', {
          userId,
          code: safeErrorCode(error),
        });
      }
    }
    return removed;
  }
}
