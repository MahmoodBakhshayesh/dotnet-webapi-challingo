"use client"

import { useRef, type ReactNode } from "react"
import { motion, useInView, useReducedMotion } from "motion/react"
import { fadeUp, staggerContainer } from "@/lib/motion"
import { cn } from "@/lib/utils"

type RevealProps = {
  children: ReactNode
  className?: string
  /** Animate direct children in sequence instead of this element as one block. Pair with <RevealItem>. */
  stagger?: boolean
  staggerDelay?: number
  /** Re-animate every time it re-enters the viewport instead of only once. */
  repeat?: boolean
  /** 0-1, how much of the element must be visible before it animates in. */
  amount?: number
}

/** Fades + slides content in as it scrolls into view. Use for every section below the hero. */
export function Reveal({
  children,
  className,
  stagger = false,
  staggerDelay = 0.1,
  repeat = false,
  amount = 0.3,
}: RevealProps) {
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, { once: !repeat, amount })
  const reduceMotion = useReducedMotion()

  return (
    <motion.div
      ref={ref}
      className={cn(className)}
      initial={reduceMotion ? false : "hidden"}
      animate={reduceMotion ? undefined : inView ? "show" : "hidden"}
      variants={stagger ? staggerContainer(staggerDelay) : fadeUp}
    >
      {children}
    </motion.div>
  )
}

/** Direct child of a staggered <Reveal stagger>; inherits the fadeUp timing from the parent. */
export function RevealItem({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <motion.div className={cn(className)} variants={fadeUp}>
      {children}
    </motion.div>
  )
}
