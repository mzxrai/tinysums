import { useState, useEffect, useCallback } from 'react';

// Define possible theme values
type Theme = 'light' | 'dark';

// Key for storing theme preference in localStorage
const THEME_STORAGE_KEY = 'themePreference';

/**
 * @description Custom hook to manage application theme (light/dark).
 * It persists the theme choice to localStorage and applies/removes the 'dark' class
 * to the document's root element (`<html>`).
 *
 * @returns {{ theme: Theme, toggleTheme: () => void }} An object containing the current theme
 * and a function to toggle it.
 *
 * @example
 * const { theme, toggleTheme } = useTheme();
 * return <button onClick={toggleTheme}>Toggle Theme ({theme})</button>;
 *
 * @remarks
 * - Reads initial theme from localStorage or system preference (`prefers-color-scheme`).
 * - Defaults to 'light' if no preference is found.
 * - Updates the `<html>` element's class list and localStorage on theme change.
 */
export const useTheme = (): { theme: Theme; toggleTheme: () => void } => {
  // Initialize theme state
  // Read from localStorage first, then check system preference, finally default to 'light'
  const [theme, setTheme] = useState<Theme>(() => {
    // Check if window and localStorage are available (for SSR or testing environments)
    // This prevents errors during server-side rendering or in environments without a browser `window`
    if (typeof window !== 'undefined') {
      // Get theme from localStorage
      // Attempt to retrieve the previously saved theme preference
      const storedTheme = localStorage.getItem(THEME_STORAGE_KEY) as Theme | null;
      // If a theme is stored, use it
      // Check if a valid theme ('light' or 'dark') was retrieved
      if (storedTheme) {
        // Return the stored theme
        // Use the value found in localStorage
        return storedTheme;
      }
      // If no stored theme, check system preference
      // Check if the browser supports `window.matchMedia` for detecting system preferences
      if (window.matchMedia) {
        // Check if the user prefers dark mode at the OS level
        // `matches` property is true if the media query evaluates to true
        const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        // Return 'dark' if preferred, otherwise 'light'
        // Set the initial theme based on the system preference
        return prefersDark ? 'dark' : 'light';
      }
    }
    // Default to 'light' if localStorage or matchMedia is unavailable, or no preference set
    // This serves as a fallback if no other preference can be determined
    return 'light';
  });

  // Effect to apply the theme class to the HTML element and update localStorage
  // This runs after the component mounts and whenever the `theme` state changes
  useEffect(() => {
    // Get the root HTML element (the `<html>` tag)
    const root = window.document.documentElement;

    // Remove the opposite theme class // Deprecated for v4
    // root.classList.remove(theme === 'light' ? 'dark' : 'light');

    // Add the current theme class // Deprecated for v4
    // root.classList.add(theme);

    // Set the data-theme attribute instead for Tailwind v4
    root.setAttribute('data-theme', theme);

    // Try to save the theme preference to localStorage
    // This ensures the user's choice persists across sessions
    try {
      // Store the current theme value ('light' or 'dark')
      localStorage.setItem(THEME_STORAGE_KEY, theme);
      // Catch potential errors (e.g., localStorage full or unavailable in private browsing)
    } catch (error) {
      // Log an error if localStorage is not available or fails
      // Inform the developer about the issue without crashing the application
      console.error('Failed to save theme to localStorage:', error);
    }
    // Dependency array: run this effect only when the `theme` state variable changes
  }, [theme]);

  // Function to toggle the theme between 'light' and 'dark'
  // Memoized with useCallback to prevent unnecessary re-creations on re-renders
  const toggleTheme = useCallback(() => {
    // Update the theme state based on the current theme
    // If current theme is 'light', set to 'dark', otherwise set to 'light'
    setTheme((prevTheme) => (prevTheme === 'light' ? 'dark' : 'light'));
    // Empty dependency array means this function is created once and never changes
  }, []);

  // Return the current theme state and the memoized toggle function
  // This makes the theme state and toggle functionality available to the component using the hook
  return { theme, toggleTheme };
}; 