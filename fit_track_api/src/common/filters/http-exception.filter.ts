import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import {
  REQUEST_ID_HEADER,
  type RequestWithId,
} from '../../gateway/request-id.middleware';

export type ApiErrorBody = {
  code: string;
  message: string;
  requestId: string;
};

export function mapStatusToCode(
  status: number,
  isValidationError: boolean,
): string {
  if (status === HttpStatus.BAD_REQUEST) {
    return isValidationError ? 'VALIDATION_ERROR' : 'BAD_REQUEST';
  }
  switch (status) {
    case HttpStatus.UNAUTHORIZED:
      return 'UNAUTHORIZED';
    case HttpStatus.FORBIDDEN:
      return 'FORBIDDEN';
    case HttpStatus.NOT_FOUND:
      return 'NOT_FOUND';
    case HttpStatus.REQUEST_TIMEOUT:
      return 'REQUEST_TIMEOUT';
    case HttpStatus.PAYLOAD_TOO_LARGE:
      return 'PAYLOAD_TOO_LARGE';
    default:
      return status >= 500 ? 'INTERNAL_ERROR' : 'BAD_REQUEST';
  }
}

function isValidationPayload(payload: unknown): boolean {
  if (typeof payload !== 'object' || payload === null) {
    return false;
  }
  const record = payload as Record<string, unknown>;
  if (Array.isArray(record.message)) {
    return true;
  }
  return record.error === 'Bad Request' && typeof record.message === 'string';
}

function extractMessage(payload: unknown, fallback: string): string {
  if (typeof payload === 'string' && payload.trim() !== '') {
    return payload;
  }
  if (typeof payload === 'object' && payload !== null) {
    const record = payload as Record<string, unknown>;
    if (Array.isArray(record.message)) {
      return record.message.map(String).join(' ');
    }
    if (typeof record.message === 'string' && record.message.trim() !== '') {
      return record.message;
    }
  }
  return fallback;
}

function resolveRequestId(req: Request, res: Response): string {
  const fromLocals = res.locals.requestId;
  if (typeof fromLocals === 'string' && fromLocals.length > 0) {
    return fromLocals;
  }
  const fromReq = (req as RequestWithId).requestId;
  if (typeof fromReq === 'string' && fromReq.length > 0) {
    return fromReq;
  }
  const header = res.getHeader(REQUEST_ID_HEADER);
  if (typeof header === 'string' && header.length > 0) {
    return header;
  }
  return 'unknown';
}

function isPayloadTooLarge(exception: unknown): boolean {
  if (typeof exception !== 'object' || exception === null) {
    return false;
  }
  const err = exception as {
    type?: string;
    status?: number;
    statusCode?: number;
  };
  return (
    err.type === 'entity.too.large' ||
    err.status === 413 ||
    err.statusCode === 413
  );
}

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    if (response.headersSent) {
      return;
    }

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Error interno del servidor';
    let validation = false;
    let customCode: string | undefined;

    if (isPayloadTooLarge(exception)) {
      status = HttpStatus.PAYLOAD_TOO_LARGE;
      message = 'El cuerpo de la petición supera el límite permitido';
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      const payload = exception.getResponse();
      validation =
        status === HttpStatus.BAD_REQUEST && isValidationPayload(payload);
      message = extractMessage(payload, exception.message);
      if (typeof payload === 'object' && payload !== null) {
        const payloadCode = (payload as { code?: unknown }).code;
        if (typeof payloadCode === 'string' && payloadCode.trim() !== '') {
          customCode = payloadCode;
        }
      }
      if (status >= 500 && process.env.NODE_ENV === 'production') {
        message = 'Error interno del servidor';
      }
    }

    const requestId = resolveRequestId(request, response);
    const body: ApiErrorBody = {
      code: customCode ?? mapStatusToCode(status, validation),
      message,
      requestId,
    };

    response.status(status).json(body);
  }
}
