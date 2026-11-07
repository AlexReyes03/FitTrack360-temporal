import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

/** Prefijo de versión que comparten todos los controllers de negocio. */
export const API_PREFIX = 'api/v1';

/** Ruta pública de la UI de Swagger; queda fuera de API_PREFIX. */
export const API_DOCS_PATH = 'api/docs';

/**
 * Configuración HTTP común del API. La usan main.ts y las pruebas, para que lo
 * que se prueba sea exactamente lo que arranca en producción.
 */
export function configureApp(app: INestApplication): void {
  app.enableCors();

  app.setGlobalPrefix(API_PREFIX, { exclude: [API_DOCS_PATH] });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  const config = new DocumentBuilder()
    .setTitle('FitTrack360 API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup(API_DOCS_PATH, app, document);
}
