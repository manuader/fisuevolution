// La lista de palabras: coincidencia por subcadena sobre variantes del nombre
// (sin acentos, con las sustituciones típicas de números y símbolos, sin separadores).

const SUBSTITUTIONS: Record<string, string> = {
  "0": "o", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s",
};

function base(text: string): string {
  return text.toLowerCase().normalize("NFD").replace(/\p{M}/gu, "");
}

function substitute(text: string, one: "i" | "l"): string {
  let out = "";
  for (const ch of text) out += ch === "1" ? one : (SUBSTITUTIONS[ch] ?? ch);
  return out;
}

/** Las variantes del nombre contra las que se busca. */
export function variants(name: string): string[] {
  const plain = base(name);
  const out = new Set<string>();
  for (const one of ["i", "l"] as const) {
    const substituted = substitute(plain, one);
    out.add(substituted);
    out.add(substituted.replace(/[ .\-_]/g, ""));
  }
  return [...out];
}

/** La primera palabra de la lista que aparece en alguna variante, o null. */
export function matches(name: string, terms: readonly string[]): string | null {
  const candidates = variants(name);
  for (const term of terms) {
    const normalized = base(term).replace(/[ .\-_]/g, "");
    if (normalized.length === 0) continue;
    if (candidates.some((candidate) => candidate.includes(normalized))) return term;
  }
  return null;
}
