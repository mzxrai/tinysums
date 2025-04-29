import React from 'react';
// Import the StoryList component
import { StoryList } from '../components/StoryList';
// Import our stories hook
import { useStories } from '../hooks/useStories';

/**
 * @description The main page component for displaying Hacker News stories.
 * Redesigned to match Twitter's light mode aesthetic, now single-column feed.
 * The header is now handled by the AppLayout component.
 */
export const HomePage: React.FC = () => {
  // Fetch stories using our custom hook
  const {
    data: stories = [],
    isLoading: isStoriesLoading
  } = useStories();

  // Return the page content
  // The outer div no longer needs min-h-screen as AppLayout handles it
  return (
    // Removed min-h-screen from this div
    <div>
      {/* Header: REMOVED - Now handled by AppLayout */}

      {/* Main content area for the home page */}
      {/* Max width and centering applied */}
      <main className="w-full max-w-3xl mx-auto">
        {/* Add indicator for content source */}
        {/* Describes the source and refresh rate of the data */}
        <p className="text-sm text-gray-600 dark:text-zinc-400 text-center mt-4 mb-4 px-4">
          {/* Content description */}
          HN top 30 summarized by gemini 2.5 pro | refreshes hourly
        </p>

        {/* Wrapper for stories feed */}
        {/* Padding adjusted for spacing */}
        <div className="pt-0 pb-6">
          {/* Conditional rendering based on loading state */}
          {isStoriesLoading ? (
            // Skeleton Loading UI
            // Displayed while stories are being fetched
            <div className="p-4 space-y-4">
              {/* Generate multiple skeleton items */}
              {Array.from({ length: 5 }).map((_, i) => (
                // Unique key for each skeleton item
                <div key={i} className="animate-pulse border-b border-gray-200 dark:border-zinc-700 pb-4">
                  {/* Flex container for skeleton layout */}
                  <div className="flex items-start space-x-3">
                    {/* Skeleton for rank number */}
                    {/* Positioned to approximate the rank alignment */}
                    <div className="w-6 text-right pr-1 pt-0.5">
                      {/* Placeholder block for rank */}
                      <div className="h-4 bg-gray-200 dark:bg-zinc-700 rounded w-4 inline-block"></div>
                    </div>
                    {/* Skeleton for story content */}
                    {/* Contains placeholders for title, metadata, and summary */}
                    <div className="flex-1 space-y-2 py-1">
                      {/* Skeleton for headline */}
                      <div className="h-5 bg-gray-200 dark:bg-zinc-700 rounded w-3/4"></div>
                      {/* Skeleton for metadata */}
                      <div className="h-3 bg-gray-200 dark:bg-zinc-600 rounded w-1/2"></div>
                      {/* Skeleton for summary box */}
                      <div className="h-24 bg-gray-200 dark:bg-zinc-700/50 rounded w-full mt-2"></div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            // Render actual StoryList component when data is available
            // Pass the fetched stories to the component
            <StoryList stories={stories} />
          )}
        </div>
      </main>

      {/* Right sidebar REMOVED */}

    </div>
  );
}; 