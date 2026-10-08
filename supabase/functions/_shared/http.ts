// Parseo y validación del cuerpo, y las respuestas JSON de las funciones del ranking.

export const MAX_BODY_BYTES = 2048;
export const MAX_PLAYED_SECONDS = 100_000_000;

/** Un error con el status y el código que ve el cliente. */
export class HttpError extends Error {
  constructor(readonly status: number, readonly code: string) {
    super(code);
  }
}

export const invalid = () => new HttpError(400, "invalid");

export type Body = Record<string, unknown>;

const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const APP_VERSION = /^[0-9.]{1,16}$/;

/** Lee el cuerpo sin pasar de 2 KB (corta la lectura al excederse) y exige un objeto JSON. */
export async function readJson(req: Request): Promise<Body> {
  const declared = Number(req.headers.get("content-length") ?? 0);
  if (declared > MAX_BODY_BYTES) throw invalid();
  const reader = req.body?.getReader();
  if (!reader) throw invalid();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_BODY_BYTES) {
      await reader.cancel();
      throw invalid();
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    throw invalid();
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) throw invalid();
  return parsed as Body;
}

export function installIdOf(body: Body): string {
  const value = body.installId;
  if (typeof value !== "string" || !UUID_V4.test(value)) throw invalid();
  return value;
}

export function runIdOf(body: Body): string {
  const value = body.runId;
  if (typeof value !== "string" || !UUID.test(value)) throw invalid();
  return value;
}

export function playedSecondsOf(body: Body): number {
  const value = body.playedSeconds;
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0 || value > MAX_PLAYED_SECONDS) {
    throw invalid();
  }
  return value;
}

export function appVersionOf(body: Body): string {
  const value = body.appVersion;
  if (typeof value !== "string" || !APP_VERSION.test(value)) throw invalid();
  return value;
}

/** El nombre es opcional (null o ausente = sin nombre); si viene, tiene que ser texto. */
export function optionalNameOf(body: Body): string | undefined {
  const value = body.name;
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "string") throw invalid();
  return value;
}

export function optionalBoolOf(body: Body, key: string): boolean {
  const value = body[key];
  if (value === undefined || value === null) return false;
  if (typeof value !== "boolean") throw invalid();
  return value;
}

export function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store", ...headers },
  });
}

export async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export const epochSeconds = (date: Date): number => Math.floor(date.getTime() / 1000);
