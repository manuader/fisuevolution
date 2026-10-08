import { assert, assertEquals } from "jsr:@std/assert@1";
import postgres from "postgres";
import { makeHandlers } from "./handlers.ts";
import { sha256Hex } from "./http.ts";
import type { Moderation } from "./moderation.ts";
import { pgRepo } from "./repo.ts";

const url = Deno.env.get("DATABASE_URL");
if (!url) console.warn("handlers_test: sin DATABASE_URL, la integración se saltea");

const HOUR = 3600_000;
const T0 = new Date("2026-10-08T10:00:00Z");
const ALICE = "11111111-1111-4111-8111-111111111111";
const BOB = "22222222-2222-4222-8222-222222222222";
const CAROL = "abcdefab-cdef-4bcd-8bcd-abcdefabcdef";

type Body = Record<string, unknown>;
// deno-lint-ignore no-explicit-any
type Json = Record<string, any>;

const aprueba = (name: string): Promise<Moderation> => Promise.resolve({ status: "ok", name });

async function withBackend(
  body: (api: Api) => Promise<void>,
  moderate: (name: string) => Promise<Moderation> = aprueba,
) {
  const sql = postgres(url!, { max: 2, onnotice: () => {} });
  try {
    await sql`truncate players, runs, reports, api_calls, blocklist cascade`;
    await sql`update settings set value = ${sql.json(true)} where key = 'ranking_enabled'`;
    await sql`update settings set value = ${sql.json(36000)} where key = 'min_real_seconds_to_god'`;
    await sql`update settings set value = ${sql.json(30)} where key = 'rate_limit_per_hour'`;
    await sql`update settings set value = ${sql.json(3)} where key = 'reports_to_hide'`;
    let clock = T0;
    const repo = pgRepo(sql);
    const handlers = makeHandlers({ repo, moderate, now: () => clock, settings: () => repo.settings() });
    const call = async (name: keyof typeof handlers, payload: unknown, method = "POST") => {
      const init: RequestInit = { method };
      if (method === "POST") init.body = typeof payload === "string" ? payload : JSON.stringify(payload);
      const res = await handlers[name](new Request("http://local/fn", init));
      return { status: res.status, body: await res.json() as Json, headers: res.headers };
    };
    await body({
      sql,
      call,
      at: (date: Date) => {
        clock = date;
      },
      later: (ms: number) => {
        clock = new Date(clock.getTime() + ms);
      },
      start: async (installId: string) => {
        const res = await call("startRun", { installId, appVersion: "2.0" });
        assertEquals(res.status, 200);
        return res.body.runId as string;
      },
    });
  } finally {
    await sql.end();
  }
}

interface Api {
  sql: ReturnType<typeof postgres>;
  call: (name: "startRun" | "finishRun" | "leaderboard" | "report", payload: unknown, method?: string) => Promise<
    { status: number; body: Json; headers: Headers }
  >;
  at: (date: Date) => void;
  later: (ms: number) => void;
  start: (installId: string) => Promise<string>;
}

function integration(name: string, fn: (api: Api) => Promise<void>, moderate?: (n: string) => Promise<Moderation>) {
  Deno.test({ name, ignore: !url, fn: () => withBackend(fn, moderate) });
}

/** Arranca a las 10:00 y termina `hours` horas después. */
async function fullRun(api: Api, installId: string, hours: number, extra: Body = {}) {
  api.at(T0);
  const runId = await api.start(installId);
  api.later(hours * HOUR);
  const finish = await api.call("finishRun", { installId, runId, playedSeconds: 1000, ...extra });
  return { runId, finish };
}

integration("el tiempo real lo pone el servidor, no el cuerpo", async (api) => {
  api.at(T0);
  const started = await api.call("startRun", { installId: ALICE, appVersion: "2.0.1" });
  assertEquals(started.status, 200);
  assertEquals(started.body.startedAt, T0.getTime() / 1000);
  api.later((42 * 3600 + 14 * 60) * 1000);
  const finish = await api.call("finishRun", {
    installId: ALICE,
    runId: started.body.runId,
    playedSeconds: 99_000_000,
    name: "Alice",
  });
  assertEquals(finish.status, 200);
  assertEquals(finish.body.realSeconds, 152040);
  assertEquals(finish.body.status, "finished");
  assertEquals(finish.body.nameStatus, "ok");
  assertEquals(finish.body.rank, 1);
  const board = await api.call("leaderboard", { installId: ALICE });
  assertEquals(board.body.top[0].playedSeconds, 152040);
});

integration("una sola partida activa por jugador: la vieja queda abandonada", async (api) => {
  const first = await api.start(ALICE);
  api.later(HOUR);
  await api.start(ALICE);
  const finish = await api.call("finishRun", { installId: ALICE, runId: first, playedSeconds: 1 });
  assertEquals(finish.status, 409);
  assertEquals(finish.body.error, "not_active");
});

integration("bajo el piso queda en review y no se publica", async (api) => {
  const { finish } = await fullRun(api, ALICE, 3, { name: "Rapido" });
  assertEquals(finish.status, 200);
  assertEquals(finish.body.status, "review");
  assertEquals(finish.body.rank, undefined);
  const board = await api.call("leaderboard", { installId: ALICE });
  assertEquals(board.body.top, []);
  assertEquals(board.body.me, undefined);
});

integration("Haiku caído: la partida se publica sin nombre", async (api) => {
  const { finish } = await fullRun(api, ALICE, 40, { name: "Alice" });
  assertEquals(finish.body.nameStatus, "pending");
  const board = await api.call("leaderboard", { installId: ALICE });
  assertEquals(board.body.top.length, 1);
  assertEquals(board.body.top[0].name, null);
}, (name) => Promise.resolve({ status: "pending", name }));

integration("un rechazo se corrige reenviando sobre la misma partida", async (api) => {
  const first = await fullRun(api, ALICE, 40, { name: "Malo" });
  assertEquals(first.finish.body.nameStatus, "rejected");
  assertEquals(first.finish.body.rank, undefined);
  const board = await api.call("leaderboard", { installId: ALICE });
  assertEquals(board.body.top, []);
  const second = await api.call("finishRun", {
    installId: ALICE,
    runId: first.runId,
    playedSeconds: 1000,
    name: "Bueno",
  });
  assertEquals(second.status, 200);
  assertEquals(second.body.nameStatus, "ok");
  assertEquals(second.body.realSeconds, first.finish.body.realSeconds);
  assertEquals(second.body.rank, 1);
}, (name) => Promise.resolve(name === "Malo" ? { status: "rejected", name, by: "blocklist" } : { status: "ok", name }));

integration("sin nombre no se publica; con nombre aparece con el tiempo del sello", async (api) => {
  const { runId, finish } = await fullRun(api, ALICE, 40);
  assertEquals(finish.body.nameStatus, "missing");
  assertEquals((await api.call("leaderboard", { installId: ALICE })).body.top, []);
  api.later(5 * HOUR);
  const named = await api.call("finishRun", { installId: ALICE, runId, playedSeconds: 1000, name: "Alice" });
  assertEquals(named.body.realSeconds, 40 * 3600);
  assertEquals(named.body.rank, 1);
  const board = await api.call("leaderboard", { installId: ALICE });
  assertEquals(board.body.top[0].realSeconds, 40 * 3600);
});

integration("tres reportes la muestran como Anónimo, en el top y en la fila propia", async (api) => {
  const { runId } = await fullRun(api, ALICE, 40, { name: "Alice" });
  const reporters = [BOB, "33333333-3333-4333-8333-333333333333", "44444444-4444-4444-8444-444444444444"];
  for (const installId of reporters) {
    const res = await api.call("report", { installId, runId });
    assertEquals(res.body, { ok: true });
  }
  // la repetición de un mismo reportero no suma
  await api.call("report", { installId: BOB, runId });
  api.later(2 * 60_000);
  const board = await api.call("leaderboard", { installId: ALICE });
  assertEquals(board.body.top[0].name, null);
  assertEquals(board.body.me.name, null);
  assertEquals(board.body.me.isMe, true);
});

integration("dos reportes no alcanzan", async (api) => {
  const { runId } = await fullRun(api, ALICE, 40, { name: "Alice" });
  await api.call("report", { installId: BOB, runId });
  await api.call("report", { installId: "33333333-3333-4333-8333-333333333333", runId });
  api.later(2 * 60_000);
  const board = await api.call("leaderboard", { installId: ALICE });
  assertEquals(board.body.top[0].name, "Alice");
});

integration("un nombre inválido por reglas es 400 y no toca la partida", async (api) => {
  const runId = await api.start(ALICE);
  api.later(40 * HOUR);
  const bad = await api.call("finishRun", { installId: ALICE, runId, playedSeconds: 1, name: "<script>" });
  assertEquals(bad.status, 400);
  assertEquals(bad.body.error, "invalid");
  const [row] = await api.sql`select status, name_status, name from runs where id = ${runId}`;
  assertEquals(row.status, "active");
  assertEquals(row.name_status, "missing");
  assertEquals(row.name, null);
}, (name) => Promise.resolve(name.includes("<") ? { status: "invalid" } : { status: "ok", name }));

integration("sellar dos veces devuelve lo mismo (idempotente)", async (api) => {
  const { runId, finish } = await fullRun(api, ALICE, 40, { name: "Alice" });
  api.later(HOUR);
  const again = await api.call("finishRun", { installId: ALICE, runId, playedSeconds: 5, name: "Alice" });
  assertEquals(again.status, 200);
  assertEquals(again.body, finish.body);
  const [count] = await api.sql`select count(*)::int as n from runs`;
  assertEquals(count.n, 1);
});

integration("una partida ajena es 403", async (api) => {
  const runId = await api.start(ALICE);
  api.later(40 * HOUR);
  const res = await api.call("finishRun", { installId: BOB, runId, playedSeconds: 1 });
  assertEquals(res.status, 403);
  assertEquals(res.body.error, "not_owner");
});

integration("la llamada 31 de la hora es 429", async (api) => {
  for (let i = 0; i < 30; i++) {
    assertEquals((await api.call("report", { installId: ALICE, runId: crypto.randomUUID() })).status, 200);
  }
  const limited = await api.call("report", { installId: ALICE, runId: crypto.randomUUID() });
  assertEquals(limited.status, 429);
  assertEquals(limited.body.error, "rate_limited");
  // otro jugador no se ve afectado, y a la hora siguiente vuelve
  assertEquals((await api.call("report", { installId: BOB, runId: crypto.randomUUID() })).status, 200);
  api.later(HOUR + 1000);
  assertEquals((await api.call("report", { installId: ALICE, runId: crypto.randomUUID() })).status, 200);
});

integration("el interruptor apaga las cuatro con 503", async (api) => {
  await api.sql`update settings set value = ${api.sql.json(false)} where key = 'ranking_enabled'`;
  const runId = crypto.randomUUID();
  const bodies = {
    startRun: { installId: ALICE, appVersion: "2.0" },
    finishRun: { installId: ALICE, runId, playedSeconds: 1 },
    leaderboard: { installId: ALICE },
    report: { installId: ALICE, runId },
  } as const;
  for (const [name, payload] of Object.entries(bodies)) {
    const res = await api.call(name as keyof typeof bodies, payload);
    assertEquals(res.status, 503, name);
    assertEquals(res.body.error, "disabled");
  }
  const [calls] = await api.sql`select count(*)::int as n from api_calls`;
  assertEquals(calls.n, 0);
});

integration("cuerpos raros son 400", async (api) => {
  const runId = crypto.randomUUID();
  const cases: [string, unknown][] = [
    ["installId que no es UUID", { installId: "no-soy-uuid", appVersion: "2.0" }],
    ["installId en mayúsculas", { installId: CAROL.toUpperCase(), appVersion: "2.0" }],
    ["sin installId", { appVersion: "2.0" }],
    ["appVersion con letras", { installId: ALICE, appVersion: "2.0-beta" }],
    ["JSON roto", "{no es json"],
    ["un arreglo", "[1,2]"],
    ["cuerpo de 3 KB", { installId: ALICE, appVersion: "2.0", relleno: "x".repeat(3000) }],
  ];
  for (const [label, payload] of cases) {
    const res = await api.call("startRun", payload);
    assertEquals(res.status, 400, label);
    assertEquals(res.body.error, "invalid", label);
  }
  const finishCases: [string, Body][] = [
    ["playedSeconds negativo", { installId: ALICE, runId, playedSeconds: -1 }],
    ["playedSeconds fraccionario", { installId: ALICE, runId, playedSeconds: 1.5 }],
    ["playedSeconds enorme", { installId: ALICE, runId, playedSeconds: 100_000_001 }],
    ["playedSeconds texto", { installId: ALICE, runId, playedSeconds: "10" }],
    ["runId que no es UUID", { installId: ALICE, runId: "1", playedSeconds: 1 }],
    ["name que no es texto", { installId: ALICE, runId, playedSeconds: 1, name: 5 }],
  ];
  for (const [label, payload] of finishCases) {
    const res = await api.call("finishRun", payload);
    assertEquals(res.status, 400, label);
  }
  assertEquals((await api.call("leaderboard", { installId: ALICE, mine: "si" })).status, 400);
  assertEquals((await api.call("report", { installId: ALICE })).status, 400);
  const [calls] = await api.sql`select count(*)::int as n from api_calls`;
  assertEquals(calls.n, 0);
});

integration("sólo POST: lo demás es 405", async (api) => {
  const res = await api.call("startRun", undefined, "GET");
  assertEquals(res.status, 405);
  assertEquals(res.headers.get("allow"), "POST");
});

integration("la fila propia fuera del top: top de 100 y el puesto 103", async (api) => {
  await api.sql`
    with fast as (
      insert into players (install_id_hash)
      select encode(sha256(convert_to(g::text, 'UTF8')), 'hex') from generate_series(1, ${102}::int) g
      returning id
    ), numbered as (select id, row_number() over () as n from fast)
    insert into runs (player_id, started_at, finished_at, real_seconds, played_seconds, name, name_status, status, app_version)
    select id, ${T0}::timestamptz, ${T0}::timestamptz + interval '1 day', 40000 + n, 100, 'Jugador', 'ok', 'finished', '2.0'
    from numbered`;
  const { finish } = await fullRun(api, ALICE, 41000 / 3600 + 0, { name: "Alice" });
  assertEquals(finish.body.realSeconds, 41000);
  assertEquals(finish.body.rank, 103);
  const board = await api.call("leaderboard", { installId: ALICE, mine: true });
  assertEquals(board.body.top.length, 100);
  assertEquals(board.body.top.some((row: Json) => row.isMe), false);
  assertEquals(board.body.me.rank, 103);
  assertEquals(board.body.myRank, 103);
  assertEquals(board.body.mine.length, 1);
  assertEquals(board.body.mine[0].nameStatus, "ok");
  assertEquals(board.headers.get("cache-control"), "private, max-age=60");
  assert(typeof board.body.fetchedAt === "number");
});

integration("el top se comparte 60 s y se refresca después", async (api) => {
  await fullRun(api, ALICE, 40, { name: "Alice" });
  const first = await api.call("leaderboard", { installId: BOB });
  assertEquals(first.body.top.length, 1);
  assertEquals(first.body.top[0].isMe, false);
  await api.sql`
    with p as (insert into players (install_id_hash) values (${await sha256Hex(CAROL)}) returning id)
    insert into runs (player_id, started_at, finished_at, real_seconds, played_seconds, name, name_status, status, app_version)
    select id, ${T0}::timestamptz, ${T0}::timestamptz, 200000, 1, 'Carol', 'ok', 'finished', '2.0' from p`;
  assertEquals((await api.call("leaderboard", { installId: BOB })).body.top.length, 1);
  api.later(61_000);
  const fresh = await api.call("leaderboard", { installId: CAROL });
  assertEquals(fresh.body.top.length, 2);
  assertEquals(fresh.body.top[1].isMe, true);
});

integration("el install id se guarda como hash, nunca en claro", async (api) => {
  await api.start(ALICE);
  const [player] = await api.sql`select install_id_hash from players`;
  assertEquals(player.install_id_hash, await sha256Hex(ALICE));
});
