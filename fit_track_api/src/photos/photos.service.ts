import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import sharp from 'sharp';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { PhotoUploadDto } from './dto/photo-upload.dto';

const formats = {
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
} as const;
@Injectable()
export class PhotosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}
  async upload(
    userId: string,
    file: Express.Multer.File | undefined,
    dto: PhotoUploadDto,
  ) {
    if (!file || !file.buffer?.length)
      throw new BadRequestException('Archivo requerido');
    if (dto.mealId && dto.metricId)
      throw new BadRequestException('Indique comida o métrica, no ambas');
    if (
      dto.mealId &&
      !(await this.prisma.mealLog.findFirst({
        where: { id: dto.mealId, userId },
        select: { id: true },
      }))
    )
      throw new NotFoundException('Comida no encontrada');
    if (
      dto.metricId &&
      !(await this.prisma.bodyMetric.findFirst({
        where: { id: dto.metricId, userId },
        select: { id: true },
      }))
    )
      throw new NotFoundException('Métrica no encontrada');
    let result: { data: Buffer; info: sharp.OutputInfo };
    let mimeType: string;
    try {
      const input = sharp(file.buffer, {
        limitInputPixels: 40000000,
        failOn: 'error',
      });
      const metadata = await input.metadata();
      const format = metadata.format;
      if (format !== 'jpeg' && format !== 'png' && format !== 'webp')
        throw new Error('formato');
      mimeType = formats[format];
      if (file.mimetype !== mimeType) throw new Error('mime');
      result = await input
        .rotate()
        .toFormat(format)
        .toBuffer({ resolveWithObject: true });
    } catch {
      throw new BadRequestException('Imagen inválida o formato no admitido');
    }
    const stored = await this.storage.save(userId, {
      ...file,
      originalname: `foto.${result.info.format === 'jpeg' ? 'jpg' : result.info.format}`,
      mimetype: mimeType,
      size: result.data.length,
      buffer: result.data,
    });
    try {
      const photo = await this.prisma.photo.create({
        data: {
          userId,
          storageKey: stored.id,
          mimeType,
          sizeBytes: result.data.length,
          width: result.info.width,
          height: result.info.height,
          mealId: dto.mealId,
          metricId: dto.metricId,
        },
      });
      return this.view(photo);
    } catch (error) {
      await this.storage.remove(userId, stored.id);
      throw error;
    }
  }
  async download(userId: string, id: string) {
    const photo = await this.owned(userId, id);
    return this.storage.read(userId, photo.storageKey);
  }
  async remove(userId: string, id: string) {
    const photo = await this.owned(userId, id);
    await this.storage.remove(userId, photo.storageKey);
    await this.prisma.photo.delete({ where: { id } });
  }
  private async owned(userId: string, id: string) {
    const photo = await this.prisma.photo.findFirst({ where: { id, userId } });
    if (!photo) throw new NotFoundException('Foto no encontrada');
    return photo;
  }
  private view(photo: {
    id: string;
    mimeType: string;
    sizeBytes: number;
    width: number;
    height: number;
    mealId: string | null;
    metricId: string | null;
    createdAt: Date;
  }) {
    return {
      id: photo.id,
      mimeType: photo.mimeType,
      sizeBytes: photo.sizeBytes,
      width: photo.width,
      height: photo.height,
      mealId: photo.mealId,
      metricId: photo.metricId,
      createdAt: photo.createdAt,
    };
  }
}
