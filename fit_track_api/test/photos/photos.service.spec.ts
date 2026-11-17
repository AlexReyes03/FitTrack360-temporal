import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import sharp from 'sharp';
import { PhotosService } from '../../src/photos/photos.service';
import { PrismaService } from '../../src/prisma/prisma.service';
import { StorageService } from '../../src/storage/storage.service';

const userId = 'user-a';
function fakeFile(
  buffer: Buffer,
  mimetype = 'image/jpeg',
): Express.Multer.File {
  return {
    fieldname: 'file',
    originalname: 'foto.jpg',
    encoding: '7bit',
    mimetype,
    size: buffer.length,
    buffer,
    destination: '',
    filename: '',
    path: '',
    stream: undefined as never,
  };
}
describe('PhotosService', () => {
  let directory: string;
  let storage: StorageService;
  let service: PhotosService;
  let saved: Record<string, unknown> | null;
  beforeEach(async () => {
    directory = await mkdtemp(join(tmpdir(), 'fittrack-photo-test-'));
    storage = new StorageService(new ConfigService({ UPLOAD_DIR: directory }));
    saved = null;
    const db = {
      photo: {
        create: ({ data }: { data: Record<string, unknown> }) => {
          saved = {
            ...data,
            id: 'photo1',
            mealId: data.mealId ?? null,
            metricId: data.metricId ?? null,
            createdAt: new Date(),
          };
          return Promise.resolve(saved);
        },
        findFirst: ({ where }: { where: { id: string; userId: string } }) =>
          Promise.resolve(
            saved?.id === where.id && saved?.userId === where.userId
              ? saved
              : null,
          ),
        delete: () => {
          const old = saved;
          saved = null;
          return Promise.resolve(old);
        },
      },
      mealLog: {
        findFirst: ({ where }: { where: { userId: string } }) =>
          Promise.resolve(where.userId === userId ? { id: 'meal1' } : null),
      },
      bodyMetric: { findFirst: () => Promise.resolve(null) },
    };
    service = new PhotosService(db as unknown as PrismaService, storage);
  });
  afterEach(async () => {
    await rm(directory, { recursive: true, force: true });
  });
  it('reencoda la imagen, elimina EXIF y borra archivo y metadata', async () => {
    const input = await sharp({
      create: { width: 4, height: 3, channels: 3, background: '#ff0000' },
    })
      .jpeg()
      .withExif({
        IFD0: { Artist: 'private' },
        IFD3: {
          GPSLatitudeRef: 'N',
          GPSLatitude: '19/1 20/1 0/1',
          GPSLongitudeRef: 'W',
          GPSLongitude: '99/1 10/1 0/1',
        },
      })
      .toBuffer();
    expect((await sharp(input).metadata()).exif).toBeDefined();
    const result = await service.upload(userId, fakeFile(input), {
      mealId: 'meal1',
    });
    expect(result).toMatchObject({
      id: 'photo1',
      mimeType: 'image/jpeg',
      width: 4,
      height: 3,
      mealId: 'meal1',
    });
    const read = await service.download(userId, result.id);
    const chunks: Buffer[] = [];
    for await (const chunk of read.stream) chunks.push(Buffer.from(chunk));
    const metadata = await sharp(Buffer.concat(chunks)).metadata();
    expect(metadata.exif).toBeUndefined();
    const key = saved?.storageKey as string;
    await service.remove(userId, result.id);
    await expect(storage.read(userId, key)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(saved).toBeNull();
  });
  it('rechaza datos inválidos y el tipo MIME falso', async () => {
    await expect(
      service.upload(userId, fakeFile(Buffer.from('no es imagen')), {}),
    ).rejects.toBeInstanceOf(BadRequestException);
    const png = await sharp({
      create: { width: 1, height: 1, channels: 3, background: '#fff' },
    })
      .png()
      .toBuffer();
    await expect(
      service.upload(userId, fakeFile(png), {}),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
  it('devuelve 404 para foto o asociación de otro usuario', async () => {
    const image = await sharp({
      create: { width: 1, height: 1, channels: 3, background: '#fff' },
    })
      .jpeg()
      .toBuffer();
    await service.upload(userId, fakeFile(image), {});
    await expect(service.download('user-b', 'photo1')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(service.remove('user-b', 'photo1')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(
      service.upload('user-b', fakeFile(image), { mealId: 'meal1' }),
    ).rejects.toBeInstanceOf(NotFoundException);
    await expect(
      service.upload(userId, fakeFile(image), { metricId: 'other' }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
