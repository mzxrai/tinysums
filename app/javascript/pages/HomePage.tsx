import React from 'react';
// Import the StoryList component
import { StoryList } from '../components/StoryList';
// Import our stories hook
import { useStories } from '../hooks/useStories';

/**
 * @description The main page component for displaying the list of Hacker News stories.
 * Fetches real data from the API using TanStack Query.
 */
export const HomePage: React.FC = () => {
  // Fetch stories using our custom hook
  const { data: stories, isLoading, error } = useStories();

  // Show loading state while stories are being fetched
  if (isLoading) {
    return (
      <div className="w-full min-h-screen bg-[#f6f6ef] dark:bg-zinc-950/95 flex items-center justify-center">
        <p className="text-black dark:text-zinc-100">Loading stories...</p>
      </div>
    );
  }

  // Show error message if stories couldn't be fetched
  if (error || !stories) {
    return (
      <div className="w-full min-h-screen bg-[#f6f6ef] dark:bg-zinc-950/95 flex items-center justify-center">
        <p className="text-red-600 dark:text-red-400">
          Error loading stories: {error?.message || 'Unknown error'}
        </p>
      </div>
    );
  }

  // Render the StoryList component with the stories
  return <StoryList stories={stories} />;
}; 