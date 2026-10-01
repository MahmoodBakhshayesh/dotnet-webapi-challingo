/** Small presentational pieces shared by the content screens. */
"use client";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ContentStatus } from "@/features/puzzle-content/repositories/puzzle-content.repository";
import { cn } from "@/lib/utils";

export function StatusBadge({ status }: { status: ContentStatus }) {
  switch (status) {
    case ContentStatus.Approved:
      return <Badge>Approved</Badge>;
    case ContentStatus.Retired:
      return <Badge variant="outline">Retired</Badge>;
    default:
      return <Badge variant="secondary">Draft</Badge>;
  }
}

const FILTERS: { label: string; value: ContentStatus | undefined }[] = [
  { label: "All", value: undefined },
  { label: "Drafts", value: ContentStatus.Draft },
  { label: "Approved", value: ContentStatus.Approved },
  { label: "Retired", value: ContentStatus.Retired },
];

export function StatusFilter({ value, onChange }: { value: ContentStatus | undefined; onChange: (v: ContentStatus | undefined) => void }) {
  return (
    <div role="group" aria-label="Filter by status" className="bg-muted inline-flex rounded-lg p-1">
      {FILTERS.map((f) => (
        <button
          key={f.label}
          type="button"
          aria-pressed={value === f.value}
          onClick={() => onChange(f.value)}
          className={cn(
            "rounded-md px-3 py-1 text-sm font-medium transition-colors",
            value === f.value ? "bg-background shadow-sm" : "text-muted-foreground hover:text-foreground",
          )}
        >
          {f.label}
        </button>
      ))}
    </div>
  );
}

export function ReviewActions({
  status,
  disabled,
  onApprove,
  onRetire,
}: {
  status: ContentStatus;
  disabled: boolean;
  onApprove: () => void;
  onRetire: () => void;
}) {
  return (
    <div className="flex justify-end gap-2">
      {status !== ContentStatus.Approved ? (
        <Button size="sm" disabled={disabled} onClick={onApprove}>
          Approve
        </Button>
      ) : null}
      {status !== ContentStatus.Retired ? (
        <Button size="sm" variant="outline" disabled={disabled} onClick={onRetire}>
          Retire
        </Button>
      ) : null}
    </div>
  );
}

export const selectClass =
  "border-input bg-background focus-visible:ring-ring/50 h-9 rounded-md border px-3 text-sm outline-none focus-visible:ring-[3px]";
