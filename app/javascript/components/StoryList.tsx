import React from 'react';
import { HackerNewsStory } from '../types/HackerNews';
import { StorySummary } from './StorySummary';
import { SummaryProvider, useSummary } from '../contexts/SummaryContext';
import { extractHostname } from '../utils/urlUtils';

/**
 * Props for the StoryList component
 */
interface StoryListProps {
  /** Array of Hacker News stories to display */
  stories: HackerNewsStory[];
}

/**
 * Button component to expand or collapse all summaries 
 * Memoized to prevent unnecessary re-renders
 */
const ExpandCollapseAllButton: React.FC = React.memo(() => {
  // Get the summary context to control global expansion state
  // Using the refactored context hook
  const { expandAll, collapseAll, isAllExpanded } = useSummary();

  // Determine the current collective state
  const allCurrentlyExpanded = isAllExpanded();

  // Define the click handler
  const handleToggleClick = () => {
    // If all are currently expanded, call collapseAll
    if (allCurrentlyExpanded) {
      // Collapse all summaries
      collapseAll();
    } else {
      // Otherwise, expand all summaries
      expandAll();
    }
  };

  // Return the button element
  return (
    // Button element itself
    <button
      // Attach the click handler
      onClick={handleToggleClick}
      // Dynamic styling based on theme and interaction
      className="text-gray-700 bg-gray-200 dark:bg-zinc-800 dark:text-zinc-400 hover:bg-gray-300 dark:hover:bg-zinc-700 px-3 py-1 rounded-full text-xs font-medium cursor-pointer transition-colors shadow-sm"
    >
      {/* Dynamically set button text based on the current collective state */}
      {allCurrentlyExpanded ? 'Collapse All' : 'Expand All'}
    </button>
  );
});

/**
 * @description StoryList - A component that displays a list of Hacker News stories,
 * supporting both light (Hacker News style) and dark themes via Tailwind's dark: variant.
 */
export const StoryList: React.FC<StoryListProps> = ({ stories = [] }) => {
  // Add a log to see what props are actually received
  console.log('StoryList received stories:', stories);

  // Format the last updated time
  const getLastUpdatedTime = () => {
    if (!stories.length) return "N/A";

    // Find the most recent update time across all stories
    const latestTime = Math.max(
      ...stories
        .filter(story => story.status?.updatedAt)
        .map(story => story.status?.updatedAt || 0)
    );

    // Format the timestamp
    return latestTime > 0
      ? new Date(latestTime * 1000).toLocaleString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      })
      : "N/A";
  };

  // Check if stories is actually an array before trying to map
  if (!Array.isArray(stories)) {
    // Log an error if stories is not an array
    console.error('StoryList expected stories to be an array, but received:', typeof stories, stories);
    // Return null or an error message component to prevent the map error
    return <div className="text-red-500 p-4">Error: Invalid story data received.</div>;
  }

  // Wrap the content with the SummaryProvider
  return (
    <SummaryProvider>
      <div className="w-full">
        <div className="w-full max-w-5xl mx-auto px-2 sm:px-6 py-4 sm:py-6">
          {/* Header area with attribution and expand/collapse button */}
          <div className="flex justify-between items-center mb-4">
            <div className="flex items-center">
              <ExpandCollapseAllButton />
            </div>
            <div className="text-xs text-gray-500 dark:text-zinc-400 whitespace-nowrap">
              Summaries by <span className="font-bold">Gemini 2.5 Pro</span> | Last Updated {getLastUpdatedTime()}
            </div>
          </div>

          {/* Stories List Container */}
          {/* Light mode: Transparent background (inherits page bg), no ring */}
          {/* Dark mode: Dark background (darker than header), rounded corners, shadow, zinc ring */}
          <div className="bg-transparent rounded-none dark:rounded-lg dark:shadow-md overflow-hidden ring-0 dark:ring-1 dark:ring-zinc-800">
            {/* Unordered list to hold the individual story items */}
            {/* Light mode divider: Light gray (gray-200) */}
            {/* Dark mode divider: Darker zinc (zinc-800) */}
            <ul className="divide-y divide-gray-200 dark:divide-zinc-800">
              {/* Map over the stories array to render each story */}
              {/* Now guaranteed to be an array due to the check above */}
              {stories.map((story, index) => (
                // List item for each story
                <li
                  // Unique key for React list rendering optimization
                  key={story.id}
                  // Flex container for layout, padding adjusted for responsiveness
                  // Reduced padding compared to original for a tighter HN look
                  className="flex flex-col py-2 px-1 sm:px-2"
                >
                  <div className="flex">
                    {/* Story Rank */}
                    {/* Light mode text: HN gray (#828282) */}
                    {/* Dark mode text: Lighter zinc (zinc-500) */}
                    {/* Adjusted width, padding, font weight, and alignment for HN style */}
                    <span className="text-[#828282] dark:text-zinc-500 font-normal w-5 sm:w-6 text-right pr-1 sm:pr-1.5 pt-0.5 text-xs">
                      {/* Display the rank (index + 1) followed by a period */}
                      {index + 1}.
                    </span>

                    {/* Story Content container (takes remaining space) */}
                    <div className="flex-1">
                      {/* Story Title */}
                      {/* Adjusted font size and bottom margin for HN look */}
                      <h2 className="text-sm font-normal mb-0.5 leading-normal"> {/* HN uses normal weight for title */}
                        {/* Check if the story has an external URL */}
                        {story.url ? (
                          // Use React Fragment to group adjacent elements without adding a DOM node
                          <>
                            {/* Story Link to external URL */}
                            <a
                              // The URL of the story
                              href={story.url}
                              // Light mode text: Near black, hover underline
                              // Dark mode text: Light zinc (zinc-100), hover lighter zinc (zinc-300)
                              // Added transition for smooth color change
                              className="text-black dark:text-zinc-100 hover:underline dark:hover:text-zinc-300 transition-colors duration-150"
                            >
                              {/* The title text of the story */}
                              {story.title}
                            </a>

                            {/* Extract and display hostname if URL is external and valid */}
                            {/* Conditionally render the hostname span */}
                            {extractHostname(story.url) && (
                              // Hostname span
                              // Light/Dark mode text: HN gray (#828282) / zinc-500
                              // Reduced left margin for tighter spacing
                              <span className="text-[#828282] dark:text-zinc-500 ml-1 text-xs">
                                {/* Display hostname enclosed in parentheses */}
                                ({extractHostname(story.url)})
                              </span>
                            )}
                          </>
                          // If story.url is null or empty (e.g., Ask HN)
                        ) : (
                          /* Link to HN comments page if no external URL */
                          <a
                            // Construct URL for the Hacker News item page using story ID
                            href={`https://news.ycombinator.com/item?id=${story.id}`}
                            // Light mode text: Near black, hover underline
                            // Dark mode text: Light zinc (zinc-100), hover lighter zinc (zinc-300)
                            // Added transition for smooth color change
                            className="text-black dark:text-zinc-100 hover:underline dark:hover:text-zinc-300 transition-colors duration-150"
                          >
                            {/* The title text of the story */}
                            {story.title}
                          </a>
                        )}
                      </h2>

                      {/* Story Metadata Container */}
                      {/* Adjusted text size, gap, and default text color for HN style */}
                      <div className="text-xs flex flex-wrap gap-x-2 items-center text-[#828282] dark:text-zinc-500">
                        {/* Story Score */}
                        {/* Removed score icon for closer HN resemblance */}
                        {/* Dark mode text color adjusted */}
                        <span className="flex items-center dark:text-emerald-500">
                          {/* Score value */}
                          {/* Dark mode font weight adjusted */}
                          {/* Added " points" text for clarity */}
                          <span className="font-normal">{story.score} points</span>
                        </span>

                        {/* Separator */}
                        <span className="text-gray-400 dark:text-zinc-600">|</span>

                        {/* Author Link Container */}
                        <span className="flex items-center">
                          {/* "by" prefix - removed as HN doesn't explicitly use "by" here */}
                          {/* <span className="mr-1">by</span> */}
                          {/* Link to the author's HN user page */}
                          <a
                            // Construct URL for the HN user page using author's username
                            href={`https://news.ycombinator.com/user?id=${story.by}`}
                            // Light mode text: HN gray (#828282), hover underline
                            // Dark mode text: HN gray (zinc-500), hover light zinc (zinc-100)
                            // Added transition for smooth color change
                            className="text-[#828282] dark:text-zinc-500 hover:underline dark:hover:text-zinc-100 transition-colors duration-150"
                          >
                            {/* Author's username */}
                            {story.by}
                          </a>
                        </span>

                        {/* Separator */}
                        <span className="text-gray-400 dark:text-zinc-600">|</span>

                        {/* Story Time (if available) */}
                        {/* Conditionally render the time */}
                        {story.time && (
                          // Regular span for time, removed hover:underline class
                          <span className="text-[#828282] dark:text-zinc-500">
                            {/* TODO: Implement relative time formatting (e.g., "X hours ago") like HN */}
                            {/* Currently uses basic date formatting */}
                            {new Date(story.time * 1000).toLocaleDateString('en-US', {
                              // Short month name (e.g., "Apr")
                              month: 'short',
                              // Numeric day (e.g., "9")
                              day: 'numeric',
                              // Consider adding hour/minute formatting later for more precision
                            })}
                          </span>
                        )}

                        {/* Separator */}
                        <span className="text-gray-400 dark:text-zinc-600">|</span>

                        {/* Comments Link */}
                        {/* Removed comments icon for closer HN resemblance */}
                        <a
                          // Construct URL for the HN item page using story ID
                          href={`https://news.ycombinator.com/item?id=${story.id}`}
                          // Light mode text: HN gray (#828282), hover underline
                          // Dark mode text: HN gray (zinc-500), hover light zinc (zinc-100)
                          // Added transition for smooth color change
                          className="text-[#828282] dark:text-zinc-500 hover:underline dark:hover:text-zinc-100 transition-colors duration-150 flex items-center"
                        >
                          {/* Display number of comments, defaulting to 0 if undefined/null */}
                          {/* Added " comments" text */}
                          {story.descendants ?? 0} comments
                        </a>
                      </div>
                    </div>
                  </div>

                  {/* AI Summary Section */}
                  {/* Display the StorySummary component if either summary is available */}
                  {(story.story_summary || story.comments_summary || story.status) && (
                    <div className="ml-5 sm:ml-6">
                      <StorySummary
                        storySummary={story.story_summary}
                        commentsSummary={story.comments_summary}
                        status={story.status}
                        hasUrl={!!story.url}
                        index={index}
                        hnId={story.id}
                      />
                    </div>
                  )}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </SummaryProvider>
  );
  // End of component return
}; 