import { assert, assertEquals } from "jsr:@std/assert@1";
import { validateName } from "./name_rules.ts";

interface Case { input: string; expect: string; normalized?: string }

const table = JSON.parse(
  Deno.readTextFileSync(new URL("../../tests/fixtures/name_rules_cases.json", import.meta.url)),
) as { cases: Case[] };

Deno.test("la tabla tiene al menos 30 casos", () => {
  assert(table.cases.length >= 30);
});

for (const [i, c] of table.cases.entries()) {
  Deno.test(`name_rules caso ${i}: ${JSON.stringify(c.input)} -> ${c.expect}`, () => {
    const result = validateName(c.input);
    if (c.expect === "ok") {
      assertEquals(result, { ok: true, name: c.normalized! });
    } else {
      assertEquals(result, { ok: false, reason: c.expect as "empty" | "too_long" | "forbidden" });
    }
  });
}
