import { randomUUID } from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';

/** Header que transporta el identificador de la petición. */
export const REQUEST_ID_HEADER = 'x-request-id';

/** Longitud máxima aceptada para un id entrante. */
export const REQUEST_ID_MAX_LENGTH = 128;

/**
 * Solo letras, dígitos, punto, guion y guion bajo: evita inyección de saltos
 * de línea en logs y de valores arbitrarios en headers de respuesta.
 */
const REQUEST_ID_PATTERN = /^[A-Za-z0-9._-]+$/;

/** Petición de Express con el id de correlación asignado por el middleware. */
export type RequestWithId = Request & { requestId?: string };

/**
 * Devuelve el id entrante si es válido; en cualquier otro caso (ausente,
 * vacío, demasiado largo o con caracteres no permitidos) genera un UUID v4.
 */
export function resolveRequestId(
  incoming: string | string[] | undefined,
): string {
  const candidate = Array.isArray(incoming) ? incoming[0] : incoming;
  if (
    candidate !== undefined &&
    candidate.length <= REQUEST_ID_MAX_LENGTH &&
    REQUEST_ID_PATTERN.test(candidate)
  ) {
    return candidate;
  }
  return randomUUID();
}

/**
 * Middleware funcional de Express: asigna el id a la petición y lo refleja en
 * la respuesta. Se registra en configureApp con app.use para cubrir todas las
 * rutas, incluidas las 404 y la UI de Swagger.
 */
export function requestIdMiddleware(
  req: RequestWithId,
  res: Response,
  next: NextFunction,
): void {
  const requestId = resolveRequestId(req.headers[REQUEST_ID_HEADER]);
  req.requestId = requestId;
  res.locals.requestId = requestId;
  res.setHeader(REQUEST_ID_HEADER, requestId);
  next();
}
