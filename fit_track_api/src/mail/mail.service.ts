import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createTransport, Transporter } from 'nodemailer';

/**
 * Envio de correo por SMTP (Mailpit en local). Si SMTP_HOST no esta
 * configurado, el servicio no envia y no rompe el flujo de forgot.
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly transporter: Transporter | null;
  private readonly from: string;

  constructor(private readonly config: ConfigService) {
    this.from =
      this.config.get<string>('SMTP_FROM') ?? 'no-reply@fittrack360.local';
    const host = this.config.get<string>('SMTP_HOST');
    if (!host) {
      this.transporter = null;
      return;
    }

    const user = this.config.get<string>('SMTP_USER');
    this.transporter = createTransport({
      host,
      port: Number(this.config.get<string>('SMTP_PORT') ?? 1025),
      secure: this.config.get<string>('SMTP_SECURE') === 'true',
      auth: user
        ? { user, pass: this.config.get<string>('SMTP_PASS') ?? '' }
        : undefined,
    });
  }

  async sendPasswordResetCode(to: string, code: string): Promise<void> {
    if (!this.transporter) {
      this.logger.warn(
        'SMTP no configurado; no se envio el codigo de recuperacion',
      );
      return;
    }

    try {
      await this.transporter.sendMail({
        from: this.from,
        to,
        subject: 'Tu codigo de recuperacion de FitTrack360',
        text: `Tu codigo de recuperacion es ${code}. Expira en 15 minutos.`,
      });
    } catch {
      // No se registra el codigo ni datos del correo.
      this.logger.warn('No se pudo enviar el correo de recuperacion');
    }
  }
}
