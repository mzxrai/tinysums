import React, { useState, useMemo, useEffect, useCallback, Fragment } from 'react';
import { HackerNewsStory } from '../types/HackerNews';
import { StorySummary } from './StorySummary';
import { SummaryProvider } from '../contexts/SummaryContext';
import { extractHostname } from '../utils/urlUtils';
import { ChatBubbleLeftIcon } from '@heroicons/react/24/outline';

/**
 * @description Props for the StoryList component.
 * Defines the expected properties for the StoryList.
 */
interface StoryListProps {
  /**
   * @description Array of Hacker News stories to display.
   * Each object in the array should conform to the HackerNewsStory interface.
   */
  stories: HackerNewsStory[];
}

/**
 * @description StoryList component renders a feed of Hacker News stories.
 * Each story is displayed using the StoryCard component.
 * It includes error handling for invalid story data and wraps content in a SummaryProvider.
 * @param {StoryListProps} props - The props for the component.
 * @param {HackerNewsStory[]} [props.stories=[]] - An array of stories to render. Defaults to an empty array.
 * @returns {JSX.Element} The rendered list of stories or an error message.
 * @example
 * const stories = fetchStories();
 * return <StoryList stories={stories} />
 * @remarks This component is responsible for the overall feed structure.
 */
export const StoryList: React.FC<StoryListProps> = ({ stories = [] }) => {
  // Check if the received stories prop is actually an array.
  if (!Array.isArray(stories)) {
    // Log an error to the console if stories is not an array.
    console.error('StoryList expected stories to be an array, but received:', typeof stories, stories);
    // Return a user-friendly error message component.
    return <div className="text-red-500 p-4">Error: Invalid story data received.</div>;
  }

  // Return the main list structure.
  return (
    // Provide summary context to child components (StoryCard -> StorySummary).
    <SummaryProvider>
      {/* Container for the list, takes full width available. */}
      <div className="w-full">
        {/* Map over the stories array to render each story card. */}
        {stories.map((story, index) => (
          // Render the StoryCard component for each story.
          <StoryCard key={story.id} story={story} index={index} />
        ))}
      </div>
    </SummaryProvider>
  );
};

/**
 * Props for StoryCard component
 */
interface StoryCardProps {
  story: HackerNewsStory;
  index: number;
}

/**
 * @description Renders an individual story card with its metadata and summary.
 * Uses helper functions to format time and score, and potentially extracts a headline from the summary.
 * @param {StoryCardProps} props - The props for the component.
 * @param {HackerNewsStory} props.story - The Hacker News story data.
 * @param {number} props.index - The rank/index of the story in the list (0-based).
 * @returns {JSX.Element} The rendered story card.
 * @example
 * <StoryCard story={storyData} index={0} />
 * @remarks Encapsulates the presentation logic for a single story item in the feed.
 */
const StoryCard: React.FC<StoryCardProps> = ({ story, index }) => {

  /**
   * @description Formats a Unix timestamp into a human-readable relative time string.
   * Displays time as seconds (s), minutes (m), hours (h), days (d), or month/day for older posts.
   * @param {number} timestamp - The Unix timestamp (in seconds) to format.
   * @returns {string} The formatted relative time string (e.g., "5m", "2h", "3d", "Jan 15").
   * @example
   * const formatted = formatTime(1678886400); // Example timestamp
   * console.log(formatted); // Output depends on current time, e.g., "Mar 15" or "2d"
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
   * Returns "0" if the score is undefined. Currently does not use abbreviations (K/M).
   * @param {number | undefined} score - The score (number of upvotes) of the story.
   * @returns {string} The formatted score as a string.
   * @example
   * const formattedScore = formatScore(123); // Returns "123"
   * const formattedZero = formatScore(undefined); // Returns "0"
   */
  const formatScore = (score: number | undefined): string => {
    // Convert the score to a string, defaulting to 0 if score is undefined.
    return (score || 0).toString();
  };

  /**
   * @description Attempts to extract the first H1 or H2 heading from a Markdown string.
   * Looks for lines starting with '#' or '##' followed by space.
   * @param {string | undefined} markdown - The Markdown content to parse.
   * @returns {string | null} The text content of the first H1 or H2 heading found, or null if no heading is found or markdown is empty.
   * @example
   * const md = "# Main Title\\nSome text\\n## Subheading";
   * const heading = extractFirstMarkdownHeading(md); // Returns "Main Title"
   * const noHeading = extractFirstMarkdownHeading("Just text."); // Returns null
   */
  const extractFirstMarkdownHeading = (markdown?: string): string | null => {
    // If markdown is null, undefined, or empty, return null immediately.
    if (!markdown) {
      // Return null as no markdown content was provided.
      return null;
    }
    // Define the regex to match lines starting with optional whitespace, then '#' or '##' followed by required space,
    // capturing the heading text until the end of line or newline.
    // It looks for the start of a line (^), optional whitespace (\s*), then '#' or '##' (?:#|##),
    // then required whitespace (\s+), then captures one or more characters (.+?) until the end of the line ($) or a newline (\n).
    // The 'm' flag enables multiline matching.
    const match = markdown.match(/^\s*(?:#|##)\s+(.+?)($|\n)/m);
    // Check if a match was found.
    // If match is not null and has a captured group (match[1]), trim whitespace and return it. Otherwise, return null.
    return match ? match[1].trim() : null;
  };

  // Attempt to extract the first H1/H2 heading from the story summary.
  // Fall back to the original story title if no heading is found in the summary.
  const displayHeadline = extractFirstMarkdownHeading(story.story_summary) || story.title;

  // --- Prepare Metadata Items ---
  // Create an array to hold metadata elements that should be rendered.
  const metadataItems = [];

  // Add Score item (always present).
  metadataItems.push(
    <span className="flex items-center" key="score">
      {/* Upvote icon (chevron-up SVG). */}
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="mr-0 w-3 h-3 text-green-600">
        <path fillRule="evenodd" d="M14.77 12.79a.75.75 0 01-1.06 0L10 9.06l-3.71 3.71a.75.75 0 01-1.06-1.06l4.25-4.25a.75.75 0 011.06 0l4.25 4.25a.75.75 0 010 1.06z" clipRule="evenodd" />
      </svg>
      {/* Display the formatted score with green text. */}
      <span className="font-medium text-green-600">{formatScore(story.score)}</span>
    </span>
  );

  // Add Author item (always present).
  metadataItems.push(
    <span key="author">
      <a
        href={`https://news.ycombinator.com/user?id=${story.by}`}
        className="text-gray-600 hover:text-blue-700 transition-colors duration-150"
        onClick={(e) => e.stopPropagation()}
      >
        {story.by}
      </a>
    </span>
  );

  // Add Time item (always present, assuming story.time exists).
  metadataItems.push(
    <span key="time">
      {story.time ? formatTime(story.time) : ''}
    </span>
  );

  // Conditionally add Hostname item.
  const hostname = story.url ? extractHostname(story.url) : null;
  if (hostname) {
    metadataItems.push(
      <span className="text-gray-500" key="hostname">{hostname}</span>
    );
  }

  // Conditionally add Comments link item.
  if (typeof story.descendants === 'number') {
    metadataItems.push(
      <a
        href={`https://news.ycombinator.com/item?id=${story.id}`}
        className="flex items-center text-gray-600 hover:text-blue-700 transition-colors duration-150"
        onClick={(e) => e.stopPropagation()}
        key="comments"
      >
        {/* Display the count followed by the word "comments". Add a non-breaking space. */}
        {story.descendants}&nbsp;comments
      </a>
    );
  }
  // --- End Prepare Metadata Items ---

  // Return the JSX structure for the story card.
  return (
    // Article container for the story card with styling.
    <article className="px-4 py-4 mb-3 rounded-lg border border-gray-200 group">
      {/* Flex container for layout (rank + content). */}
      <div className="flex items-start space-x-3">
        {/* Container for the story rank number. */}
        <div className="w-6 text-right">
          {/* Display the rank (index + 1) with styling. */}
          <span className="text-sm text-gray-500">{index + 1}.</span>
        </div>

        {/* Main content area for the story details. */}
        <div className="flex-1 min-w-0">
          {/* Story title/headline section. Reverted to simple state. */}
          <h2 className="text-lg text-black font-semibold mb-1 leading-snug">
            {/* Anchor tag linking to the story URL or the HN item page. */}
            <a
              // Use story URL if available, otherwise link to HN comments page.
              href={story.url || `https://news.ycombinator.com/item?id=${story.id}`}
              // Remove target="_blank" and rel attributes to open in current tab.
              // Apply underline on hover. Removed truncation classes.
              className="hover:underline"
              // Prevent click event from bubbling up to the article container.
              onClick={(e) => e.stopPropagation()}
            >
              {/* Display the determined headline (either from summary or original title). */}
              {displayHeadline}
            </a>
            {/* Domain removed from here */}
          </h2>

          {/* Metadata section - Render items joined by pipes */}
          <div className="flex items-center text-sm text-gray-600 flex-wrap gap-x-3 mb-2">
            {/* Map over the visible metadata items. */}
            {metadataItems.map((item, index) => (
              // Use Fragment to handle key prop and conditional separator.
              <Fragment key={index}>
                {/* Render the metadata item itself. */}
                {item}
                {/* Render the pipe separator if it's not the last item. */}
                {index < metadataItems.length - 1 && (
                  <span className="text-gray-400">|</span>
                )}
              </Fragment>
            ))}
          </div>

          {/* Conditionally render the summary section. */}
          {/* Render this block if there is a story summary, comments summary, or a status. */}
          {(story.story_summary || story.comments_summary || story.status) && (
            // Container for the StorySummary component with slight top margin.
            <div className="mt-1">
              {/* Render the StorySummary component, passing relevant props. */}
              <StorySummary
                // Pass the story summary content.
                storySummary={story.story_summary}
                // Pass the comments summary content.
                commentsSummary={story.comments_summary}
                // Pass the status of the summary generation.
                status={story.status}
                // Pass a boolean indicating if the story has an external URL.
                hasUrl={!!story.url}
                // Pass the index of the story.
                index={index}
                // Pass the Hacker News ID of the story.
                hnId={story.id}
              />
            </div>
          )}
        </div>
      </div>
    </article>
  );
}; 