import postgres from "postgres";
import type { Deps } from "./handlers.ts";
import { type Classifier, haikuClassifier } from "./haiku.ts";
import { moderate } from "./moderation.ts";
import { pgRepo } from "./repo.ts";

const TERMS_TTL_MS = 5 * 60_000;

/** Sin la clave de Anthropic nada queda `ok` sin moderar: todo cae en `pending` para el cron. */
const unavailable: Classifier = () => Promise.resolve("unavailable");

export function prodDeps(): Deps {
  const url = Deno.env.get("SUPABASE_DB_URL");
  if (!url) throw new Error("falta SUPABASE_DB_URL");
  const repo = pgRepo(postgres(url));
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  const classify = apiKey ? haikuClassifier(apiKey) : unavailable;

  let terms: { at: number; list: string[] } | null = null;
  async function blocklist(now: Date): Promise<string[]> {
    if (terms !== null && now.getTime() - terms.at < TERMS_TTL_MS) return terms.list;
    terms = { at: now.getTime(), list: await repo.blocklist() };
    return terms.list;
  }

  const now = () => new Date();
  return {
    repo,
    now,
    settings: () => repo.settings(),
    moderate: async (name) => moderate(name, { terms: await blocklist(now()), classify }),
  };
}
