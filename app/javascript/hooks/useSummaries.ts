import { useQuery } from '@tanstack/react-query';
import { fetchSummaries } from '../api/summariesApi';
import { HackerNewsStory } from '../types/HackerNews';

/**
 * @description Custom hook for fetching Hacker News story summaries
 * @returns Query object containing stories with summary data, loading state, error state, etc.
 */
export const useSummaries = () => {
  return useQuery<HackerNewsStory[], Error>({
    queryKey: ['summaries'],
    queryFn: fetchSummaries,
    // Error handling
    retry: 2,
    // Refetch summaries every 15 minutes to keep them fresh
    refetchInterval: 1000 * 60 * 15,
  });
};
