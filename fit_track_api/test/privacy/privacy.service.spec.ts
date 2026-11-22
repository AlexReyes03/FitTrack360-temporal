import { NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { FirebaseTokenVerifier } from '../../src/auth/firebase-token.verifier';
import { RegisterDto } from '../../src/auth/dto/register.dto';
import { ConsentDto } from '../../src/privacy/dto/consent.dto';
import { PrivacyService } from '../../src/privacy/privacy.service';
import { PrismaService } from '../../src/prisma/prisma.service';
import { StorageService } from '../../src/storage/storage.service';

describe('Privacidad', () => {
  function setup(failIdentity = false, failDb = false) {
    const calls: string[] = [];
    const db = {
      user: {
        findUnique: ({ select }: { select: Record<string, unknown> }) =>
          Promise.resolve(
            select.firebaseUid
              ? { id: 'u1', firebaseUid: 'firebase1' }
              : {
                  id: 'u1',
                  email: 'u@example.test',
                  workoutSessions: [{ sets: [] }],
                  routines: [],
                  mealLogs: [],
                  photos: [],
                  bodyMetrics: [],
                },
          ),
        update: ({ data }: { data: unknown }) => {
          calls.push('consent');
          return Promise.resolve(data);
        },
        delete: () => {
          calls.push('delete-db');
          if (failDb) throw new Error('base de datos no disponible');
          return Promise.resolve({});
        },
      },
      $transaction: async (fn: (tx: unknown) => Promise<unknown>) => {
        const result = await fn(db);
        calls.push('transaction-commit');
        return result;
      },
    };
    const storage = {
      stageUserRemoval: () => {
        calls.push('stage');
        return Promise.resolve({
          commit: async () => {
            calls.push('files-commit');
          },
          rollback: async () => {
            calls.push('files-rollback');
          },
        });
      },
    };
    const verifier = {
      verifyIdToken: async () => ({
        uid: 'firebase1',
        email: 'u@example.test',
      }),
      deleteUser: async () => {
        calls.push('delete-identity');
        if (failIdentity) throw new Error('identidad no disponible');
      },
    };
    return {
      service: new PrivacyService(
        db as unknown as PrismaService,
        storage as unknown as StorageService,
        verifier as FirebaseTokenVerifier,
      ),
      calls,
    };
  }
  it('publica la versión actual sin marcadores y la exige al registrarse', async () => {
    const { service } = setup();
    expect(service.notice().version).toBe('2');
    expect(JSON.stringify(service.notice())).not.toMatch(/\[[A-ZÁÉÍÓÚ ]+\]/);
    const register = plainToInstance(RegisterDto, {
      username: 'ana',
      displayName: 'Ana',
      privacyConsent: true,
      privacyNoticeVersion: '1',
    });
    expect(await validate(register)).not.toHaveLength(0);
    register.privacyNoticeVersion = '2';
    expect(await validate(register)).toHaveLength(0);
  });
  it('rechaza una solicitud para otro usuario con 404', async () => {
    const { service, calls } = setup();
    await expect(service.exportData('u1', 'u2')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(service.removeAccount('u1', 'u2')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(
      service.consent('u1', 'u2', { consent: true, version: '2' }),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(calls).toEqual([]);
  });
  it('exige consentimiento y versión actuales y registra fecha', async () => {
    expect(
      await validate(
        plainToInstance(ConsentDto, { consent: false, version: '1' }),
      ),
    ).not.toHaveLength(0);
    const { service } = setup();
    const result = await service.consent('u1', 'u1', {
      consent: true,
      version: '2',
    });
    expect(result.privacyNoticeVersion).toBe('2');
    expect(result.privacyConsentAt).toBeInstanceOf(Date);
  });
  it('exporta datos legibles sin secretos de autenticación', async () => {
    const { service } = setup();
    const result = await service.exportData('u1', 'u1');
    expect(result.data).toMatchObject({
      id: 'u1',
      email: 'u@example.test',
      workoutSessions: [{ sets: [] }],
    });
    expect(JSON.stringify(result)).not.toContain('passwordHash');
    expect(JSON.stringify(result)).not.toContain('firebaseUid');
  });
  it('elimina datos, identidad y archivos', async () => {
    const { service, calls } = setup();
    await service.removeAccount('u1', 'u1');
    expect(calls).toEqual([
      'stage',
      'delete-db',
      'transaction-commit',
      'delete-identity',
      'files-commit',
    ]);
  });
  it('elimina archivos y conserva el fallo si Firebase falla después del commit', async () => {
    const { service, calls } = setup(true);
    await expect(service.removeAccount('u1', 'u1')).rejects.toThrow();
    expect(calls).toEqual([
      'stage',
      'delete-db',
      'transaction-commit',
      'delete-identity',
      'files-commit',
    ]);
  });
  it('restaura archivos y no elimina la identidad si falla la base de datos', async () => {
    const { service, calls } = setup(false, true);
    await expect(service.removeAccount('u1', 'u1')).rejects.toThrow(
      'base de datos no disponible',
    );
    expect(calls).toEqual(['stage', 'delete-db', 'files-rollback']);
  });
  it('no borra datos si no se puede eliminar la identidad', async () => {
    const storage = {
      stageUserRemoval: () => {
        throw new Error('no debe llamarse');
      },
    };
    const db = {
      user: {
        findUnique: () => Promise.resolve({ id: 'u1', firebaseUid: 'f1' }),
      },
    };
    const verifier = {
      verifyIdToken: async () => ({ uid: 'f1', email: 'u@example.test' }),
    };
    const service = new PrivacyService(
      db as unknown as PrismaService,
      storage as unknown as StorageService,
      verifier,
    );
    await expect(service.removeAccount('u1', 'u1')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
  it('el almacenamiento restaura o elimina el archivo preparado', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'fittrack-arco-test-'));
    try {
      const storage = new StorageService(
        new ConfigService({ UPLOAD_DIR: dir }),
      );
      const file = await storage.save('u1', {
        originalname: 'foto.jpg',
        mimetype: 'image/jpeg',
        size: 3,
        buffer: Buffer.from('abc'),
      } as Express.Multer.File);
      const staged = await storage.stageUserRemoval('u1');
      await expect(storage.read('u1', file.id)).rejects.toBeInstanceOf(
        NotFoundException,
      );
      await staged.rollback();
      const restored = await storage.read('u1', file.id);
      expect(restored.metadata.id).toBe(file.id);
      for await (const _chunk of restored.stream) {
        /* consumir el archivo antes de moverlo */
      }
      const stagedAgain = await storage.stageUserRemoval('u1');
      await stagedAgain.commit();
      await expect(storage.read('u1', file.id)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});
