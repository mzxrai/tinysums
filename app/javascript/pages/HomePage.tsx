import React, { useMemo } from 'react';
// Import the StoryList component
import { StoryList } from '../components/StoryList';
// Import our stories and summaries hooks
import { useStories } from '../hooks/useStories';
import { useSummaries } from '../hooks/useSummaries';
import { HackerNewsStory } from '../types/HackerNews';

/**
 * @description The main page component for displaying the list of Hacker News stories.
 * Fetches story data and summaries from separate API endpoints and combines them.
 * Uses a matching placeholder structure to prevent jarring transitions.
 */
export const HomePage: React.FC = () => {
  // Fetch stories using our custom hook
  const {
    data: stories = [],
    isLoading: isStoriesLoading
  } = useStories();

  // Fetch summaries using our custom hook
  const { data: summaries = [] } = useSummaries();

  // Combine stories and their summaries
  const combinedStories = useMemo(() => {
    // Create a map of story IDs to summaries for quick lookup
    const summaryMap = new Map<number, HackerNewsStory>();
    if (summaries.length) {
      summaries.forEach((summary: HackerNewsStory) => {
        summaryMap.set(summary.id, summary);
      });
    }

    // Combine each story with its summary data if available
    return stories.map((story: HackerNewsStory) => {
      const summary = summaryMap.get(story.id);

      // If we don't have a summary, just return the story as is
      if (!summary) return story;

      // Return a merged story object with summary data
      return {
        ...story,
        // Add the summary data
        status: summary.status,
        contentSummary: summary.contentSummary,
        contentSummaryMeta: summary.contentSummaryMeta,
        commentsSummary: summary.commentsSummary,
        commentsSummaryMeta: summary.commentsSummaryMeta
      };
    });
  }, [stories, summaries]);

  // Always render the same container structure
  return (
    <div className="w-full min-h-screen bg-[#f6f6ef] dark:bg-zinc-950/95">
      {isStoriesLoading ? (
        // Empty placeholder with the same structure as StoryList
        <div className="w-full max-w-5xl mx-auto px-2 sm:px-6 py-4 sm:py-6">
          <div className="bg-transparent dark:bg-zinc-900 rounded-none dark:rounded-lg dark:shadow-md overflow-hidden ring-0 dark:ring-1 dark:ring-zinc-800">
            <ul className="divide-y divide-gray-200 dark:divide-zinc-800">
              {/* Invisible placeholder */}
            </ul>
          </div>
        </div>
      ) : (
        // Actual content when loaded
        <StoryList stories={combinedStories} />
      )}
    </div>
  );
}; 