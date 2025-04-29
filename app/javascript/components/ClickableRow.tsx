import React from 'react';

/**
 * Props for the ClickableRow component
 */
interface ClickableRowProps {
  /** The URL to navigate to when clicking on empty space */
  discussionUrl: string;
  /** The row content */
  children: React.ReactNode;
  /** Additional CSS classes for the row */
  className?: string;
}

/**
 * ClickableRow - A React component that makes a row clickable to navigate to a discussion URL
 * while preserving the behavior of links within the row.
 */
export const ClickableRow: React.FC<ClickableRowProps> = ({
  discussionUrl,
  children,
  className = ''
}) => {
  const handleClick = (event: React.MouseEvent<HTMLLIElement>): void => {
    // Find if the click occurred on or within a link
    const target = event.target as HTMLElement;
    const link = target.closest('a');

    // If a link was clicked, do nothing (let the browser handle it)
    if (link) {
      return;
    }

    // Otherwise, navigate to the discussion URL
    window.location.href = discussionUrl;
  };

  return (
    <li
      className={`flex py-4 px-5 hover:bg-zinc-800 transition-colors duration-150 cursor-pointer ${className}`}
      onClick={handleClick}
    >
      {children}
    </li>
  );
}; 