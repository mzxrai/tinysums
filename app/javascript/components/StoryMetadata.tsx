import React, { Fragment } from 'react';
// Import utility for extracting hostname
import { extractHostname } from '../utils/urlUtils';

/**
 * @description Props for the StoryMetadata component.
 * Defines the data needed to render the metadata line for a story.
 */
interface StoryMetadataProps {
  /** @description The Hacker News ID of the story. */
  storyId: number;
  /** @description The score (upvotes) of the story. */
  score?: number;
  /** @description The username of the story author. */
  author: string;
  /** @description The Unix timestamp (seconds) when the story was posted. */
  time?: number;
  /** @description The number of comments on the story. */
  commentCount?: number;
  /** @description The optional external URL of the story. */
  url?: string;
}

/**
 * @description A reusable component to display the standard metadata line for a Hacker News story.
 * Includes score, author, time, hostname (if applicable), and comment link.
 * Mirrors the styling and logic originally found in StoryList.tsx.
 * 
 * @param {StoryMetadataProps} props - The props for the component.
 * @returns {JSX.Element} The rendered metadata line.
 * @example
 * <StoryMetadata 
 *   storyId={123} 
 *   score={100} 
 *   author="pg" 
 *   time={1678886400} 
 *   commentCount={50} 
 *   url="https://example.com" 
 * />
 */
export const StoryMetadata: React.FC<StoryMetadataProps> = ({
  // Destructure props
  storyId,
  score,
  author,
  time,
  commentCount,
  url
}) => {

  /**
   * @description Formats a Unix timestamp into a human-readable relative time string.
   * Displays time as seconds (s), minutes (m), hours (h), days (d), or month/day for older posts.
   * @param {number} timestamp - The Unix timestamp (in seconds) to format.
   * @returns {string} The formatted relative time string (e.g., "5m", "2h", "3d", "Jan 15").
   */
  const formatTime = (timestamp: number): string => {
    // Get the current date and time.
    const now = new Date();
    // Convert the Unix timestamp (seconds) to milliseconds and create a Date object.
    const postTime = new Date(timestamp * 1000);
    // Calculate the difference in milliseconds between now and the post time.
    const diffMs = now.getTime() - postTime.getTime();
    // Convert the difference to seconds.
    const diffSecs = Math.round(diffMs / 1000);
    // Convert the difference to minutes.
    const diffMins = Math.round(diffMs / 60000);
    // Convert the difference to hours.
    const diffHours = Math.round(diffMs / 3600000);
    // Convert the difference to days.
    const diffDays = Math.round(diffMs / 86400000);

    // If the difference is less than 60 seconds, return in seconds.
    if (diffSecs < 60) {
      // Return formatted time string in seconds.
      return `${diffSecs}s`;
    }
    // If the difference is less than 60 minutes, return in minutes.
    if (diffMins < 60) {
      // Return formatted time string in minutes.
      return `${diffMins}m`;
    }
    // If the difference is less than 24 hours, return in hours.
    if (diffHours < 24) {
      // Return formatted time string in hours.
      return `${diffHours}h`;
    }
    // If the difference is less than 7 days, return in days.
    if (diffDays < 7) {
      // Return formatted time string in days.
      return `${diffDays}d`;
    }
    // Otherwise, return the date in 'Month Day' format (e.g., "Apr 10").
    return postTime.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  };

  /**
   * @description Formats the story score into a string.
   * Returns "0" if the score is undefined.
   * @param {number | undefined} scoreValue - The score (number of upvotes) of the story.
   * @returns {string} The formatted score as a string.
   */
  const formatScore = (scoreValue: number | undefined): string => {
    // Convert the score to a string, defaulting to 0 if score is undefined.
    return (scoreValue || 0).toString();
  };

  // --- Prepare Metadata Items ---
  // Create an array to hold metadata elements that should be rendered.
  const metadataItems = [];

  // 1. Add Score item (always present).
  metadataItems.push(
    // Span container for score, aligned vertically
    <span className="flex items-center" key="score">
      {/* Upvote icon (chevron-up SVG) with specific styling */}
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="mr-0 w-3 h-3 text-green-600 dark:text-emerald-500">
        <path fillRule="evenodd" d="M14.77 12.79a.75.75 0 01-1.06 0L10 9.06l-3.71 3.71a.75.75 0 01-1.06-1.06l4.25-4.25a.75.75 0 011.06 0l4.25 4.25a.75.75 0 010 1.06z" clipRule="evenodd" />
      </svg>
      {/* Display the formatted score with specific text styling */}
      <span className="font-medium text-green-600 dark:text-emerald-500">{formatScore(score)}</span>
    </span>
  );

  // 2. Add Author item (always present).
  metadataItems.push(
    // Span container for author link
    <span key="author">
      {/* Link to the author's HN profile */}
      <a
        href={`https://news.ycombinator.com/user?id=${author}`}
        // Styling for the link, including hover and dark mode adjustments
        className="text-gray-600 dark:text-zinc-400 hover:text-blue-700 dark:hover:text-blue-400 transition-colors duration-150"
        // Prevent click event from propagating to parent elements (e.g., card)
        onClick={(e) => e.stopPropagation()}
        target="_blank" // Open in new tab
        rel="noopener noreferrer" // Security best practice
      >
        {/* Display the author's username */}
        {author}
      </a>
    </span>
  );

  // 3. Add Time item (always present, assuming time exists).
  metadataItems.push(
    // Span container for the formatted time
    <span key="time">
      {/* Display formatted time; render empty string if time is undefined */}
      {time ? formatTime(time) : ''}
    </span>
  );

  // 4. Conditionally add Hostname item.
  // Extract hostname from the URL using the utility function
  const hostname = url ? extractHostname(url) : null;
  // If a hostname was extracted:
  if (hostname) {
    // Add the hostname span to the metadata items array
    metadataItems.push(
      // Span container for the hostname with specific text styling
      <span className="text-gray-500 dark:text-zinc-500" key="hostname">
        {/* Display the extracted hostname */}
        {hostname}
      </span>
    );
  }

  // 5. Conditionally add Comments link item.
  // Check if commentCount is a number (including 0)
  if (typeof commentCount === 'number') {
    // Add the comments link anchor to the metadata items array
    metadataItems.push(
      // Link to the HN comments page for the story
      <a
        href={`https://news.ycombinator.com/item?id=${storyId}`}
        // Styling for the link, including hover and dark mode adjustments
        className="flex items-center text-gray-600 dark:text-zinc-400 hover:text-blue-700 dark:hover:text-blue-400 transition-colors duration-150"
        // Prevent click event propagation
        onClick={(e) => e.stopPropagation()}
        key="comments"
        target="_blank" // Open in new tab
        rel="noopener noreferrer" // Security best practice
      >
        {/* Display the comment count followed by the word "comments" */}
        {/* Use a non-breaking space (&nbsp;) for better text flow */}
        {commentCount}&nbsp;comments
      </a>
    );
  }
  // --- End Prepare Metadata Items ---

  // Return the container div rendering the metadata items.
  return (
    // Container div with flex layout, vertical alignment, wrapping, gap, and margin
    // Uses text style defaults appropriate for metadata
    <div className="flex items-center text-sm text-gray-600 dark:text-zinc-400 flex-wrap gap-x-3 mb-2">
      {/* Map over the collected metadata items. */}
      {metadataItems.map((item, index) => (
        // Use Fragment for key and conditional separator logic.
        <Fragment key={index}>
          {/* Render the actual metadata item (span or link). */}
          {item}
          {/* Render the pipe separator if it's not the last item in the array. */}
          {index < metadataItems.length - 1 && (
            // Pipe separator with specific styling
            <span className="text-gray-400 dark:text-zinc-600">|</span>
          )}
        </Fragment>
      ))}
    </div>
  );
}; 