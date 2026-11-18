import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
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
  ApiBody,
  ApiConsumes,
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiParam,
  ApiProduces,
  ApiTags,
  ApiUnauthorizedResponse,
  ApiBadRequestResponse,
} from '@nestjs/swagger';
import type { Response } from 'express';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
import { PhotoResponseDto } from './dto/photo-response.dto';
import { PhotoUploadDto } from './dto/photo-upload.dto';
import { PhotosService } from './photos.service';

@ApiTags('photos')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('photos')
export class PhotosController {
  constructor(private readonly photos: PhotosService) {}

  private user(req: AuthenticatedRequest) {
    if (!req.user?.sub) throw new UnauthorizedException('Token requerido');
    return req.user.sub;
  }

  @Post()
  @ApiOperation({
    summary:
      'Sube una foto reencodada sin EXIF, opcionalmente ligada a meal o métrica',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: {
        file: { type: 'string', format: 'binary' },
        mealId: { type: 'string', format: 'uuid' },
        metricId: { type: 'string', format: 'uuid' },
      },
    },
  })
  @ApiCreatedResponse({ type: PhotoResponseDto })
  @ApiBadRequestResponse({
    description: 'Archivo inválido o mealId+metricId a la vez (400)',
  })
  @ApiNotFoundResponse({
    description: 'Comida o métrica ajena/inexistente (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }),
  )
  upload(
    @Req() req: AuthenticatedRequest,
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: PhotoUploadDto,
  ): Promise<PhotoResponseDto> {
    return this.photos.upload(this.user(req), file, dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Descarga el binario de una foto propia' })
  @ApiParam({ name: 'id' })
  @ApiProduces('image/jpeg', 'image/png', 'image/webp')
  @ApiOkResponse({
    description: 'Contenido binario de la imagen',
    schema: { type: 'string', format: 'binary' },
  })
  @ApiNotFoundResponse({
    description: 'Foto no encontrada o ajena (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  async download(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StreamableFile> {
    const file = await this.photos.download(this.user(req), id);
    res.set({
      'Content-Type': file.metadata.mimeType,
      'Content-Disposition': 'inline',
    });
    return new StreamableFile(file.stream);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Elimina una foto propia' })
  @ApiParam({ name: 'id' })
  @ApiNoContentResponse({ description: 'Foto eliminada' })
  @ApiNotFoundResponse({
    description: 'Foto no encontrada o ajena (Regla S4: 404)',
  })
  @ApiUnauthorizedResponse({ description: 'Token ausente o inválido (401)' })
  remove(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    return this.photos.remove(this.user(req), id);
  }
}
