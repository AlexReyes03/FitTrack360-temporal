import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import { verify } from '@node-rs/argon2';
import { createHash } from 'node:crypto';
import { MailService } from '../../src/mail/mail.service';
import { PrismaService } from '../../src/prisma/prisma.service';
import { AuthService } from '../../src/auth/auth.service';
import { LoginDto } from '../../src/auth/dto/login.dto';
import { RegisterDto } from '../../src/auth/dto/register.dto';

const PASSWORD = 'Prueba12345';
const WRONG_PASSWORD = 'NoEsLaClave99';

const anaRegistration: RegisterDto = {
  username: 'ana',
  email: 'ana@test.com',
  password: PASSWORD,
  displayName: 'Ana',
  privacyConsent: true,
  privacyNoticeVersion: '1',
};
const anaCredentials: LoginDto = {
  email: anaRegistration.email,
  password: PASSWORD,
};

interface StoredAccount {
  id: string;
  email: string;
  username: string;
  passwordHash: string;
  privacyConsentAt: Date;
  privacyNoticeVersion: string;
}

interface StoredRefreshToken {
  userId: string;
  tokenHash: string;
}

/** Almacen en memoria que sustituye a Postgres; no requiere base de datos. */
function createInMemoryStore() {
  const accounts: StoredAccount[] = [];
  const refreshTokens: StoredRefreshToken[] = [];

  return {
    accounts,
    refreshTokens,
    user: {
      findUnique: ({
        where,
      }: {
        where: { email?: string; username?: string };
      }) =>
        Promise.resolve(
          accounts.find(
            (account) =>
              account.email === where.email ||
              account.username === where.username,
          ) ?? null,
        ),
      create: ({ data }: { data: Omit<StoredAccount, 'id'> }) => {
        const account = { id: `user-${accounts.length + 1}`, ...data };
        accounts.push(account);
        return Promise.resolve(account);
      },
    },
    refreshToken: {
      create: ({ data }: { data: StoredRefreshToken }) => {
        refreshTokens.push(data);
        return Promise.resolve(data);
      },
    },
  };
}

describe('AuthService', () => {
  let service: AuthService;
  let store: ReturnType<typeof createInMemoryStore>;

  beforeEach(async () => {
    store = createInMemoryStore();
    let issuedTokens = 0;

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: store },
        {
          provide: JwtService,
          useValue: {
            signAsync: () => Promise.resolve(`token-${++issuedTokens}`),
          },
        },
        {
          provide: ConfigService,
          useValue: {
            get: () => undefined,
            getOrThrow: () => 'secreto-de-prueba',
          },
        },
        { provide: MailService, useValue: {} },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  describe('registro de una cuenta', () => {
    it('rechaza con conflicto un correo que ya pertenece a otra cuenta', async () => {
      await service.register(anaRegistration);

      await expect(
        service.register({ ...anaRegistration, username: 'otra' }),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(store.accounts).toHaveLength(1);
    });

    it('rechaza con conflicto un usuario que ya pertenece a otra cuenta', async () => {
      await service.register(anaRegistration);

      await expect(
        service.register({ ...anaRegistration, email: 'otra@test.com' }),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(store.accounts).toHaveLength(1);
    });

    it('nunca guarda la contraseña en texto plano, sino un hash verificable', async () => {
      await service.register(anaRegistration);

      const [account] = store.accounts;
      expect(JSON.stringify(account)).not.toContain(PASSWORD);
      expect(await verify(account.passwordHash, PASSWORD)).toBe(true);
    });

    it('registra el consentimiento de privacidad y abre la sesion', async () => {
      const session = await service.register(anaRegistration);

      const [account] = store.accounts;
      expect(account.privacyConsentAt).toBeInstanceOf(Date);
      expect(account.privacyNoticeVersion).toBe(
        anaRegistration.privacyNoticeVersion,
      );
      expect(session.accessToken).toEqual(expect.any(String));
      expect(session.refreshToken).toEqual(expect.any(String));
      expect(session.expiresIn).toBe(900);
    });
  });

  describe('inicio de sesion', () => {
    beforeEach(async () => {
      await service.register(anaRegistration);
      store.refreshTokens.length = 0;
    });

    it('abre la sesion de una cuenta registrada con sus credenciales', async () => {
      const session = await service.login(anaCredentials);

      expect(session.accessToken).toEqual(expect.any(String));
      expect(store.refreshTokens).toHaveLength(1);
    });

    it('rechaza una contraseña incorrecta y no abre sesion', async () => {
      await expect(
        service.login({ ...anaCredentials, password: WRONG_PASSWORD }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(store.refreshTokens).toHaveLength(0);
    });

    it('no revela si el correo existe: responde igual que con contraseña incorrecta', async () => {
      const wrongPassword = await service
        .login({ ...anaCredentials, password: WRONG_PASSWORD })
        .catch((error: UnauthorizedException) => error);
      const unknownEmail = await service
        .login({ ...anaCredentials, email: 'nadie@test.com' })
        .catch((error: UnauthorizedException) => error);

      expect(unknownEmail).toBeInstanceOf(UnauthorizedException);
      expect((unknownEmail as UnauthorizedException).message).toBe(
        (wrongPassword as UnauthorizedException).message,
      );
      expect(store.refreshTokens).toHaveLength(0);
    });

    it('guarda solo el hash del refresh token, ligado a la cuenta', async () => {
      const session = await service.login(anaCredentials);

      const [stored] = store.refreshTokens;
      expect(stored.userId).toBe(store.accounts[0].id);
      expect(stored.tokenHash).toBe(
        createHash('sha256').update(session.refreshToken).digest('hex'),
      );
    });
  });
});
