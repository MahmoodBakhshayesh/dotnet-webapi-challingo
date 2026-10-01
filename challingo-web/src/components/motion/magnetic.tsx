"use client"

import { useRef, type ReactNode, type PointerEvent as ReactPointerEvent } from "react"
import { motion, useReducedMotion } from "motion/react"
import { cn } from "@/lib/utils"

type MagneticProps = {
  children: ReactNode
  className?: string
  /** How far the element can be pulled toward the pointer, in px. */
  strength?: number
}

/** Wrap a button/link/card to give it a subtle magnetic pull + radial glow toward the pointer on hover. */
export function Magnetic({ children, className, strength = 10 }: MagneticProps) {
  const ref = useRef<HTMLDivElement>(null)
  const reduceMotion = useReducedMotion()

  function handlePointerMove(e: ReactPointerEvent<HTMLDivElement>) {
    if (reduceMotion || !ref.current) return
    const rect = ref.current.getBoundingClientRect()
    const px = (e.clientX - rect.left) / rect.width
    const py = (e.clientY - rect.top) / rect.height
    const dx = (px - 0.5) * strength
    const dy = (py - 0.5) * strength
    ref.current.style.setProperty("--magnet-x", `${dx}px`)
    ref.current.style.setProperty("--magnet-y", `${dy}px`)
    ref.current.style.setProperty("--glow-x", `${px * 100}%`)
    ref.current.style.setProperty("--glow-y", `${py * 100}%`)
  }

  function handlePointerLeave() {
    if (!ref.current) return
    ref.current.style.setProperty("--magnet-x", "0px")
    ref.current.style.setProperty("--magnet-y", "0px")
  }

  return (
    <motion.div
      ref={ref}
      onPointerMove={handlePointerMove}
      onPointerLeave={handlePointerLeave}
      className={cn("magnetic-glow relative", className)}
      style={{ x: "var(--magnet-x, 0px)", y: "var(--magnet-y, 0px)" }}
      transition={{ type: "spring", stiffness: 150, damping: 15, mass: 0.1 }}
    >
      {children}
    </motion.div>
  )
}
