import type { Response } from 'express';
import {
  REQUEST_ID_MAX_LENGTH,
  type RequestWithId,
  requestIdMiddleware,
  resolveRequestId,
} from '../../src/gateway/request-id.middleware';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

describe('resolveRequestId (W8-09)', () => {
  it('reutiliza un id entrante válido', () => {
    expect(resolveRequestId('abc-123_DEF.9')).toBe('abc-123_DEF.9');
  });

  it('genera un UUID v4 cuando no viene id', () => {
    expect(resolveRequestId(undefined)).toMatch(UUID_PATTERN);
  });

  it('genera un UUID v4 cuando el id viene vacío', () => {
    expect(resolveRequestId('')).toMatch(UUID_PATTERN);
  });

  it('genera ids distintos en cada llamada', () => {
    expect(resolveRequestId(undefined)).not.toBe(resolveRequestId(undefined));
  });

  it('acepta un id con la longitud máxima permitida', () => {
    const id = 'a'.repeat(REQUEST_ID_MAX_LENGTH);
    expect(resolveRequestId(id)).toBe(id);
  });

  it('reemplaza un id que excede la longitud máxima', () => {
    const id = 'a'.repeat(REQUEST_ID_MAX_LENGTH + 1);
    expect(resolveRequestId(id)).toMatch(UUID_PATTERN);
  });

  it.each([
    ['salto de línea (inyección en logs)', 'abc\nFAKE LOG'],
    ['retorno de carro', 'abc\r\nSet-Cookie: x=1'],
    ['espacios', 'abc def'],
    ['caracteres de script', '<script>'],
  ])('reemplaza un id con %s', (_caso, id) => {
    expect(resolveRequestId(id)).toMatch(UUID_PATTERN);
  });

  it('usa el primer valor cuando el header llega repetido', () => {
    expect(resolveRequestId(['primero', 'segundo'])).toBe('primero');
  });
});

describe('requestIdMiddleware (W8-09)', () => {
  /** Respuesta falsa que solo registra headers y locals. */
  function fakeResponse(): {
    res: Response;
    headers: Record<string, string>;
    locals: Record<string, unknown>;
  } {
    const headers: Record<string, string> = {};
    const locals: Record<string, unknown> = {};
    const res = {
      locals,
      setHeader(name: string, value: string) {
        headers[name] = value;
        return res;
      },
    } as unknown as Response;
    return { res, headers, locals };
  }

  it('deja el id en el request, en res.locals y en el header de respuesta', () => {
    const req = {
      headers: { 'x-request-id': 'traza-1' },
    } as unknown as RequestWithId;
    const { res, headers, locals } = fakeResponse();
    let nextCalls = 0;

    requestIdMiddleware(req, res, () => {
      nextCalls += 1;
    });

    expect(req.requestId).toBe('traza-1');
    expect(locals.requestId).toBe('traza-1');
    expect(headers['x-request-id']).toBe('traza-1');
    expect(nextCalls).toBe(1);
  });
});
