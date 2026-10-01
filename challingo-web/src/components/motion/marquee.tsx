"use client"

import { type ReactNode } from "react"
import { cn } from "@/lib/utils"

type MarqueeProps = {
  children: ReactNode
  className?: string
  /** Seconds for one full loop. Slower = calmer. */
  duration?: number
  reverse?: boolean
  pauseOnHover?: boolean
}

/** Duplicates its children once for a seamless CSS-driven loop — pass one row's worth of items as children. */
export function Marquee({ children, className, duration = 30, reverse = false, pauseOnHover = true }: MarqueeProps) {
  return (
    <div className={cn("group flex overflow-hidden [--gap:2rem]", className)}>
      {[0, 1].map((i) => (
        <div
          key={i}
          aria-hidden={i === 1}
          className={cn(
            "flex shrink-0 items-center gap-[var(--gap)] pr-[var(--gap)] motion-safe:animate-[marquee_var(--marquee-duration)_linear_infinite]",
            reverse && "[animation-direction:reverse]",
            pauseOnHover && "group-hover:[animation-play-state:paused]"
          )}
          style={{ ["--marquee-duration" as string]: `${duration}s` }}
        >
          {children}
        </div>
      ))}
    </div>
  )
}
