/**
 * Extracts the hostname from a URL string
 * 
 * Parses a URL and returns just the hostname, excluding protocol, path, etc.
 * Returns null for invalid URLs or for news.ycombinator.com domains.
 * 
 * @param url - The URL to extract the hostname from
 * @returns The extracted hostname or null if invalid or filtered out
 * @example
 * ```ts
 * extractHostname('https://example.com/path') // 'example.com'
 * extractHostname('https://news.ycombinator.com') // null
 * extractHostname('invalid-url') // null
 * ```
 */
export const extractHostname = (url: string): string | null => {
  // Start of try block to handle potential URL parsing errors
  try {
    // Create a new URL object from the input string
    // This can throw an error if the URL string is malformed
    const parsedUrl = new URL(url);

    // Get the hostname property from the URL object
    const hostname = parsedUrl.hostname;

    // Check if the hostname is the Hacker News domain itself
    // Return null if it is, otherwise return the extracted hostname
    return hostname === 'news.ycombinator.com' ? null : hostname;

    // Catch any errors during URL parsing (e.g., TypeError for invalid URL)
  } catch (e) {
    // Return null if the URL is invalid or parsing fails
    return null;
  }
}; 