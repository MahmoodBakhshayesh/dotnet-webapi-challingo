/** Presentational: reads only `viewState` + invokes `actions`. */
"use client";

import { CalendarClock, ChevronLeft, ChevronRight, Play, Shuffle } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import type { ScheduleViewModel } from "@/features/competition-schedule/controllers/schedule.controller";
import {
  ChallengeKind,
  ChallengeState,
  type ScheduleEntryDto,
} from "@/features/competition-schedule/repositories/schedule.repository";
import { GAME_TITLES } from "@/features/puzzle-content/lib/crossword-layout";
import { selectClass } from "@/features/puzzle-content/views/content-ui";

const KIND_LABEL: Record<ChallengeKind, string> = {
  [ChallengeKind.Practice]: "Practice",
  [ChallengeKind.Daily]: "Daily puzzle",
  [ChallengeKind.Ranked]: "Ranked round",
  [ChallengeKind.Grand]: "Grand game",
};

const utcTime = (iso: string) => `${iso.slice(5, 10)} ${iso.slice(11, 16)}`;

function StateBadge({ entry }: { entry: ScheduleEntryDto }) {
  if (entry.finalized) return <Badge variant="outline">Finalized</Badge>;
  switch (entry.state) {
    case ChallengeState.Open:
      return <Badge>Open</Badge>;
    case ChallengeState.Closed:
      return <Badge variant="secondary">Closing…</Badge>;
    default:
      return <Badge variant="secondary">Upcoming</Badge>;
  }
}

export function ScheduleView({ viewState, actions, pending }: ScheduleViewModel) {
  const gameOptions = viewState.games.length ? viewState.games : Object.keys(GAME_TITLES);
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex items-start gap-3">
          <CalendarClock className="mt-1 size-6 opacity-80" />
          <div>
            <h1 className="text-2xl font-bold tracking-tight">Schedule</h1>
            <p className="text-muted-foreground text-sm">
              Six ranked rounds a day (UTC), a daily puzzle per local date, the Grand Challenge on Sundays. Puzzles can be swapped until they open.
            </p>
          </div>
        </div>
        <Button variant="outline" disabled={pending.run} onClick={actions.run}>
          <Play className="size-4" />
          {pending.run ? "Running…" : "Run jobs now"}
        </Button>
      </div>

      <Card>
        <CardContent className="flex flex-wrap items-center gap-2 pt-6">
          <Button variant="outline" size="icon" aria-label="Previous day" onClick={actions.previousDay}>
            <ChevronLeft className="size-4" />
          </Button>
          <Input type="date" className="w-44" aria-label="UTC date" value={viewState.date} onChange={(e) => e.target.value && actions.setDate(e.target.value)} />
          <Button variant="outline" size="icon" aria-label="Next day" onClick={actions.nextDay}>
            <ChevronRight className="size-4" />
          </Button>
          <Button variant="ghost" onClick={actions.today}>
            Today
          </Button>
          <span className="text-muted-foreground ml-auto text-sm">{viewState.isSunday ? "Sunday: Grand Challenge" : "All times UTC"}</span>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{viewState.date}</CardTitle>
          <CardDescription>
            {viewState.entries.length} scheduled {viewState.entries.length === 1 ? "challenge" : "challenges"}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {viewState.error ? <p className="text-destructive text-sm">{viewState.error}</p> : null}
          {viewState.loading ? <p className="text-muted-foreground text-sm">Loading…</p> : null}
          {!viewState.loading && !viewState.error && viewState.entries.length === 0 ? (
            <p className="text-muted-foreground text-sm">Nothing scheduled for this date yet. The Worker plans 8 days ahead; “Run jobs now” fills gaps.</p>
          ) : null}
          {viewState.entries.length ? (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="text-muted-foreground text-left">
                  <tr className="border-b">
                    <th className="py-2 pr-3 font-medium">Slot</th>
                    <th className="py-2 pr-3 font-medium">Game</th>
                    <th className="py-2 pr-3 font-medium">Opens</th>
                    <th className="py-2 pr-3 font-medium">Closes</th>
                    <th className="py-2 pr-3 font-medium">State</th>
                    <th className="py-2 pr-3 text-right font-medium">Players</th>
                    <th className="py-2 font-medium">
                      <span className="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {viewState.entries.map((e) => {
                    const editable = e.state === ChallengeState.Upcoming && e.attempts === 0;
                    const busy = pending.swapId === e.challengeId;
                    return (
                      <tr key={e.challengeId} className="border-b last:border-0">
                        <td className="py-2 pr-3">
                          <div className="font-medium">
                            {KIND_LABEL[e.kind]}
                            {e.kind === ChallengeKind.Daily ? "" : ` ${e.sequence}`}
                          </div>
                          <div className="text-muted-foreground text-xs">{e.slotKey}</div>
                        </td>
                        <td className="py-2 pr-3">
                          {editable ? (
                            <select
                              className={selectClass}
                              aria-label={`Game for ${e.slotKey}`}
                              value={e.gameKey}
                              disabled={busy}
                              onChange={(ev) => actions.swap(e.challengeId, ev.target.value)}
                            >
                              {gameOptions.map((g) => (
                                <option key={g} value={g}>
                                  {GAME_TITLES[g] ?? g}
                                </option>
                              ))}
                            </select>
                          ) : (
                            <span>{GAME_TITLES[e.gameKey] ?? e.gameKey}</span>
                          )}
                          <span className="text-muted-foreground ml-2 text-xs">d{e.difficulty}</span>
                        </td>
                        <td className="py-2 pr-3 tabular-nums">{utcTime(e.opensAtUtc)}</td>
                        <td className="py-2 pr-3 tabular-nums">{utcTime(e.closesAtUtc)}</td>
                        <td className="py-2 pr-3">
                          <StateBadge entry={e} />
                        </td>
                        <td className="py-2 pr-3 text-right tabular-nums">{e.attempts}</td>
                        <td className="py-2 text-right">
                          {editable ? (
                            <Button variant="ghost" size="sm" disabled={busy} onClick={() => actions.swap(e.challengeId, null)} title="New random game">
                              <Shuffle className="size-4" />
                              <span className="sr-only">Swap {e.slotKey} for a random game</span>
                            </Button>
                          ) : null}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          ) : null}
        </CardContent>
      </Card>
    </div>
  );
}
