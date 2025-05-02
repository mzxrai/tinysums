import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

/**
 * @description Array of taglines to cycle through in the header.
 */
const taglines = [
  "| tasteful summaries for nerds on the go",
  "| appreciate you stopping by",
  "| basic idea is 5-min insights, less time-suck",
  "| turn HN fomo into 'meh, got the summary'",
  "| unrelated but legit impressed with gemini 2.5 pro",
  "| what about gpt4o though? idk man"
];

/**
 * @description Animation variants for the tagline switch effect.
 */
const taglineVariants = {
  // Initial state (before entering): positioned slightly below and faded out
  initial: { y: 10, opacity: 0 },
  // Animate state (when visible): positioned normally and fully visible
  animate: { y: 0, opacity: 1 },
  // Exit state (before leaving): positioned slightly above and faded out
  exit: { y: -10, opacity: 0 },
};

/**
 * @description Transition timing for the tagline animation.
 */
const taglineTransition = {
  duration: 0.3, // Duration of the animation in seconds
  ease: "easeOut", // Changed from easeInOut to potentially improve initial perceived smoothness
};

// --- Constants --- 
const TAGLINE_INTERVAL = 5000; // Milliseconds between tagline changes
const INITIAL_ANIMATION_DELAY = 200; // Milliseconds to wait before starting any timers

/**
 * @description A component representing the application's header bar.
 * It displays branding information and creator credits, with an animated tagline
 * that cycles through once.
 * This component is intended to be used within the main AppLayout.
 * 
 * @returns {React.ReactElement} The rendered header component.
 */
export const AppHeader: React.FC = () => {
  // State to keep track of the currently displayed tagline index
  const [currentIndex, setCurrentIndex] = useState(0);

  // State to track whether the animation sequence should be active (gates initial animation)
  const [isAnimationActive, setIsAnimationActive] = useState(false);

  // State to track if the first cycle of taglines has completed
  const [hasCompletedCycle, setHasCompletedCycle] = useState(false);

  // Effect for Animation Timing and Cycling Logic
  useEffect(() => {
    let activationTimeoutId: ReturnType<typeof setTimeout> | null = null;
    let intervalId: ReturnType<typeof setInterval> | null = null;

    // Delay initial setup slightly
    const initialDelayTimeoutId = setTimeout(() => {
      // Activate the animation presence after the first tagline duration
      activationTimeoutId = setTimeout(() => {
        setIsAnimationActive(true);
      }, TAGLINE_INTERVAL);

      // Start the interval to cycle through taglines
      intervalId = setInterval(() => {
        // Use functional update to get the latest state reliably
        setCurrentIndex((prevIndex) => {
          // Stop cycling if the cycle is complete
          // We check hasCompletedCycle directly from state, as it's stable within this interval's scope setup
          if (hasCompletedCycle) {
            // Returning prevIndex stops the update if condition met early
            return prevIndex;
          }

          // Calculate the next index
          const nextIndex = (prevIndex + 1) % taglines.length;

          // If the next index is 0, it means we've completed a cycle
          if (nextIndex === 0) {
            setHasCompletedCycle(true); // Mark cycle as complete
          }

          // Return the calculated next index to update the state
          return nextIndex;
        });
      }, TAGLINE_INTERVAL);

    }, INITIAL_ANIMATION_DELAY);

    // Cleanup function
    return () => {
      clearTimeout(initialDelayTimeoutId);
      if (activationTimeoutId) clearTimeout(activationTimeoutId);
      if (intervalId) clearInterval(intervalId);
    };
    // Rerun effect only if hasCompletedCycle changes (or on mount/unmount)
  }, [hasCompletedCycle]);

  // Return the header structure
  return (
    // Header element: Sticky positioning, background, border, flex layout
    // Added ::after pseudo-element for the gradient bar
    <header className="sticky top-0 z-10 h-10 bg-white border-b border-gray-200 flex items-center justify-between after:absolute after:bottom-0 after:left-0 after:right-0 after:h-0.5 after:bg-gradient-to-r after:from-transparent after:via-[#ff9000] after:to-transparent after:content-['']">
      {/* Left side: Brand Name and Animated Tagline */}
      {/* Added left padding here to prevent text touching the edge */}
      <span className="pl-4 text-lg font-semibold text-gray-800">
        {/* Brand name itself */}
        <span className="font-semibold">tinysums</span>

        {/* --- Tagline Container: Always rendered --- */}
        {/* Responsive width: w-0 by default, w-[300px] on sm+ screens */}
        <div className="inline-block relative ml-1 overflow-hidden align-middle h-4 w-0 sm:w-[300px]">
          {/* Conditionally render AnimatePresence only when animation is active */}
          {isAnimationActive ? (
            <AnimatePresence mode="wait">
              <motion.span
                key={currentIndex} // Key drives the animation
                className="absolute inset-0 text-gray-500 text-xs"
                variants={taglineVariants}
                initial="initial"
                animate="animate"
                exit="exit"
                transition={taglineTransition}
              >
                {taglines[currentIndex]}
              </motion.span>
            </AnimatePresence>
          ) : (
            // Render the first tagline statically before animation activates
            <motion.span
              key={currentIndex}
              className="absolute inset-0 text-gray-500 text-xs"
              initial={{ opacity: 1, y: 0 }}
              animate={{ opacity: 1, y: 0 }}
            >
              {taglines[currentIndex]}
            </motion.span>
          )}
        </div>
        {/* --- End Tagline Container --- */}
      </span>
    </header>
  );
}; 