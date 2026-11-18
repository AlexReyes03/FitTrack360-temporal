import type { NextFunction, Request, Response } from 'express';

export const DEFAULT_REQUEST_TIMEOUT_MS = 30_000;

export function resolveRequestTimeoutMs(
  raw: string | undefined = process.env.REQUEST_TIMEOUT_MS,
): number {
  if (raw === undefined || raw.trim() === '') {
    return DEFAULT_REQUEST_TIMEOUT_MS;
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return DEFAULT_REQUEST_TIMEOUT_MS;
  }
  return parsed;
}

export function createRequestTimeoutMiddleware(
  timeoutMs: number = resolveRequestTimeoutMs(),
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const timer = setTimeout(() => {
      if (res.headersSent) {
        return;
      }
      const requestId =
        (res.locals.requestId as string | undefined) ??
        (req as Request & { requestId?: string }).requestId ??
        'unknown';
      res.status(408).json({
        code: 'REQUEST_TIMEOUT',
        message: 'La solicitud excedió el tiempo máximo de espera',
        requestId,
      });
    }, timeoutMs);

    const clear = (): void => {
      clearTimeout(timer);
    };
    res.on('finish', clear);
    res.on('close', clear);
    next();
  };
}
