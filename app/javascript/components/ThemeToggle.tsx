import React from 'react';
// Import the theme hook
import { useTheme } from '../hooks/useTheme';

/**
 * @description A button component to toggle between light and dark themes.
 * Uses only an icon to indicate the current mode.
 *
 * @example
 * <ThemeToggle />
 */
export const ThemeToggle: React.FC = () => {
  // Use the theme hook to get the current theme and the toggle function
  const { theme, toggleTheme } = useTheme();

  // Return the button element
  return (
    // Button element with icon only
    <button
      // Call toggleTheme when the button is clicked
      onClick={toggleTheme}
      // Apply Tailwind classes for styling
      className="p-1.5 rounded-md text-xs transition-colors duration-150 \
                 focus:outline-none focus:ring-1 focus:ring-offset-1 focus:ring-sky-500 \
                 // Light mode styles (default)
                 bg-zinc-200 text-zinc-700 hover:bg-zinc-300 focus:ring-offset-white \
                 // Dark mode styles (applied when dark theme is active)
                 dark:bg-zinc-800 dark:text-zinc-300 dark:hover:bg-zinc-700 dark:focus:ring-offset-zinc-950"
      // Add accessible title for screen readers
      title={`Switch to ${theme === 'light' ? 'dark' : 'light'} mode`}
      aria-label={`Switch to ${theme === 'light' ? 'dark' : 'light'} mode`}
    >
      {/* Display appropriate icon based on current theme */}
      {theme === 'light' ? (
        // Moon icon for dark mode (shown in light mode to indicate what you'll switch to)
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" className="inline-block">
          <path d="M6 .278a.768.768 0 0 1 .08.858 7.208 7.208 0 0 0-.878 3.46c0 4.021 3.278 7.277 7.318 7.277.527 0 1.04-.055 1.533-.16a.787.787 0 0 1 .81.316.733.733 0 0 1-.031.893A8.349 8.349 0 0 1 8.344 16C3.734 16 0 12.286 0 7.71 0 4.266 2.114 1.312 5.124.06A.752.752 0 0 1 6 .278z" />
        </svg>
      ) : (
        // Sun icon for light mode (shown in dark mode to indicate what you'll switch to)
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" className="inline-block">
          <path d="M8 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM8 0a.5.5 0 0 1 .5.5v2a.5.5 0 0 1-1 0v-2A.5.5 0 0 1 8 0zm0 13a.5.5 0 0 1 .5.5v2a.5.5 0 0 1-1 0v-2A.5.5 0 0 1 8 13zm8-5a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1 0-1h2a.5.5 0 0 1 .5.5zM3 8a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1 0-1h2A.5.5 0 0 1 3 8zm10.657-5.657a.5.5 0 0 1 0 .707l-1.414 1.415a.5.5 0 1 1-.707-.708l1.414-1.414a.5.5 0 0 1 .707 0zm-9.193 9.193a.5.5 0 0 1 0 .707L3.05 13.657a.5.5 0 0 1-.707-.707l1.414-1.414a.5.5 0 0 1 .707 0zm9.193 2.121a.5.5 0 0 1-.707 0l-1.414-1.414a.5.5 0 0 1 .707-.707l1.414 1.414a.5.5 0 0 1 0 .707zM4.464 4.465a.5.5 0 0 1-.707 0L2.343 3.05a.5.5 0 1 1 .707-.707l1.414 1.414a.5.5 0 0 1 0 .708z" />
        </svg>
      )}
    </button>
  );
}; 