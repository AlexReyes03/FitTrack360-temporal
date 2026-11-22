import { INestApplication, ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { buildCorsOptions } from './gateway/cors.config';
import { requestIdMiddleware } from './gateway/request-id.middleware';
import { createRequestTimeoutMiddleware } from './gateway/request-timeout.middleware';

export const API_PREFIX = 'api/v1';
export const API_DOCS_PATH = 'api/docs';
export const JSON_BODY_LIMIT = '1mb';
export const APP_HTTP_OPTIONS = { bodyParser: false as const };

export function configureApp(app: INestApplication): void {
  const httpApp = app as NestExpressApplication;

  httpApp.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", 'data:', 'validator.swagger.io'],
          scriptSrc: ["'self'", "'unsafe-inline'", 'https:'],
        },
      },
    }),
  );

  httpApp.use(requestIdMiddleware);
  httpApp.use(createRequestTimeoutMiddleware());

  httpApp.useBodyParser('json', { limit: JSON_BODY_LIMIT });
  httpApp.useBodyParser('urlencoded', {
    extended: true,
    limit: JSON_BODY_LIMIT,
  });

  httpApp.enableCors(buildCorsOptions());

  httpApp.setGlobalPrefix(API_PREFIX, { exclude: [API_DOCS_PATH] });

  httpApp.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  httpApp.useGlobalFilters(new HttpExceptionFilter());

  const config = new DocumentBuilder()
    .setTitle('FitTrack360 API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(httpApp, config);
  SwaggerModule.setup(API_DOCS_PATH, httpApp, document);
}
