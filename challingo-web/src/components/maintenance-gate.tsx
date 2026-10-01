"use client";

const maintenance =
  process.env.NEXT_PUBLIC_MAINTENANCE_MODE === "true" ||
  process.env.NEXT_PUBLIC_MAINTENANCE_MODE === "1";

export function MaintenanceGate({ children }: { children: React.ReactNode }) {
  if (!maintenance) return <>{children}</>;

  return (
    <div className="flex min-h-full flex-col items-center justify-center gap-4 p-8 text-center">
      <h1 className="text-2xl font-semibold">Maintenance</h1>
      <p className="max-w-md text-muted-foreground">
        The application is temporarily unavailable. Please try again later.
      </p>
    </div>
  );
}
