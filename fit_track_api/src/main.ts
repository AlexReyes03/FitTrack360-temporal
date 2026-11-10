import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { configureApp } from './app.setup';
import { resolveApiPort } from './config/port';

async function bootstrap(): Promise<void> {
  const port = resolveApiPort(process.env.PORT);
  const app = await NestFactory.create(AppModule);
  configureApp(app);
  await app.listen(port);
}

void bootstrap();
