import React from 'react';
// Import the StoryList component
import { StoryList } from '../components/StoryList';
// Import our stories hook
import { useStories } from '../hooks/useStories';

/**
 * @description The main page component for displaying Hacker News stories.
 * Redesigned to match Twitter's light mode aesthetic, now single-column feed.
 */
export const HomePage: React.FC = () => {
  // Fetch stories using our custom hook
  const {
    data: stories = [],
    isLoading: isStoriesLoading
  } = useStories();

  return (
    <div className="min-h-screen">
      {/* Header: Now a dedicated branding bar */}
      <header className="sticky top-0 z-10 h-10 bg-white border-b border-gray-200 flex items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Left side: Brand Name */}
        <span className="text-lg font-semibold text-gray-800">
          <span className="font-semibold">tinysums</span> <span className="text-gray-500 text-xs">| tasty summaries for nerds on the go</span>
        </span>

        {/* Right side: Creator Credit */}
        <span className="text-sm text-gray-500">
          by{' '}
          <a
            href="https://github.com/mzxrai"
            target="_blank"
            rel="noopener noreferrer"
            className="text-gray-600 hover:text-blue-700 transition-colors duration-150"
          >
            @mzxrai
          </a>
        </span>
      </header>

      {/* Main content area */}
      <main className="w-full max-w-3xl mx-auto">
        {/* Add indicator for content source */}
        <p className="text-sm text-gray-600 text-center mt-4 mb-4 px-4">
          HN top 30, summarized by gemini-2.5-pro | refreshes hourly
        </p>

        {/* Wrapper for stories feed with padding, accounting for header */}
        {/* Added py-6 for vertical padding */}
        {/* Adjusted padding: removed py-6, added pt-0 pb-6. Use margin on indicator instead */}
        <div className="pt-0 pb-6">
          {isStoriesLoading ? (
            // Skeleton Loading
            <div className="p-4 space-y-4">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="animate-pulse border-b border-gray-200 pb-4">
                  <div className="flex items-start space-x-3">
                    {/* Kept skeleton structure */}
                    <div className="w-6 text-right pr-1 pt-0.5"> {/* Approximate rank positioning */}
                      <div className="h-4 bg-gray-200 rounded w-4 inline-block"></div>
                    </div>
                    <div className="flex-1 space-y-2 py-1">
                      <div className="h-5 bg-gray-200 rounded w-3/4"></div> {/* Headline */}
                      <div className="h-3 bg-gray-200 rounded w-1/2"></div> {/* Metadata */}
                      <div className="h-24 bg-gray-200 rounded w-full mt-2"></div> {/* Summary Box */}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            // Render actual StoryList
            <StoryList stories={stories} />
          )}
        </div>
      </main>

      {/* Right sidebar REMOVED */}

    </div>
  );
}; 