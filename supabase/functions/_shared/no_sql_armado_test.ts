import { assertEquals } from "@std/assert";

// Nada de SQL armado con texto: sólo consultas parametrizadas.
function* tsFiles(dir: URL): Generator<URL> {
  for (const entry of Deno.readDirSync(dir)) {
    const child = new URL(entry.name + (entry.isDirectory ? "/" : ""), dir);
    if (entry.isDirectory) yield* tsFiles(child);
    else if (entry.name.endsWith(".ts")) yield child;
  }
}

Deno.test("no hay SQL armado con texto en supabase/functions", () => {
  const prohibido = [/\.unsafe\(/, /\bsql\(\s*[`"'][^`"']*\$\{/];
  const culpables: string[] = [];
  for (const file of tsFiles(new URL("../", import.meta.url))) {
    if (file.pathname.endsWith("no_sql_armado_test.ts")) continue;
    const text = Deno.readTextFileSync(file);
    if (prohibido.some((re) => re.test(text))) culpables.push(file.pathname);
  }
  assertEquals(culpables, []);
});
