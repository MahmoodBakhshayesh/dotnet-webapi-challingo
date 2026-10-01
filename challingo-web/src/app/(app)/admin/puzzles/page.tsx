"use client";

import { usePuzzlePreviewController } from "@/features/puzzle-content/controllers/puzzle-preview.controller";
import { PuzzlePreviewView } from "@/features/puzzle-content/views/puzzle-preview.view";

export default function AdminPuzzlePreviewPage() {
  return <PuzzlePreviewView {...usePuzzlePreviewController()} />;
}
