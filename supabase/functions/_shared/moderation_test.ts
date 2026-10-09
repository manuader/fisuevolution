import { assertEquals } from "@std/assert";
import type { Classifier } from "./haiku.ts";
import { moderate } from "./moderation.ts";

const terms = ["boludo"];

function spy(verdict: "ok" | "reject" | "unavailable") {
  const calls: string[] = [];
  const classify: Classifier = (name) => {
    calls.push(name);
    return Promise.resolve(verdict);
  };
  return { calls, classify };
}

Deno.test("reglas inválidas no llaman a la lista ni a Haiku", async () => {
  const { calls, classify } = spy("ok");
  assertEquals(await moderate("<b>", { terms, classify }), { status: "invalid" });
  assertEquals(calls.length, 0);
});

Deno.test("la lista rechaza sin llamar a Haiku", async () => {
  const { calls, classify } = spy("ok");
  assertEquals(await moderate("B0ludo", { terms, classify }), {
    status: "rejected", name: "B0ludo", by: "blocklist",
  });
  assertEquals(calls.length, 0);
});

Deno.test("Haiku ok -> ok, con el nombre normalizado", async () => {
  const { calls, classify } = spy("ok");
  assertEquals(await moderate("  Juan  P ", { terms, classify }), { status: "ok", name: "Juan P" });
  assertEquals(calls, ["Juan P"]);
});

Deno.test("Haiku reject -> rejected por haiku", async () => {
  const { classify } = spy("reject");
  assertEquals(await moderate("Juan", { terms, classify }), {
    status: "rejected", name: "Juan", by: "haiku",
  });
});

Deno.test("Haiku unavailable -> pending", async () => {
  const { classify } = spy("unavailable");
  assertEquals(await moderate("Juan", { terms, classify }), { status: "pending", name: "Juan" });
});

Deno.test("un clasificador que revienta -> pending", async () => {
  const classify: Classifier = () => Promise.reject(new Error("red caída"));
  assertEquals(await moderate("Juan", { terms, classify }), { status: "pending", name: "Juan" });
});

Deno.test("un clasificador que nunca resuelve -> pending al timeout y aborta la señal", async () => {
  let aborted = false;
  const classify: Classifier = (_name, signal) => {
    signal.addEventListener("abort", () => (aborted = true));
    return new Promise(() => {});
  };
  assertEquals(await moderate("Juan", { terms, classify, timeoutMs: 50 }), {
    status: "pending", name: "Juan",
  });
  assertEquals(aborted, true);
});
