import {
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  FIREBASE_TOKEN_VERIFIER,
  type FirebaseTokenVerifier,
} from '../auth/firebase-token.verifier';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { ConsentDto } from './dto/consent.dto';

export const NOTICE_VERSION = '2';
@Injectable()
export class PrivacyService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    @Inject(FIREBASE_TOKEN_VERIFIER)
    private readonly verifier: FirebaseTokenVerifier,
  ) {}
  notice() {
    return {
      version: NOTICE_VERSION,
      date: '2026-11-16',
      sections: [
        {
          title: 'Cuenta',
          text: 'Se registran nombre, usuario, correo y consentimiento. Firebase Auth gestiona el acceso.',
        },
        {
          title: 'Registros',
          text: 'El servicio almacena sesiones, series, rutinas, comidas, medidas corporales y fotos proporcionadas. Las fotos se reencodan para retirar EXIF.',
        },
        {
          title: 'Acceso y eliminación',
          text: 'La API permite exportar los registros personales y solicitar la eliminación de la cuenta, sus archivos locales y su identidad de Firebase.',
        },
        {
          title: 'Salud',
          text: 'FitTrack360 registra información y no sustituye la atención médica ni nutricional.',
        },
      ],
    };
  }
  async consent(actor: string, target: string, dto: ConsentDto) {
    await this.owned(actor, target);
    if (dto.consent !== true || dto.version !== NOTICE_VERSION)
      throw new NotFoundException('Versión de aviso no encontrada');
    const user = await this.prisma.user.update({
      where: { id: actor },
      data: {
        privacyConsentAt: new Date(),
        privacyNoticeVersion: NOTICE_VERSION,
      },
      select: { privacyConsentAt: true, privacyNoticeVersion: true },
    });
    return user;
  }
  async exportData(actor: string, target: string) {
    await this.owned(actor, target);
    const user = await this.prisma.user.findUnique({
      where: { id: actor },
      select: {
        id: true,
        email: true,
        username: true,
        displayName: true,
        privacyConsentAt: true,
        privacyNoticeVersion: true,
        createdAt: true,
        updatedAt: true,
        settings: true,
        workoutSessions: {
          include: { sets: { orderBy: { order: 'asc' } } },
          orderBy: { startedAt: 'asc' },
        },
        routines: {
          include: { exercises: { orderBy: { position: 'asc' } } },
          orderBy: { createdAt: 'asc' },
        },
        mealLogs: { include: { items: true }, orderBy: { eatenAt: 'asc' } },
        bodyMetrics: { orderBy: { measuredAt: 'asc' } },
        photos: {
          select: {
            id: true,
            mimeType: true,
            sizeBytes: true,
            width: true,
            height: true,
            mealId: true,
            metricId: true,
            createdAt: true,
          },
        },
      },
    });
    if (!user) throw new NotFoundException('Usuario no encontrado');
    return { exportedAt: new Date().toISOString(), data: user };
  }
  async removeAccount(actor: string, target: string) {
    const user = await this.owned(actor, target);
    if (user.firebaseUid && !this.verifier.deleteUser)
      throw new ServiceUnavailableException(
        'El servicio de identidad no permite eliminar la cuenta',
      );
    const files = await this.storage.stageUserRemoval(actor);
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.user.delete({ where: { id: actor } });
        if (user.firebaseUid) await this.verifier.deleteUser!(user.firebaseUid);
      });
    } catch (error) {
      await files.rollback();
      throw error;
    }
    await files.commit();
  }
  private async owned(actor: string, target: string) {
    if (actor !== target) throw new NotFoundException('Usuario no encontrado');
    const user = await this.prisma.user.findUnique({
      where: { id: actor },
      select: { id: true, firebaseUid: true },
    });
    if (!user) throw new NotFoundException('Usuario no encontrado');
    return user;
  }
}
