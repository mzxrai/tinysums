import { HackerNewsStory } from '../types/HackerNews';

/**
 * Response format directly from the /api/summaries endpoint
 * The backend uses snake_case naming convention for its JSON properties
 */
interface SummariesResponse {
  summaries: Array<{
    id: number;
    title: string;
    url: string | null;
    by: string;
    score: number;
    time: number;
    descendants: number;
    status?: {
      content: string;
      comments: string;
      updated_at: number;
    };
    content_summary?: string;
    content_summary_meta?: {
      generated_at: number;
      word_count: number;
      character_count: number;
    };
    comments_summary?: string;
    comments_summary_meta?: {
      generated_at: number;
      word_count: number;
      character_count: number;
    };
  }>;
}

/**
 * Transforms a snake_case key to camelCase
 * @param key - The snake_case string to transform
 * @returns The camelCase version of the input string
 * @example
 * toCamelCase("content_summary") // returns "contentSummary"
 */
const toCamelCase = (key: string): string => {
  // Replace any instance of underscore followed by a letter with the uppercase version of that letter
  return key.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
};

/**
 * Recursively transforms an object with snake_case keys to camelCase
 * @param obj - The object to transform
 * @returns A new object with all keys transformed to camelCase, including nested objects and arrays
 * @remarks
 * This function handles nested objects and arrays recursively.
 * Only string keys are transformed, and the original values are preserved.
 * @example
 * transformKeysToCamelCase({ content_summary: "text", status: { updated_at: 123 } })
 * // returns { contentSummary: "text", status: { updatedAt: 123 } }
 */
const transformKeysToCamelCase = <T extends object>(obj: T): any => {
  // Handle arrays by mapping over each item and recursively transforming objects
  if (Array.isArray(obj)) {
    return obj.map(item => {
      // Only transform objects, leave primitive values as-is
      if (typeof item === 'object' && item !== null) {
        return transformKeysToCamelCase(item);
      }
      return item;
    });
  }

  // For regular objects, transform each key-value pair
  return Object.entries(obj).reduce((acc, [key, value]) => {
    // Convert the current key from snake_case to camelCase
    const camelKey = toCamelCase(key);
    let camelValue = value;

    // If the value is an object or array, recursively transform it
    if (typeof value === 'object' && value !== null) {
      camelValue = transformKeysToCamelCase(value);
    }

    // Add the transformed key-value pair to the result object
    return { ...acc, [camelKey]: camelValue };
  }, {});
};

/**
 * Fetches summaries for top Hacker News stories from the API
 * @returns Promise that resolves to an array of HackerNewsStory objects with summary data
 * @remarks
 * This function handles the conversion from the snake_case API response
 * to the camelCase format used throughout the frontend codebase.
 */
export const fetchSummaries = async (): Promise<HackerNewsStory[]> => {
  // Get CSRF token from meta tag for Rails authenticity
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';

  try {
    // Fetch the summaries from the API
    const response = await fetch('/api/summaries', {
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

    // Parse the response JSON
    const data = await response.json() as SummariesResponse;

    // Extract summaries array from the response and transform to camelCase
    // This ensures consistency with JavaScript/TypeScript naming conventions
    return data.summaries.map(summary => transformKeysToCamelCase(summary)) as HackerNewsStory[];
  } catch (error) {
    console.error('Error fetching summaries:', error);
    throw error;
  }
}; 