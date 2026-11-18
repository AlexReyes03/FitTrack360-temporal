import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { FirebaseAdminTokenVerifier } from './firebase-admin.verifier';
import { FirebaseAuthGuard } from './firebase-auth.guard';
import {
  FIREBASE_TOKEN_VERIFIER,
  MockFirebaseTokenVerifier,
  type FirebaseTokenVerifier,
} from './firebase-token.verifier';

function createTokenVerifier(config: ConfigService): FirebaseTokenVerifier {
  const mode = (
    config.get<string>('FIREBASE_AUTH_MODE') ?? 'admin'
  ).toLowerCase();
  if (mode === 'mock') {
    return new MockFirebaseTokenVerifier();
  }
  return new FirebaseAdminTokenVerifier(config);
}

@Module({
  imports: [ConfigModule, PrismaModule],
  controllers: [AuthController],
  providers: [
    AuthService,
    FirebaseAuthGuard,
    {
      provide: FIREBASE_TOKEN_VERIFIER,
      inject: [ConfigService],
      useFactory: createTokenVerifier,
    },
  ],
  // JwtAuthGuard es alias de FirebaseAuthGuard (misma clase).
  exports: [FirebaseAuthGuard, FIREBASE_TOKEN_VERIFIER],
})
export class AuthModule {}
