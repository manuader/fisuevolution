import type postgres from "postgres";
import { epochSeconds } from "./http.ts";

type Sql = ReturnType<typeof postgres>;

export interface Settings {
  ranking_enabled?: boolean;
  [key: string]: unknown;
}

export type RunStatus = "active" | "finished" | "review" | "hidden" | "abandoned";
export type NameStatus = "ok" | "pending" | "rejected" | "missing";

export interface BoardRow {
  runId: string;
  rank: number;
  name: string | null;
  realSeconds: number;
  playedSeconds: number;
}

export interface MyRun {
  runId: string;
  startedAt: number;
  finishedAt: number | null;
  realSeconds: number | null;
  playedSeconds: number | null;
  name: string | null;
  nameStatus: NameStatus;
  status: RunStatus;
}

/** Cada método es una llamada a una función SQL de las migraciones; las horas las pone el handler. */
export interface Repo {
  settings(): Promise<Settings>;
  blocklist(): Promise<string[]>;
  hitRateLimit(hash: string, now: Date): Promise<boolean>;
  startRun(hash: string, appVersion: string, clientRunId: string, now: Date): Promise<{ runId: string; startedAt: number }>;
  finishRun(hash: string, runId: string, played: number, now: Date): Promise<
    { status: RunStatus; nameStatus: NameStatus; realSeconds: number }
  >;
  setRunName(hash: string, runId: string, name: string, status: NameStatus, now: Date): Promise<
    { nameStatus: NameStatus; rank: number | null }
  >;
  reportRun(hash: string, runId: string, now: Date): Promise<void>;
  top(limit: number): Promise<BoardRow[]>;
  myRank(hash: string): Promise<BoardRow | null>;
  myRuns(hash: string): Promise<MyRun[]>;
}

// Un hash que no es de nadie: el top compartido no sabe quién lo pide.
const NO_ONE = "";

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;

const boardRow = (row: Row): BoardRow => ({
  runId: row.run_id,
  rank: Number(row.rank),
  name: row.display_name,
  realSeconds: row.real_seconds,
  playedSeconds: row.played_seconds,
});

const optionalNumber = (value: number | null): number | null => (value === null ? null : Number(value));

export function pgRepo(sql: Sql): Repo {
  return {
    async settings() {
      const [row] = await sql`select ranking_settings() as settings`;
      return row.settings as Settings;
    },
    async blocklist() {
      const rows = await sql`select term from blocklist`;
      return rows.map((row) => row.term as string);
    },
    async hitRateLimit(hash, now) {
      const [row] = await sql`select hit_rate_limit(${hash}, ${now}) as limited`;
      return row.limited as boolean;
    },
    async startRun(hash, appVersion, clientRunId, now) {
      const [row] = await sql`select * from start_run(${hash}, ${appVersion}, ${now}, ${clientRunId})`;
      return { runId: row.run_id, startedAt: epochSeconds(row.started_at) };
    },
    async finishRun(hash, runId, played, now) {
      const [row] = await sql`select * from finish_run(${hash}, ${runId}, ${played}, ${now})`;
      return { status: row.status, nameStatus: row.name_status, realSeconds: row.real_seconds };
    },
    async setRunName(hash, runId, name, status, now) {
      const [row] = await sql`select * from set_run_name(${hash}, ${runId}, ${name}, ${status}, ${now})`;
      return { nameStatus: row.name_status, rank: row.rank === null ? null : Number(row.rank) };
    },
    async reportRun(hash, runId, now) {
      await sql`select report_run(${hash}, ${runId}, ${now})`;
    },
    async top(limit) {
      const rows = await sql`select * from leaderboard_top(${NO_ONE}, ${limit})`;
      return rows.map(boardRow);
    },
    async myRank(hash) {
      const [row] = await sql`select * from my_rank(${hash})`;
      return row ? boardRow(row) : null;
    },
    async myRuns(hash) {
      const rows = await sql`select * from my_runs(${hash})`;
      return rows.map((row) => ({
        runId: row.run_id,
        startedAt: epochSeconds(row.started_at),
        finishedAt: row.finished_at === null ? null : epochSeconds(row.finished_at),
        realSeconds: optionalNumber(row.real_seconds),
        playedSeconds: optionalNumber(row.played_seconds),
        name: row.name,
        nameStatus: row.name_status,
        status: row.status,
      }));
    },
  };
}
