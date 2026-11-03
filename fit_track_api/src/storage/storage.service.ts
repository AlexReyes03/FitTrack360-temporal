import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createReadStream, type ReadStream } from 'node:fs';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';

interface FileMetadata {
  id: string;
  originalName: string;
  mimeType: string;
  size: number;
  extension: string;
}

export interface StoredFileView {
  id: string;
  originalName: string;
  mimeType: string;
  size: number;
}

export interface ReadFileResult {
  metadata: StoredFileView;
  stream: ReadStream;
}

const FILE_ID_PATTERN = /^[0-9a-f-]{36}$/;

function safeExtension(originalName: string): string {
  const extension = extname(originalName).toLowerCase();
  return /^\.[a-z0-9]{1,10}$/.test(extension) ? extension : '';
}

/**
 * Driver local de almacenamiento. Cada archivo vive bajo uploads/<userId>/,
 * de modo que un userId distinto al dueno no puede resolver la ruta y recibe
 * 404 sin filtrar la existencia del recurso.
 */
@Injectable()
export class StorageService {
  private readonly root: string;

  constructor(config: ConfigService) {
    this.root = resolve(
      config.get<string>('UPLOAD_DIR') ?? join(process.cwd(), 'uploads'),
    );
  }

  async save(
    userId: string,
    file: Express.Multer.File,
  ): Promise<StoredFileView> {
    const id = randomUUID();
    const extension = safeExtension(file.originalname);
    const directory = join(this.root, userId);
    await mkdir(directory, { recursive: true });

    const metadata: FileMetadata = {
      id,
      originalName: file.originalname,
      mimeType: file.mimetype || 'application/octet-stream',
      size: file.size,
      extension,
    };
    await writeFile(join(directory, `${id}${extension}`), file.buffer);
    await writeFile(
      join(directory, `${id}.meta.json`),
      JSON.stringify(metadata),
    );

    return this.toView(metadata);
  }

  async read(userId: string, fileId: string): Promise<ReadFileResult> {
    const metadata = await this.readMetadata(userId, fileId);
    return {
      metadata: this.toView(metadata),
      stream: createReadStream(
        join(this.root, userId, `${fileId}${metadata.extension}`),
      ),
    };
  }

  async remove(userId: string, fileId: string): Promise<void> {
    const metadata = await this.readMetadata(userId, fileId);
    const directory = join(this.root, userId);
    await rm(join(directory, `${fileId}${metadata.extension}`), {
      force: true,
    });
    await rm(join(directory, `${fileId}.meta.json`), { force: true });
  }

  private async readMetadata(
    userId: string,
    fileId: string,
  ): Promise<FileMetadata> {
    if (!FILE_ID_PATTERN.test(fileId)) {
      throw new NotFoundException('Archivo no encontrado');
    }

    try {
      const raw = await readFile(
        join(this.root, userId, `${fileId}.meta.json`),
        'utf8',
      );
      return JSON.parse(raw) as FileMetadata;
    } catch {
      throw new NotFoundException('Archivo no encontrado');
    }
  }

  private toView(metadata: FileMetadata): StoredFileView {
    return {
      id: metadata.id,
      originalName: metadata.originalName,
      mimeType: metadata.mimeType,
      size: metadata.size,
    };
  }
}
