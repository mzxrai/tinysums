import React from 'react';
// Import the StoryList component
import { StoryList } from '../components/StoryList';
// Import our stories hook
import { useStories } from '../hooks/useStories';

/**
 * @description The main page component for displaying the list of Hacker News stories.
 * Fetches story data from the API, including summaries if available.
 * Uses a matching placeholder structure to prevent jarring transitions.
 */
export const HomePage: React.FC = () => {
  // Fetch stories using our custom hook
  const {
    data: stories = [],
    isLoading: isStoriesLoading
  } = useStories();

  // Always render the same container structure
  return (
    <div className="w-full min-h-screen bg-[#f6f6ef] dark:bg-zinc-900">
      <StoryList stories={stories} />
    </div >
  );
}; 