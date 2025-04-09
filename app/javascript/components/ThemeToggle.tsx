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
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="inline-block"
        >
          <path d="M12 3a6.364 6.364 0 0 0 9 9 9 9 0 1 1-9-9Z" />
        </svg>
      ) : (
        // Sun icon for light mode (shown in dark mode to indicate what you'll switch to)
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="inline-block"
        >
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2" />
          <path d="M12 20v2" />
          <path d="m4.93 4.93 1.41 1.41" />
          <path d="m17.66 17.66 1.41 1.41" />
          <path d="M2 12h2" />
          <path d="M20 12h2" />
          <path d="m6.34 17.66-1.41 1.41" />
          <path d="m19.07 4.93-1.41 1.41" />
        </svg>
      )}
    </button>
  );
}; 