import { useQuery } from '@tanstack/react-query';
import { fetchStoryById } from '../api/storiesApi';
import { HackerNewsStory } from '../types/HackerNews';

/**
 * Custom hook to fetch a single Hacker News story by its HN ID
 * 
 * This hook manages the query state for fetching an individual story,
 * including loading, error states, and data caching.
 * 
 * @param hnId - The Hacker News ID of the story to fetch
 * @returns Query object containing the story data and query status
 * 
 * @example
 * ```tsx
 * // In a component:
 * const { data: story, isLoading, error } = useSingleStory(12345);
 * 
 * if (isLoading) return <div>Loading...</div>;
 * if (error) return <div>Error loading story</div>;
 * if (!story) return <div>Story not found</div>;
 * 
 * return <div>{story.title}</div>;
 * ```
 */
export const useSingleStory = (hnId?: number) => {
  // Return the query object from TanStack Query
  // This provides loading state, error handling, caching, and data
  return useQuery<HackerNewsStory, Error>({
    // The query key includes both 'story' and the ID to identify this specific query
    // This ensures proper caching and invalidation
    queryKey: ['story', hnId],

    // The query function that actually fetches the data
    // The exclamation mark asserts that hnId is non-null when the function is called
    // This is safe because of the enabled option below
    queryFn: () => fetchStoryById(hnId!),

    // Only run the query if hnId is provided (not undefined or null)
    // This prevents unnecessary API calls when the ID is not available
    enabled: !!hnId,

    // Number of times to retry if the query fails
    retry: 2,

    // How long to consider data "fresh" before refetching (5 minutes)
    staleTime: 1000 * 60 * 5,

    // Refetch when the window regains focus (disabled to prevent unwanted refreshes)
    refetchOnWindowFocus: false,
  });
}; 