import React from 'react';
import { HackerNewsStory } from '../types/HackerNews';
import { StorySummary } from './StorySummary';

/**
 * Props for the StoryList component
 */
interface StoryListProps {
  /** Array of Hacker News stories to display */
  stories: HackerNewsStory[];
}

/**
 * Extracts the hostname from a URL string
 * @param url - The URL to extract the hostname from
 * @returns The extracted hostname or null if invalid
 * @remarks Returns null specifically for news.ycombinator.com to avoid displaying it,
 *          matching the behavior of Hacker News itself.
 */
const extractHostname = (url: string): string | null => {
  // Start of try block to handle potential URL parsing errors
  try {
    // Create a new URL object from the input string
    // This can throw an error if the URL string is malformed
    const parsedUrl = new URL(url);
    // Get the hostname property from the URL object
    const hostname = parsedUrl.hostname;
    // Check if the hostname is the Hacker News domain itself
    // Return null if it is, otherwise return the extracted hostname
    return hostname === 'news.ycombinator.com' ? null : hostname;
    // Catch any errors during URL parsing (e.g., TypeError for invalid URL)
  } catch (e) {
    // Log the error for debugging purposes (optional)
    // console.error("Invalid URL for hostname extraction:", url, e);
    // Return null if the URL is invalid or parsing fails, preventing component errors
    return null;
  }
  // End of function
};

/**
 * @description StoryList - A component that displays a list of Hacker News stories,
 * supporting both light (Hacker News style) and dark themes via Tailwind's dark: variant.
 */
export const StoryList: React.FC<StoryListProps> = ({ stories = [] }) => {
  // Add a log to see what props are actually received
  console.log('StoryList received stories:', stories);

  // Check if stories is actually an array before trying to map
  if (!Array.isArray(stories)) {
    // Log an error if stories is not an array
    console.error('StoryList expected stories to be an array, but received:', typeof stories, stories);
    // Return null or an error message component to prevent the map error
    return <div className="text-red-500 p-4">Error: Invalid story data received.</div>;
  }

  // Return the main div container for the story list
  return (
    // Main container div
    // Light mode background: HN orange-ish beige background (#f6f6ef)
    // Dark mode background: Near-black (zinc-950/95)
    <div className="w-full min-h-screen bg-[#f6f6ef] dark:bg-zinc-950/95">
      {/* Inner container for centering content and applying padding */}
      {/* Uses max-width for larger screens, padding adjusts for smaller screens */}
      <div className="w-full max-w-5xl mx-auto px-2 sm:px-6 py-4 sm:py-6">
        {/* Page Header - Removed as it's assumed to be in a separate layout header now */}
        {/* <h1 className="text-2xl font-semibold mb-6 text-zinc-800 dark:text-zinc-100">Stories</h1> */}

        {/* Stories List Container */}
        {/* Light mode: Transparent background (inherits page bg), no ring */}
        {/* Dark mode: Dark background (zinc-900), rounded corners, shadow, zinc ring */}
        <div className="bg-transparent dark:bg-zinc-900 rounded-none dark:rounded-lg dark:shadow-md overflow-hidden ring-0 dark:ring-1 dark:ring-zinc-800">
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
                  <span className="text-[#828282] dark:text-zinc-500 font-normal w-8 sm:w-10 text-right pr-1.5 sm:pr-2 pt-0.5 text-xs">
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
                {(story.contentSummary || story.commentSummary) && (
                  <div className="ml-8 sm:ml-10">
                    <StorySummary
                      contentSummary={story.contentSummary}
                      commentSummary={story.commentSummary}
                    />
                  </div>
                )}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  );
  // End of component return
}; 