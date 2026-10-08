import { assertEquals, assertThrows } from "@std/assert";
import { blocklistSql, parseEntries } from "../../scripts/blocklist_to_sql.ts";

const PROPUESTA = new URL("../../blocklist/propuesta.txt", import.meta.url);

/** El arreglo JSON que la migración le pasa a jsonb_array_elements. */
function payloadOf(sql: string) {
  const match = sql.match(/\$blocklist\$(.*)\$blocklist\$/s);
  return JSON.parse(match![1]);
}

Deno.test("blocklist_to_sql: una comilla entra literal, sin escapar a mano", () => {
  const entries = parseEntries("# comentario\n\nes|O'Neil\nen|x$y\\z\nes|o'neil\n");
  const sql = blocklistSql(entries);
  assertEquals(payloadOf(sql), [{ lang: "es", term: "o'neil" }, { lang: "en", term: "x$y\\z" }]);
  assertEquals(sql.includes("o'neil"), true);
  assertEquals(sql.includes("on conflict do nothing"), true);
});

Deno.test("blocklist_to_sql: rechaza líneas mal formadas y la etiqueta dentro de la lista", () => {
  assertThrows(() => parseEntries("fr|merde"));
  assertThrows(() => parseEntries("es|"));
  assertThrows(() => blocklistSql([{ lang: "es", term: "a$blocklist$b" }]));
});

Deno.test("la propuesta de lista parsea, sin repetidos y con lo mínimo de cada familia", () => {
  const entries = parseEntries(Deno.readTextFileSync(PROPUESTA));
  const terms = entries.map((entry) => `${entry.lang}|${entry.term}`);
  assertEquals(new Set(terms).size, terms.length);
  for (const must of ["es|admin", "es|soporte", "es|moderador", "es|fisu oficial", "es|mierda", "en|fuck"]) {
    assertEquals(terms.includes(must), true, must);
  }
  assertEquals(entries.length >= 120, true);
});
