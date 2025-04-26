/**
 * Retrieves the CSRF token from the page's meta tags
 * 
 * Rails adds a CSRF token in meta tags for security purposes.
 * This helper extracts that token for use in API requests to protect
 * against Cross-Site Request Forgery attacks.
 * 
 * @returns The CSRF token string, or an empty string if not found
 * 
 * @example
 * ```ts
 * const headers = {
 *   'Content-Type': 'application/json',
 *   'X-CSRF-Token': getCsrfToken()
 * };
 * ```
 */
export const getCsrfToken = (): string => {
  // Find the meta tag with name="csrf-token"
  const metaTag = document.querySelector('meta[name="csrf-token"]');

  // Extract the content attribute which contains the token
  // Return empty string if the meta tag doesn't exist
  return metaTag?.getAttribute('content') || '';
}; 