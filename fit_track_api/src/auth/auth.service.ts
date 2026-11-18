import {
  ConflictException,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUserDto } from './dto/auth-response.dto';
import { RegisterDto } from './dto/register.dto';
import {
  FIREBASE_TOKEN_VERIFIER,
  type FirebaseTokenVerifier,
  type VerifiedFirebaseToken,
} from './firebase-token.verifier';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(FIREBASE_TOKEN_VERIFIER)
    private readonly verifier: FirebaseTokenVerifier,
  ) {}

  /** Crea el User de Postgres ligado al UID del ID token. */
  async register(idToken: string, dto: RegisterDto): Promise<AuthUserDto> {
    const verified = await this.verify(idToken);

    const byUid = await this.prisma.user.findUnique({
      where: { firebaseUid: verified.uid },
    });
    if (byUid) {
      throw new ConflictException('La cuenta Firebase ya esta registrada');
    }

    const byEmail = await this.prisma.user.findUnique({
      where: { email: verified.email },
    });
    if (byEmail) {
      throw new ConflictException('El correo ya esta registrado');
    }

    const byUsername = await this.prisma.user.findUnique({
      where: { username: dto.username },
    });
    if (byUsername) {
      throw new ConflictException('El usuario ya esta registrado');
    }

    const user = await this.prisma.user.create({
      data: {
        firebaseUid: verified.uid,
        email: verified.email,
        username: dto.username,
        displayName: dto.displayName,
        privacyConsentAt: new Date(),
        privacyNoticeVersion: dto.privacyNoticeVersion,
      },
    });

    return this.toDto(user);
  }

  /** Resuelve el User existente por firebaseUid (post-login Firebase). */
  async session(idToken: string): Promise<AuthUserDto> {
    const verified = await this.verify(idToken);
    const user = await this.prisma.user.findUnique({
      where: { firebaseUid: verified.uid },
    });
    if (!user) {
      throw new UnauthorizedException('Usuario no sincronizado');
    }
    return this.toDto(user);
  }

  /** Revoca refresh tokens de Firebase para el UID del Bearer. */
  async logout(idToken: string): Promise<void> {
    const verified = await this.verify(idToken);
    if (this.verifier.revokeRefreshTokens) {
      await this.verifier.revokeRefreshTokens(verified.uid);
    }
  }

  private async verify(idToken: string): Promise<VerifiedFirebaseToken> {
    try {
      return await this.verifier.verifyIdToken(idToken);
    } catch {
      throw new UnauthorizedException('Token invalido');
    }
  }

  private toDto(user: {
    id: string;
    email: string;
    username: string;
    displayName: string;
    firebaseUid: string | null;
  }): AuthUserDto {
    if (!user.firebaseUid) {
      throw new UnauthorizedException('Usuario sin firebaseUid');
    }
    return {
      id: user.id,
      email: user.email,
      username: user.username,
      displayName: user.displayName,
      firebaseUid: user.firebaseUid,
    };
  }
}
