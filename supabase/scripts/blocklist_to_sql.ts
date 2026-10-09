// Convierte supabase/blocklist/propuesta.txt en una migración de blocklist.
//   deno run --allow-read --allow-write supabase/scripts/blocklist_to_sql.ts [lista.txt] [salida.sql]
// Los términos no se pegan en el SQL como texto suelto: viajan como un arreglo JSON dentro de un
// literal entre dólares (donde la comilla simple es literal) y es la base la que los abre con
// jsonb_array_elements. Así `o'neil` entra tal cual, sin escapar a mano.

export type Lang = "es" | "en";
export interface Entry {
  lang: Lang;
  term: string;
}

const TAG = "$blocklist$";

/** `es|término` por línea; ignora vacías y comentarios (#). Rechaza lo que no entiende. */
export function parseEntries(text: string): Entry[] {
  const entries = new Map<string, Entry>();
  text.split("\n").forEach((raw, index) => {
    const line = raw.trim();
    if (line === "" || line.startsWith("#")) return;
    const [lang, ...rest] = line.split("|");
    const term = rest.join("|").trim().toLowerCase();
    if ((lang !== "es" && lang !== "en") || term === "") {
      throw new Error(`línea ${index + 1}: se espera "es|término" o "en|término", llegó "${line}"`);
    }
    entries.set(`${lang}|${term}`, { lang, term });
  });
  return [...entries.values()];
}

export function blocklistSql(entries: readonly Entry[]): string {
  const payload = JSON.stringify(entries.map(({ lang, term }) => ({ lang, term })));
  if (payload.includes(TAG)) throw new Error(`la lista contiene ${TAG}`);
  return [
    "-- Generada por supabase/scripts/blocklist_to_sql.ts desde supabase/blocklist/propuesta.txt.",
    "insert into public.blocklist (term, lang)",
    "select e ->> 'term', e ->> 'lang'",
    `from jsonb_array_elements(${TAG}${payload}${TAG}::jsonb) as e`,
    "on conflict do nothing;",
    "",
  ].join("\n");
}

if (import.meta.main) {
  const root = new URL("../", import.meta.url);
  const source = Deno.args[0] ?? new URL("blocklist/propuesta.txt", root).pathname;
  const stamp = new Date().toISOString().replace(/\D/g, "").slice(0, 14);
  const target = Deno.args[1] ?? new URL(`migrations/${stamp}_blocklist.sql`, root).pathname;
  const entries = parseEntries(Deno.readTextFileSync(source));
  Deno.writeTextFileSync(target, blocklistSql(entries));
  console.log(`${entries.length} términos -> ${target}`);
}
