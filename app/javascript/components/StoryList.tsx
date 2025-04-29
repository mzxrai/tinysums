import React, { useState, useMemo, useEffect, useCallback, Fragment } from 'react';
import { HackerNewsStory } from '../types/HackerNews';
import { StorySummary } from './StorySummary';
import { SummaryProvider } from '../contexts/SummaryContext';
import { StoryMetadata } from './StoryMetadata';
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
  /** @description The Hacker News story data object. */
  story: HackerNewsStory;
  /** @description The rank/index of the story in the list (0-based). */
  index: number;
}

/**
 * @description Renders an individual story card with its metadata and summary.
 * Uses helper functions to format time and score, and potentially extracts a headline from the summary.
 * Metadata display is now delegated to the StoryMetadata component.
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
   * @description Attempts to extract the first H1 or H2 heading from a Markdown string.
   * Looks for lines starting with '#' or '##' followed by space.
   * @param {string | undefined} markdown - The Markdown content to parse.
   * @returns {string | null} The text content of the first H1 or H2 heading found, or null if no heading is found or markdown is empty.
   * @example
   * const md = "# Main Title\\nSome text\\n## Subheading";
   * const heading = extractFirstMarkdownHeading(md); // Returns "Main Title"
   * const noHeading = extractFirstMarkdownHeading("Just text."); // Returns null
   */
  const extractFirstMarkdownHeading = (markdown?: string): string | undefined => {
    // If markdown is null, undefined, or empty, return undefined immediately.
    if (!markdown) {
      // Return undefined as no markdown content was provided.
      return undefined;
    }
    // Define the regex to match lines starting with optional whitespace, then '#' or '##' followed by required space,
    // capturing the heading text until the end of line or newline.
    const match = markdown.match(/^\s*(?:#|##)\s+(.+?)($|\n)/m);
    // Check if a match was found.
    // If match is not null and has a captured group (match[1]), trim whitespace and return it.
    // Otherwise, return undefined.
    return match ? match[1].trim() : undefined;
  };

  // Attempt to extract the first H1/H2 heading from the story summary.
  // Fall back to the original story title if no heading is found in the summary.
  // Use nullish coalescing for a concise fallback.
  const displayHeadline: string = extractFirstMarkdownHeading(story.story_summary) ?? story.title ?? '[Untitled Story]';

  // Return the JSX structure for the story card.
  return (
    // Article container for the story card with styling.
    <article className="px-4 py-4 mb-3 rounded-lg border border-gray-200 dark:border-zinc-700 group">
      {/* Flex container for layout (rank + content). */}
      <div className="flex items-start space-x-3">
        {/* Container for the story rank number. */}
        <div className="w-6 text-right">
          {/* Display the rank (index + 1) with styling. */}
          <span className="text-sm text-gray-500 dark:text-zinc-500">{index + 1}.</span>
        </div>

        {/* Main content area for the story details. */}
        <div className="flex-1 min-w-0">
          {/* Story title/headline section. */}
          {/* Contains the main link to the story or HN page. */}
          <h2 className="text-lg text-black dark:text-zinc-100 font-semibold mb-1 leading-snug">
            {/* Anchor tag linking to the story URL or the HN item page. */}
            <a
              // Use story URL if available, otherwise link to HN comments page.
              href={story.url || `https://news.ycombinator.com/item?id=${story.id}`}
              // Apply hover effect.
              // Updated dark mode hover color.
              className="hover:underline dark:hover:text-zinc-300 transition-colors duration-150"
              // Prevent click event from bubbling up to the article container.
              onClick={(e) => e.stopPropagation()}
              target="_blank" // Keep target blank for external links
              rel="noopener noreferrer"
            >
              {/* Display the determined headline (either from summary or original title). */}
              {displayHeadline}
            </a>
          </h2>

          {/* Use the reusable StoryMetadata component */}
          {/* Pass all necessary props derived from the story object. */}
          <StoryMetadata
            storyId={story.id}
            score={story.score}
            author={story.by}
            time={story.time}
            commentCount={story.descendants}
            url={story.url ?? undefined}
          />

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