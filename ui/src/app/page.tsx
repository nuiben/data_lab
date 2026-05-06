"use client";

import { useCallback, useEffect, useState } from "react";

// ── Types ──────────────────────────────────────────────────────────────────

type ExecStatus = "RUNNING" | "SUCCEEDED" | "FAILED" | "TIMED_OUT" | "ABORTED";

interface Execution {
  executionArn: string;
  name: string;
  status: ExecStatus;
  startDate: string;
  stopDate?: string;
}

interface S3Object {
  Key: string;
  LastModified: string;
  Size: number;
}

// ── Domain config ──────────────────────────────────────────────────────────

const BUSINESS_LINES: Record<string, { tables: string[]; color: string; dot: string }> = {
  "P&S": {
    tables: ["merchant", "account", "txn", "settlement", "dispute"],
    color: "text-blue-400 border-blue-800 bg-blue-950/40",
    dot: "bg-blue-400",
  },
  FCC: {
    tables: ["fleet_customer", "card"],
    color: "text-amber-400 border-amber-800 bg-amber-950/40",
    dot: "bg-amber-400",
  },
  RUS: {
    tables: ["underwriting_decision", "risk_score", "partner"],
    color: "text-violet-400 border-violet-800 bg-violet-950/40",
    dot: "bg-violet-400",
  },
};

const STATUS_BADGE: Record<ExecStatus, string> = {
  RUNNING: "bg-sky-500/15 text-sky-400 ring-1 ring-sky-500/30 animate-pulse",
  SUCCEEDED: "bg-emerald-500/15 text-emerald-400 ring-1 ring-emerald-500/30",
  FAILED: "bg-red-500/15 text-red-400 ring-1 ring-red-500/30",
  TIMED_OUT: "bg-orange-500/15 text-orange-400 ring-1 ring-orange-500/30",
  ABORTED: "bg-slate-500/15 text-slate-400 ring-1 ring-slate-500/30",
};

// ── Helpers ────────────────────────────────────────────────────────────────

function duration(start: string, stop?: string): string {
  const ms = (stop ? new Date(stop) : new Date()).getTime() - new Date(start).getTime();
  const s = Math.floor(ms / 1000);
  return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m ${s % 60}s`;
}

function relative(iso: string): string {
  const min = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (min < 1) return "just now";
  if (min < 60) return `${min}m ago`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return `${hr}h ago`;
  return `${Math.floor(hr / 24)}d ago`;
}

function tableFromKey(key: string): string {
  return key.split("/")[1] ?? key;
}

function fmtBytes(n: number): string {
  return n >= 1024 * 1024
    ? `${(n / 1024 / 1024).toFixed(1)} MB`
    : `${(n / 1024).toFixed(1)} KB`;
}

// ── Component ──────────────────────────────────────────────────────────────

export default function Dashboard() {
  const [executions, setExecutions] = useState<Execution[]>([]);
  const [s3Objects, setS3Objects] = useState<S3Object[]>([]);
  const [loading, setLoading] = useState(true);
  const [triggering, setTriggering] = useState(false);
  const [lastTriggered, setLastTriggered] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    const [exRes, s3Res] = await Promise.all([
      fetch("/api/executions"),
      fetch("/api/exports"),
    ]);
    if (exRes.ok) setExecutions(await exRes.json());
    if (s3Res.ok) setS3Objects(await s3Res.json());
    setLoading(false);
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 15_000);
    return () => clearInterval(id);
  }, [refresh]);

  async function triggerRun() {
    setTriggering(true);
    const res = await fetch("/api/executions", { method: "POST" });
    if (res.ok) {
      const { name } = (await res.json()) as { name: string };
      setLastTriggered(name);
    }
    await refresh();
    setTriggering(false);
  }

  // Latest Parquet file per table (keyed by table name)
  const latestByTable = s3Objects.reduce<Record<string, S3Object>>((acc, obj) => {
    const table = tableFromKey(obj.Key);
    if (!acc[table] || new Date(obj.LastModified) > new Date(acc[table].LastModified)) {
      acc[table] = obj;
    }
    return acc;
  }, {});

  const last = executions[0];
  const succeeded = executions.filter((e) => e.status === "SUCCEEDED").length;
  const hasRunning = executions.some((e) => e.status === "RUNNING");

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 font-sans">

      {/* ── Header ─────────────────────────────────────────────────────── */}
      <header className="border-b border-slate-800 px-6 py-3 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded bg-indigo-600 flex items-center justify-center text-xs font-bold tracking-tighter">
              X
            </div>
            <span className="font-semibold text-slate-100 tracking-tight">XMOB</span>
            <span className="text-slate-700 select-none">·</span>
            <span className="text-slate-400 text-sm">Datalab</span>
          </div>
          <span className="hidden sm:block px-2 py-0.5 rounded text-xs font-mono bg-slate-800 text-slate-400 border border-slate-700">
            NYSE: XMOB
          </span>
        </div>
        <div className="flex items-center gap-3 text-xs text-slate-500">
          {hasRunning && (
            <span className="flex items-center gap-1.5 text-sky-400">
              <span className="w-1.5 h-1.5 rounded-full bg-sky-400 animate-pulse" />
              pipeline running
            </span>
          )}
          <span className="font-mono">auto-refresh 15s</span>
        </div>
      </header>

      <main className="px-6 py-8 mx-auto max-w-5xl space-y-8">

        {/* ── Stats ──────────────────────────────────────────────────────── */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {[
            { label: "Total Runs", value: loading ? "—" : String(executions.length) },
            {
              label: "Last Status",
              value: last ? last.status : "—",
              badge: last ? STATUS_BADGE[last.status] : undefined,
            },
            { label: "Succeeded", value: loading ? "—" : `${succeeded} / ${executions.length}` },
            { label: "Tables in S3", value: loading ? "—" : String(Object.keys(latestByTable).length) },
          ].map(({ label, value, badge }) => (
            <div key={label} className="bg-slate-900 border border-slate-800 rounded-xl p-4">
              <div className="text-xs uppercase tracking-widest text-slate-500 mb-2">{label}</div>
              {badge ? (
                <span className={`text-xs font-mono px-2 py-0.5 rounded-full ${badge}`}>{value}</span>
              ) : (
                <div className="text-2xl font-bold font-mono">{value}</div>
              )}
            </div>
          ))}
        </div>

        {/* ── Run trigger ────────────────────────────────────────────────── */}
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 flex flex-col sm:flex-row sm:items-center gap-4">
          <div className="flex-1">
            <div className="text-sm font-semibold mb-0.5">Export → Load Pipeline</div>
            <div className="text-xs text-slate-500">
              Postgres → S3 Parquet (export-step) → Snowflake (load-step)
              <span className="ml-2 font-mono text-slate-600">
                · replaces IWS job-stream <em>data-lab-export</em>
              </span>
            </div>
          </div>
          <button
            onClick={triggerRun}
            disabled={triggering}
            className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700 disabled:bg-slate-700 disabled:text-slate-500 text-white font-semibold text-sm px-5 py-2.5 rounded-lg transition-colors whitespace-nowrap"
          >
            {triggering ? (
              <>
                <span className="w-3.5 h-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                Starting…
              </>
            ) : (
              "▶ Run Pipeline"
            )}
          </button>
          {lastTriggered && (
            <span className="text-xs font-mono text-emerald-400 sm:ml-2">
              ✓ {lastTriggered}
            </span>
          )}
        </div>

        {/* ── Execution history ──────────────────────────────────────────── */}
        <section>
          <h2 className="text-xs font-semibold uppercase tracking-widest text-slate-500 mb-3">
            Recent Executions
          </h2>
          <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
            {loading ? (
              <div className="p-10 text-center text-slate-600 text-sm">Loading…</div>
            ) : executions.length === 0 ? (
              <div className="p-10 text-center text-slate-600 text-sm">
                No executions yet — run the pipeline to get started.
              </div>
            ) : (
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-800">
                    {["Execution name", "Status", "Started", "Duration"].map((h) => (
                      <th
                        key={h}
                        className="text-left px-5 py-3 text-xs uppercase tracking-wider text-slate-500 font-medium"
                      >
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {executions.map((ex, i) => (
                    <tr
                      key={ex.executionArn}
                      className={`hover:bg-slate-800/50 transition-colors ${i < executions.length - 1 ? "border-b border-slate-800/60" : ""}`}
                    >
                      <td className="px-5 py-3 font-mono text-xs text-slate-300 max-w-xs truncate">
                        {ex.name}
                      </td>
                      <td className="px-5 py-3">
                        <span className={`text-xs font-mono px-2 py-0.5 rounded-full ${STATUS_BADGE[ex.status]}`}>
                          {ex.status}
                        </span>
                      </td>
                      <td className="px-5 py-3 text-slate-400 font-mono text-xs">
                        {relative(ex.startDate)}
                      </td>
                      <td className="px-5 py-3 text-slate-400 font-mono text-xs">
                        {duration(ex.startDate, ex.stopDate)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </section>

        {/* ── S3 exports by business line ────────────────────────────────── */}
        <section>
          <h2 className="text-xs font-semibold uppercase tracking-widest text-slate-500 mb-3">
            S3 Exports by Business Line
          </h2>
          <div className="space-y-3">
            {Object.entries(BUSINESS_LINES).map(([line, { tables, color, dot }]) => (
              <div key={line} className={`border rounded-xl p-4 ${color}`}>
                <div className="flex items-center gap-2 mb-3">
                  <span className={`w-2 h-2 rounded-full ${dot}`} />
                  <span className="text-xs font-semibold uppercase tracking-widest">{line}</span>
                </div>
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-2">
                  {tables.map((table) => {
                    const obj = latestByTable[table];
                    return (
                      <div
                        key={table}
                        className={`rounded-lg p-3 bg-slate-950/50 border ${obj ? "border-slate-700" : "border-slate-800 opacity-50"}`}
                      >
                        <div className="font-mono text-xs text-slate-200 truncate mb-1">{table}</div>
                        {obj ? (
                          <>
                            <div className="text-xs text-slate-500">{relative(obj.LastModified)}</div>
                            <div className="text-xs text-slate-600 font-mono">{fmtBytes(obj.Size)}</div>
                          </>
                        ) : (
                          <div className="text-xs text-slate-600">not exported</div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        </section>

      </main>

      {/* ── Footer ─────────────────────────────────────────────────────── */}
      <footer className="border-t border-slate-800 mt-12 px-6 py-4 text-xs text-slate-700 flex justify-between">
        <span>XMOB &amp; Co. — Datalab initiative · Charlotte, NC</span>
        <span className="font-mono">data-lab-pipeline · Step Functions</span>
      </footer>
    </div>
  );
}
