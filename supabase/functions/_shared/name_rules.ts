// La regla del nombre del ranking. La misma que aplica la app (NameRules.swift):
// las dos leen la tabla supabase/tests/fixtures/name_rules_cases.json.

export const MAX_LENGTH = 15;

export type NameResult =
  | { ok: true; name: string }
  | { ok: false; reason: "empty" | "too_long" | "forbidden" };

// 0-9 A-Z a-z, espacio . - _, Latin-1 sin × ni ÷, Extended-A/-B y Extended Additional.
const ALLOWED = /^[A-Za-z0-9 ._\-À-ÖØ-öø-ɏḀ-ỿ]*$/u;

/** Normaliza y valida. Orden: NFC, prohibidos (antes que el largo), espacios, vacío, largo. */
export function validateName(raw: string): NameResult {
  const composed = raw.normalize("NFC");
  if (!ALLOWED.test(composed)) return { ok: false, reason: "forbidden" };
  const name = composed.replace(/ {2,}/g, " ").replace(/^ +| +$/g, "");
  if (name.length === 0) return { ok: false, reason: "empty" };
  if ([...name].length > MAX_LENGTH) return { ok: false, reason: "too_long" };
  return { ok: true, name };
}
