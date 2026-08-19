import { motion, useReducedMotion } from 'framer-motion';
import type { ReactNode } from 'react';

type PageTransitionProps = {
  children: ReactNode;
  className?: string;
};

export function PageTransition({ children, className }: PageTransitionProps) {
  const shouldReduceMotion = useReducedMotion();

  const motionProps = shouldReduceMotion
    ? {
        initial: { opacity: 0 },
        animate: { opacity: 1 },
        exit: { opacity: 0 },
        transition: { duration: 0.22, ease: 'easeInOut' as const }
      }
    : {
        initial: { opacity: 0, y: 12, scale: 0.99 },
        animate: { opacity: 1, y: 0, scale: 1 },
        exit: { opacity: 0, y: -8, scale: 0.99 },
        transition: {
          duration: 0.28,
          ease: [0.22, 1, 0.36, 1] as const
        }
      };

  return (
    <motion.div {...motionProps} className={className}>
      {children}
    </motion.div>
  );
}
