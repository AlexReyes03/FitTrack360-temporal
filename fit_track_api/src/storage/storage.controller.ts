import {
  BadRequestException,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Req,
  Res,
  StreamableFile,
  UnauthorizedException,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiConsumes,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { Response } from 'express';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
import { StoredFileDto } from './dto/stored-file.dto';
import { StorageService } from './storage.service';

const MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024;

@ApiTags('storage')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('storage/files')
export class StorageController {
  constructor(private readonly storage: StorageService) {}

  @Post()
  @ApiOperation({ summary: 'Sube un archivo del usuario autenticado' })
  @ApiConsumes('multipart/form-data')
  @ApiOkResponse({ type: StoredFileDto })
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: MAX_FILE_SIZE_BYTES } }),
  )
  upload(
    @Req() request: AuthenticatedRequest,
    @UploadedFile() file?: Express.Multer.File,
  ): Promise<StoredFileDto> {
    if (!file) {
      throw new BadRequestException('Archivo requerido');
    }
    return this.storage.save(this.userId(request), file);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Descarga un archivo del usuario autenticado' })
  async download(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
    @Res({ passthrough: true }) response: Response,
  ): Promise<StreamableFile> {
    const result = await this.storage.read(this.userId(request), id);
    response.set({
      'Content-Type': result.metadata.mimeType,
      'Content-Disposition': `inline; filename*=UTF-8''${encodeURIComponent(
        result.metadata.originalName,
      )}`,
    });
    return new StreamableFile(result.stream);
  }

  @Delete(':id')
  @HttpCode(204)
  @ApiOperation({ summary: 'Borra un archivo del usuario autenticado' })
  async remove(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    await this.storage.remove(this.userId(request), id);
  }

  private userId(request: AuthenticatedRequest): string {
    const userId = request.user?.sub;
    if (!userId) {
      throw new UnauthorizedException('Token requerido');
    }
    return userId;
  }
}
