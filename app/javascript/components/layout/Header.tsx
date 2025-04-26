import React from 'react';
// Import the ThemeToggle component
import { ThemeToggle } from '../ThemeToggle';

/**
 * @description Header component for the application layout.
 * Displays the site title and includes the theme toggle button at the far right.
 */
export const Header: React.FC = () => {
  // Return the header element
  return (
    // Header element with background colors for light/dark modes and padding
    // Light mode: Hacker News orange background
    // Dark mode: Elegant dark grey
    <header className="bg-[#ff6600] dark:bg-zinc-800 py-2 shadow-sm">
      {/* Container to center content and manage spacing */}
      <div className="w-full max-w-5xl mx-auto flex justify-between items-center px-2 sm:px-6">
        {/* Site Title */}
        {/* Light mode text: Black */}
        {/* Dark mode text: Light zinc */}
        <h1 className="text-black dark:text-zinc-100 text-sm sm:text-base font-bold">
          {/* Add link to homepage with the title */}
          <a href="/" className="hover:underline">hnsum</a>
        </h1>

        {/* Theme Toggle Button - Far right side of header */}
        <ThemeToggle />
      </div>
    </header>
  );
}; 