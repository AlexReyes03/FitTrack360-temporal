import {
  ConflictException,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../src/prisma/prisma.service';
import { AuthService } from '../../src/auth/auth.service';
import { RegisterDto } from '../../src/auth/dto/register.dto';
import {
  FIREBASE_TOKEN_VERIFIER,
  MockFirebaseTokenVerifier,
  type FirebaseTokenVerifier,
} from '../../src/auth/firebase-token.verifier';

const anaRegistration: RegisterDto = {
  username: 'ana',
  displayName: 'Ana',
  privacyConsent: true,
  privacyNoticeVersion: '1',
};

const ANA_TOKEN = 'mock:firebase-ana:ana@test.com';
const BETO_TOKEN = 'mock:firebase-beto:beto@test.com';

interface StoredAccount {
  id: string;
  firebaseUid: string | null;
  email: string;
  username: string;
  displayName: string;
  privacyConsentAt: Date;
  privacyNoticeVersion: string;
}

function createInMemoryStore() {
  const accounts: StoredAccount[] = [];

  return {
    accounts,
    user: {
      findUnique: ({
        where,
      }: {
        where: {
          email?: string;
          username?: string;
          firebaseUid?: string;
        };
      }) =>
        Promise.resolve(
          accounts.find(
            (account) =>
              (where.email !== undefined && account.email === where.email) ||
              (where.username !== undefined &&
                account.username === where.username) ||
              (where.firebaseUid !== undefined &&
                account.firebaseUid === where.firebaseUid),
          ) ?? null,
        ),
      create: ({ data }: { data: Omit<StoredAccount, 'id'> }) => {
        const account = { id: `user-${accounts.length + 1}`, ...data };
        accounts.push(account);
        return Promise.resolve(account);
      },
    },
    /** Sustituye create para simular carrera de unicidad Prisma. */
    failCreateWithP2002() {
      this.user.create = () =>
        Promise.reject(
          new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
            code: 'P2002',
            clientVersion: 'test',
            meta: { target: ['email'] },
          }),
        );
    },
  };
}

describe('AuthService (Firebase Auth)', () => {
  let service: AuthService;
  let store: ReturnType<typeof createInMemoryStore>;

  beforeEach(async () => {
    store = createInMemoryStore();

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: store },
        {
          provide: FIREBASE_TOKEN_VERIFIER,
          useValue: new MockFirebaseTokenVerifier(),
        },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  describe('registro sincronizado', () => {
    it('rechaza con conflicto un correo que ya pertenece a otra cuenta', async () => {
      await service.register(ANA_TOKEN, anaRegistration);

      await expect(
        service.register(ANA_TOKEN, {
          ...anaRegistration,
          username: 'otra',
        }),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(store.accounts).toHaveLength(1);
    });

    it('rechaza con conflicto un usuario que ya pertenece a otra cuenta', async () => {
      await service.register(ANA_TOKEN, anaRegistration);

      await expect(
        service.register(BETO_TOKEN, anaRegistration),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(store.accounts).toHaveLength(1);
    });

    it('guarda firebaseUid, consentimiento y no emite JWT propios', async () => {
      const profile = await service.register(ANA_TOKEN, anaRegistration);

      const [account] = store.accounts;
      expect(account.firebaseUid).toBe('firebase-ana');
      expect(account.email).toBe('ana@test.com');
      expect(account.privacyConsentAt).toBeInstanceOf(Date);
      expect(account.privacyNoticeVersion).toBe(
        anaRegistration.privacyNoticeVersion,
      );
      expect(profile).toMatchObject({
        id: account.id,
        firebaseUid: 'firebase-ana',
        email: 'ana@test.com',
        username: 'ana',
      });
      expect(profile).not.toHaveProperty('accessToken');
      expect(profile).not.toHaveProperty('passwordHash');
    });

    it('rechaza un Bearer invalido', async () => {
      await expect(
        service.register('no-es-mock', anaRegistration),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('mapea P2002 de create a ConflictException (409)', async () => {
      store.failCreateWithP2002();

      await expect(
        service.register(ANA_TOKEN, anaRegistration),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(store.accounts).toHaveLength(0);
    });
  });

  describe('session', () => {
    beforeEach(async () => {
      await service.register(ANA_TOKEN, anaRegistration);
    });

    it('resuelve el User existente por firebaseUid', async () => {
      const profile = await service.session(ANA_TOKEN);
      expect(profile.username).toBe('ana');
      expect(profile.firebaseUid).toBe('firebase-ana');
    });

    it('rechaza si Firebase existe pero no hay User en Postgres', async () => {
      await expect(service.session(BETO_TOKEN)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });

  describe('disponibilidad Firebase', () => {
    it('repropaga ServiceUnavailableException sin enmascarar como 401', async () => {
      const unavailableVerifier: FirebaseTokenVerifier = {
        verifyIdToken: async () => {
          throw new ServiceUnavailableException(
            'Firebase Admin no configurado',
          );
        },
      };

      const moduleRef = await Test.createTestingModule({
        providers: [
          AuthService,
          { provide: PrismaService, useValue: store },
          { provide: FIREBASE_TOKEN_VERIFIER, useValue: unavailableVerifier },
        ],
      }).compile();

      const auth = moduleRef.get(AuthService);
      await expect(auth.session(ANA_TOKEN)).rejects.toBeInstanceOf(
        ServiceUnavailableException,
      );
    });
  });
});
