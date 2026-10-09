import { matches } from "./blocklist.ts";
import type { Classifier } from "./haiku.ts";
import { validateName } from "./name_rules.ts";

export const DEFAULT_TIMEOUT_MS = 5_000;

export type Moderation =
  | { status: "invalid" }
  | { status: "rejected"; name: string; by: "blocklist" | "haiku" }
  | { status: "pending" | "ok"; name: string };

export interface ModerationDeps {
  terms: readonly string[];
  classify: Classifier;
  timeoutMs?: number;
}

/** Reglas, después lista, después Haiku. Cada etapa corta la siguiente. */
export async function moderate(raw: string, deps: ModerationDeps): Promise<Moderation> {
  const checked = validateName(raw);
  if (!checked.ok) return { status: "invalid" };
  const name = checked.name;
  if (matches(name, deps.terms) !== null) return { status: "rejected", name, by: "blocklist" };

  const controller = new AbortController();
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timedOut = new Promise<"unavailable">((resolve) => {
    timer = setTimeout(() => {
      controller.abort();
      resolve("unavailable");
    }, deps.timeoutMs ?? DEFAULT_TIMEOUT_MS);
  });
  try {
    const verdict = await Promise.race([
      deps.classify(name, controller.signal).catch(() => "unavailable" as const),
      timedOut,
    ]);
    if (verdict === "ok") return { status: "ok", name };
    if (verdict === "reject") return { status: "rejected", name, by: "haiku" };
    return { status: "pending", name };
  } finally {
    clearTimeout(timer);
  }
}
