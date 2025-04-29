import { useQuery } from '@tanstack/react-query';
import { fetchStories } from '../api/storiesApi';
import { HackerNewsStory } from '../types/HackerNews';

/**
 * @description Custom hook for fetching Hacker News stories
 * @returns Query object containing stories data with summaries when available, 
 *          loading state, error state, etc.
 * @remarks This hook fetches data from the /api/stories endpoint which includes
 *          story_summary and comments_summary properties when available
 */
export const useStories = () => {
  return useQuery<HackerNewsStory[], Error>({
    queryKey: ['stories'],
    queryFn: fetchStories,
    // Error handling
    retry: 2,
    // Refetch stories every 15 minutes to keep them somewhat fresh
    // The server caches them for an hour, but we want to check more frequently
    refetchInterval: 1000 * 60 * 15,
  });
};