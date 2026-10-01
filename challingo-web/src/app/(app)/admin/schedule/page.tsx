"use client";

import { useScheduleController } from "@/features/competition-schedule/controllers/schedule.controller";
import { ScheduleView } from "@/features/competition-schedule/views/schedule.view";

export default function AdminSchedulePage() {
  return <ScheduleView {...useScheduleController()} />;
}
