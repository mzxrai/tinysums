import React from 'react';

/**
 * @description A component representing the application's header bar.
 * It displays branding information and creator credits.
 * This component is intended to be used within the main AppLayout.
 * 
 * @returns {React.ReactElement} The rendered header component.
 */
export const AppHeader: React.FC = () => {
  // Return the header structure
  return (
    // Header element: Sticky positioning, background, border, flex layout
    // Adjusted dark mode colors for better contrast/consistency
    <header className="sticky top-0 z-10 h-10 bg-white border-b border-gray-200 flex items-center justify-between after:absolute after:bottom-0 after:left-0 after:right-0 after:h-0.5 after:bg-gradient-to-r after:from-transparent after:via-[#ff9000] after:to-transparent after:content-['']">
      {/* Left side: Brand Name and Tagline */}
      {/* Added left padding here to prevent text touching the edge */}
      <span className="pl-4 text-lg font-semibold text-gray-800 dark:text-zinc-100">
        {/* Brand name itself */}
        <span className="font-semibold">tinysums</span>
        {/* Separator and tagline */}
        {/* Tagline provides a brief description of the app */}
        <span className="text-gray-500 dark:text-zinc-400 text-xs"> | tasty summaries for nerds on the go</span>
      </span>

      {/* Right side: Creator Credit Link */}
      {/* Added right padding here to prevent text touching the edge */}
      <span className="pr-4 text-sm text-gray-500 dark:text-zinc-400">
        {/* Introductory text */}
        by{' '}
        {/* Link to the creator's GitHub profile */}
        <a
          href="https://github.com/mzxrai"
          target="_blank"
          rel="noopener noreferrer"
          // Styling for the link, including hover effects and transitions
          // Ensures the link is visually distinct and interactive
          className="text-gray-600 dark:text-zinc-300 hover:text-blue-700 dark:hover:text-blue-400 transition-colors duration-150"
        >
          {/* The actual link text (GitHub handle) */}
          @mzxrai
        </a>
      </span>
    </header>
  );
}; 