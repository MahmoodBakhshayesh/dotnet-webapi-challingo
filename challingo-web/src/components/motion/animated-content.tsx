"use client"

import type { ReactNode } from "react"
import { AnimatePresence, motion } from "motion/react"
import { cn } from "@/lib/utils"
import { EASE_OUT } from "@/lib/motion"

type Direction = "horizontal" | "vertical" | "fade"

const OFFSETS: Record<Direction, { x: number; y: number }> = {
  horizontal: { x: 16, y: 0 },
  vertical: { x: 0, y: 12 },
  fade: { x: 0, y: 0 },
}

type AnimatedContentProps = {
  /** Changes whenever the content identity changes (step id, tab value, field-group key, ...). */
  id: string | number
  children: ReactNode
  className?: string
  direction?: Direction
}

/**
 * Crossfades content when `id` changes and animates the container's height to match, so wizard
 * steps / tab panels / conditional field groups never hard-cut or jump the surrounding layout.
 */
export function AnimatedContent({ id, children, className, direction = "vertical" }: AnimatedContentProps) {
  const { x, y } = OFFSETS[direction]

  return (
    <motion.div layout transition={{ layout: { duration: 0.3, ease: EASE_OUT } }} className="overflow-hidden">
      <AnimatePresence mode="wait" initial={false}>
        <motion.div
          key={id}
          initial={{ opacity: 0, x, y }}
          animate={{ opacity: 1, x: 0, y: 0 }}
          exit={{ opacity: 0, x: -x, y: -y }}
          transition={{ duration: 0.25, ease: EASE_OUT }}
          className={cn(className)}
        >
          {children}
        </motion.div>
      </AnimatePresence>
    </motion.div>
  )
}
