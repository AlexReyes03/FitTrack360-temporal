/**
 * Puerto único de desarrollo del API. Lo comparten `.env.example`, el
 * `Dockerfile` (EXPOSE), el panel `pnpm dev` y el default de Flutter
 * (`http://10.0.2.2:3000` en el emulador de Android).
 */
export const DEFAULT_API_PORT = 3000;

const DECIMAL_PORT = /^\d+$/;

/**
 * Convierte `PORT` en un puerto TCP válido. Si viene vacío usa el default; si
 * trae otro valor inválido lanza un error en vez de arrancar en silencio: Node
 * interpreta un `PORT` no numérico como nombre de pipe y no abre ningún puerto.
 */
export function resolveApiPort(value: string | undefined): number {
  const raw = value?.trim() ?? '';
  if (raw === '') {
    return DEFAULT_API_PORT;
  }

  const port = DECIMAL_PORT.test(raw) ? Number(raw) : Number.NaN;
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(
      `PORT inválido: "${value}". Usa un entero entre 1 y 65535 (por defecto ${DEFAULT_API_PORT}).`,
    );
  }
  return port;
}
