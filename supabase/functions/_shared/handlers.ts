import {
  appVersionOf,
  type Body,
  epochSeconds,
  HttpError,
  installIdOf,
  json,
  optionalBoolOf,
  optionalNameOf,
  playedSecondsOf,
  readJson,
  runIdOf,
  sha256Hex,
} from "./http.ts";
import type { Moderation } from "./moderation.ts";
import type { BoardRow, Repo, Settings } from "./repo.ts";

export const TOP_SIZE = 100;
export const TOP_CACHE_MS = 60_000;

export interface Deps {
  repo: Repo;
  moderate: (name: string) => Promise<Moderation>;
  now: () => Date;
  settings: () => Promise<Settings>;
}

export type Handler = (req: Request) => Promise<Response>;

interface Context {
  hash: string;
  now: Date;
}

/** Los códigos de las funciones SQL: P0403 la partida no es del jugador, P0409 no está en ese estado. */
function failure(error: unknown): Response {
  if (error instanceof HttpError) return json({ error: error.code }, error.status);
  const code = (error as { code?: string } | null)?.code;
  if (code === "P0403") return json({ error: "not_owner" }, 403);
  if (code === "P0409") return json({ error: "not_active" }, 409);
  console.error("ranking: error inesperado", code ?? error);
  return json({ error: "internal" }, 500);
}

export function makeHandlers(deps: Deps) {
  const { repo } = deps;

  /** Método, cuerpo, interruptor del servidor y límite de llamadas, antes de cualquier otra cosa. */
  function endpoint<I>(
    parse: (body: Body) => I,
    act: (input: I, context: Context) => Promise<Response>,
  ): Handler {
    return async (req) => {
      if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405, { Allow: "POST" });
      try {
        const body = await readJson(req);
        const installId = installIdOf(body);
        const input = parse(body);
        if ((await deps.settings()).ranking_enabled !== true) throw new HttpError(503, "disabled");
        const hash = await sha256Hex(installId);
        const now = deps.now();
        if (await repo.hitRateLimit(hash, now)) throw new HttpError(429, "rate_limited");
        return await act(input, { hash, now });
      } catch (error) {
        return failure(error);
      }
    };
  }

  const startRun = endpoint(appVersionOf, async (appVersion, { hash, now }) => {
    const run = await repo.startRun(hash, appVersion, now);
    return json(run);
  });

  const finishRun = endpoint(
    (body) => ({
      runId: runIdOf(body),
      played: playedSecondsOf(body),
      name: optionalNameOf(body),
    }),
    async ({ runId, played, name }, { hash, now }) => {
      // Un nombre inválido por reglas corta antes de tocar la partida.
      const verdict = name === undefined ? undefined : await deps.moderate(name);
      if (verdict?.status === "invalid") throw new HttpError(400, "invalid");

      const sealed = await repo.finishRun(hash, runId, played, now);
      if (verdict === undefined) {
        return json({ status: sealed.status, nameStatus: sealed.nameStatus, realSeconds: sealed.realSeconds });
      }
      const named = await repo.setRunName(hash, runId, verdict.name, verdict.status, now);
      return json({
        status: sealed.status,
        nameStatus: named.nameStatus,
        realSeconds: sealed.realSeconds,
        ...(named.rank === null ? {} : { rank: named.rank }),
      });
    },
  );

  // La parte común del top se comparte 60 s entre los pedidos de este isolate.
  let topCache: { at: number; rows: BoardRow[] } | null = null;
  async function sharedTop(now: Date): Promise<BoardRow[]> {
    if (topCache !== null && now.getTime() - topCache.at < TOP_CACHE_MS && now.getTime() >= topCache.at) {
      return topCache.rows;
    }
    const rows = await repo.top(TOP_SIZE);
    topCache = { at: now.getTime(), rows };
    return rows;
  }

  const leaderboard = endpoint(
    (body) => ({ mine: optionalBoolOf(body, "mine") }),
    async ({ mine }, { hash, now }) => {
      const [top, me, runs] = await Promise.all([
        sharedTop(now),
        repo.myRank(hash),
        mine ? repo.myRuns(hash) : Promise.resolve(undefined),
      ]);
      const row = (r: BoardRow) => ({
        runId: r.runId,
        rank: r.rank,
        name: r.name,
        realSeconds: r.realSeconds,
        playedSeconds: r.playedSeconds,
        isMe: r.runId === me?.runId,
      });
      return json({
        top: top.map(row),
        ...(me === null ? {} : { me: row(me), myRank: me.rank }),
        ...(runs === undefined ? {} : { mine: runs }),
        fetchedAt: epochSeconds(now),
      }, 200, { "Cache-Control": "private, max-age=60" });
    },
  );

  const report = endpoint(runIdOf, async (runId, { hash, now }) => {
    await repo.reportRun(hash, runId, now);
    return json({ ok: true });
  });

  return { startRun, finishRun, leaderboard, report };
}
