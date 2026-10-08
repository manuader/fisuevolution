import { assertEquals } from "jsr:@std/assert@1";
import { matches } from "./blocklist.ts";

const terms = ["boludo", "puto", "idiot"];

for (const name of ["b0lud0", "B.O.L.U.D.O", "Bolúdo", "elboludo99", "1d10t", "b o l u d o", "PUT0"]) {
  Deno.test(`la lista atrapa ${name}`, () => {
    assertEquals(matches(name, terms) !== null, true);
  });
}

for (const name of ["Juan", "ld1ot", "Fisu", "Pérez"]) {
  Deno.test(`la lista deja pasar ${name}`, () => {
    assertEquals(matches(name, terms), null);
  });
}

Deno.test("devuelve la palabra encontrada", () => {
  assertEquals(matches("xxPuto", terms), "puto");
});
