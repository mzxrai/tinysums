import { HackerNewsStory } from '../types/HackerNews';

/**
 * Fetches the list of top Hacker News stories from the API
 * @returns Promise that resolves to an array of HackerNewsStory objects
 */
export const fetchStories = async (): Promise<HackerNewsStory[]> => {
  // Get CSRF token from meta tag for Rails authenticity
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';

  try {
    // Fetch the stories from the API
    const response = await fetch('/api/stories', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      }
    });

    // Handle HTTP errors
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }

    // Parse and return the response JSON
    return await response.json() as HackerNewsStory[];
  } catch (error) {
    console.error('Error fetching stories:', error);
    throw error;
  }
}; 