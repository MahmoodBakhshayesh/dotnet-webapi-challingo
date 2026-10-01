"use client";

import { useCrosswordContentController } from "@/features/puzzle-content/controllers/crossword-content.controller";
import { CrosswordContentView } from "@/features/puzzle-content/views/crossword-content.view";

export default function AdminCrosswordsPage() {
  return <CrosswordContentView {...useCrosswordContentController()} />;
}
