import { HackerNewsStory } from '../types/HackerNews';
import { getCsrfToken } from '../utils/csrf';

/**
 * Fetches the list of top Hacker News stories from the API
 * @returns Promise that resolves to an array of HackerNewsStory objects
 */
export const fetchStories = async (): Promise<HackerNewsStory[]> => {
  // Get CSRF token using our helper function
  const csrfToken = getCsrfToken();

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

/**
 * Fetches a single Hacker News story by its ID
 * 
 * This function makes an API request to fetch a specific story
 * and its associated summaries from the server.
 * 
 * @param hnId - The Hacker News ID of the story to fetch
 * @returns Promise that resolves to a single HackerNewsStory object
 * @throws Error if the API request fails or returns non-200 status
 */
export const fetchStoryById = async (hnId: number): Promise<HackerNewsStory> => {
  // Get CSRF token using our helper function
  const csrfToken = getCsrfToken();

  try {
    // Fetch the specific story from the API
    // The URL includes the story's HN ID, not its database ID
    const response = await fetch(`/api/stories/${hnId}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      }
    });

    // Handle HTTP errors - particularly important for 404s
    if (!response.ok) {
      // Different error message for 404 vs other errors
      if (response.status === 404) {
        throw new Error(`Story with ID ${hnId} not found`);
      }
      throw new Error(`HTTP error! Status: ${response.status}`);
    }

    // Parse and return the response JSON
    return await response.json() as HackerNewsStory;
  } catch (error) {
    // Log error for debugging purposes
    console.error(`Error fetching story ${hnId}:`, error);
    // Re-throw the error for the caller to handle
    throw error;
  }
}; 