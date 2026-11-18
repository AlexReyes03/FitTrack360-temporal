import { validateEnv } from '../../src/config/env';

const SECRET_PASSWORD = 'super-secret-password-xyz';
const SECRET_KEY =
  '-----BEGIN PRIVATE KEY-----\nfake\n-----END PRIVATE KEY-----';

function validAdminEnv(
  overrides: Record<string, string> = {},
): Record<string, unknown> {
  return {
    DATABASE_URL: `postgresql://fittrack:${SECRET_PASSWORD}@localhost:5432/fittrack`,
    FIREBASE_AUTH_MODE: 'admin',
    FIREBASE_PROJECT_ID: 'fittrack-test',
    FIREBASE_CLIENT_EMAIL: 'sa@fittrack-test.iam.gserviceaccount.com',
    FIREBASE_PRIVATE_KEY: SECRET_KEY,
    ...overrides,
  };
}

describe('validateEnv (W12-14)', () => {
  it('acepta un entorno admin completo', () => {
    expect(validateEnv(validAdminEnv())).toMatchObject({
      FIREBASE_AUTH_MODE: 'admin',
      FIREBASE_PROJECT_ID: 'fittrack-test',
    });
  });

  it('acepta mock sin credenciales Firebase', () => {
    expect(
      validateEnv({
        DATABASE_URL: 'postgresql://fittrack:fittrack@localhost:5432/fittrack',
        FIREBASE_AUTH_MODE: 'mock',
      }),
    ).toMatchObject({ FIREBASE_AUTH_MODE: 'mock' });
  });

  it('acepta admin con GOOGLE_APPLICATION_CREDENTIALS en lugar de email/key', () => {
    expect(
      validateEnv({
        DATABASE_URL: 'postgresql://fittrack:fittrack@localhost:5432/fittrack',
        FIREBASE_AUTH_MODE: 'admin',
        FIREBASE_PROJECT_ID: 'fittrack-test',
        GOOGLE_APPLICATION_CREDENTIALS: '/tmp/sa.json',
      }),
    ).toMatchObject({ FIREBASE_PROJECT_ID: 'fittrack-test' });
  });

  it('falla nombrando DATABASE_URL cuando falta', () => {
    expect(() =>
      validateEnv({
        FIREBASE_AUTH_MODE: 'mock',
      }),
    ).toThrow(/DATABASE_URL/);
  });

  it('falla nombrando FIREBASE_PROJECT_ID en modo admin', () => {
    expect(() =>
      validateEnv(
        validAdminEnv({
          FIREBASE_PROJECT_ID: '',
        }),
      ),
    ).toThrow(/FIREBASE_PROJECT_ID/);
  });

  it('falla nombrando FIREBASE_CLIENT_EMAIL cuando falta en admin', () => {
    const env = validAdminEnv();
    delete env.FIREBASE_CLIENT_EMAIL;
    expect(() => validateEnv(env)).toThrow(/FIREBASE_CLIENT_EMAIL/);
  });

  it('rechaza FIREBASE_AUTH_MODE desconocido', () => {
    expect(() =>
      validateEnv({
        DATABASE_URL: 'postgresql://fittrack:fittrack@localhost:5432/fittrack',
        FIREBASE_AUTH_MODE: 'production',
      }),
    ).toThrow(/FIREBASE_AUTH_MODE/);
  });

  it('no incluye secretos en el mensaje de error', () => {
    let message = '';
    try {
      validateEnv(
        validAdminEnv({
          FIREBASE_PROJECT_ID: '',
        }),
      );
    } catch (error: unknown) {
      message = error instanceof Error ? error.message : String(error);
    }
    expect(message).toContain('FIREBASE_PROJECT_ID');
    expect(message).not.toContain(SECRET_PASSWORD);
    expect(message).not.toContain(SECRET_KEY);
    expect(message).not.toContain('BEGIN PRIVATE KEY');
  });
});
