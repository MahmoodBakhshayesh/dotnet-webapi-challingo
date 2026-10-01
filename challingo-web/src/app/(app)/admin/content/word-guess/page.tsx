"use client";

import { useWordGuessContentController } from "@/features/puzzle-content/controllers/word-guess-content.controller";
import { WordGuessContentView } from "@/features/puzzle-content/views/word-guess-content.view";

export default function AdminWordGuessPage() {
  return <WordGuessContentView {...useWordGuessContentController()} />;
}
