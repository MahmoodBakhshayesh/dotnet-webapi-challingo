"use client"

import { useState, type ReactNode, useRef } from "react"
import { motion, useMotionValueEvent, useScroll } from "motion/react"
import { cn } from "@/lib/utils"

type Step = { id: string; label: ReactNode; content: ReactNode }

type ScrollStepsProps = {
  steps: Step[]
  className?: string
}

/**
 * A sticky rail of numbered steps on one side, with the active step highlighted as the matching
 * content scrolls through the viewport on the other side. Use for "how it works" / process sections.
 */
export function ScrollSteps({ steps, className }: ScrollStepsProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [active, setActive] = useState(0)
  const { scrollYProgress } = useScroll({ target: containerRef, offset: ["start center", "end center"] })

  useMotionValueEvent(scrollYProgress, "change", (progress) => {
    const index = Math.min(steps.length - 1, Math.floor(progress * steps.length))
    setActive(Math.max(0, index))
  })

  return (
    <div ref={containerRef} className={cn("grid gap-12 md:grid-cols-[minmax(0,280px)_1fr]", className)}>
      <div className="sticky top-24 hidden h-fit flex-col gap-4 md:flex">
        {steps.map((step, i) => (
          <div
            key={step.id}
            className={cn(
              "flex items-center gap-3 text-sm transition-opacity duration-300",
              i === active ? "opacity-100" : "opacity-40"
            )}
          >
            <span className="font-mono text-xs">{String(i + 1).padStart(2, "0")}</span>
            {step.label}
            {i === active ? (
              <motion.span layoutId="scroll-step-indicator" className="bg-primary ml-auto h-1.5 w-1.5 rounded-full" />
            ) : null}
          </div>
        ))}
      </div>
      <div className="flex flex-col gap-24">
        {steps.map((step) => (
          <div key={step.id} id={step.id}>
            {step.content}
          </div>
        ))}
      </div>
    </div>
  )
}
