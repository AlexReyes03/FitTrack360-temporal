import {
  Body,
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
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
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
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }),
  )
  upload(
    @Req() req: AuthenticatedRequest,
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: PhotoUploadDto,
  ) {
    return this.photos.upload(this.user(req), file, dto);
  }
  @Get(':id') async download(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    const file = await this.photos.download(this.user(req), id);
    res.set({
      'Content-Type': file.metadata.mimeType,
      'Content-Disposition': 'inline',
    });
    return new StreamableFile(file.stream);
  }
  @Delete(':id') @HttpCode(204) remove(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ) {
    return this.photos.remove(this.user(req), id);
  }
}
