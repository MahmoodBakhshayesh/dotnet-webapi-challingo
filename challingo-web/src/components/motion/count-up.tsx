"use client"

import { useEffect, useRef, useState, type ReactNode } from "react"
import { useInView, useReducedMotion } from "motion/react"

type CountUpProps = {
  /** Final value to land on. */
  value: number
  /** Shown before the number (e.g. "$"). */
  prefix?: string
  /** Shown after the number (e.g. "+", "%"). */
  suffix?: string
  duration?: number
  decimals?: number
  className?: string
}

/** Counts up from 0 to `value` once it scrolls into view. Respects prefers-reduced-motion (jumps straight to value). */
export function CountUp({ value, prefix = "", suffix = "", duration = 1.4, decimals = 0, className }: CountUpProps) {
  const ref = useRef<HTMLSpanElement>(null)
  const inView = useInView(ref, { once: true, amount: 0.6 })
  const reduceMotion = useReducedMotion()
  const [display, setDisplay] = useState(0)

  useEffect(() => {
    if (!inView) return
    if (reduceMotion) {
      setDisplay(value)
      return
    }
    let raf: number
    const start = performance.now()
    const tick = (now: number) => {
      const t = Math.min((now - start) / (duration * 1000), 1)
      const eased = 1 - Math.pow(1 - t, 3) // ease-out cubic
      setDisplay(value * eased)
      if (t < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [inView, value, duration, reduceMotion])

  return (
    <span ref={ref} className={className}>
      {prefix}
      {display.toLocaleString(undefined, { minimumFractionDigits: decimals, maximumFractionDigits: decimals })}
      {suffix}
    </span>
  )
}

/** Wraps a row of stats so each <CountUp> starts together once the row is in view, not independently per-card. */
export function StatRow({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={className}>{children}</div>
}
