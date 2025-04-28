import React, { useState, useMemo, useEffect, useCallback } from 'react';
import ReactMarkdown from 'react-markdown';
import rehypeSanitize, { defaultSchema } from 'rehype-sanitize';
import remarkGfm from 'remark-gfm';
import { useSummary } from '../contexts/SummaryContext';

/**
 * Create a custom sanitization schema that allows table elements
 * This extends the default schema to include all table-related tags
 */
const sanitizeSchema = {
  ...defaultSchema,
  attributes: {
    ...defaultSchema.attributes,
    // Allow all elements to have className, style
    '*': [...(defaultSchema.attributes?.['*'] || []), 'className', 'style']
  },
  // Add support for tables and related elements
  tagNames: [
    ...(defaultSchema.tagNames || []),
    'table', 'thead', 'tbody', 'tfoot', 'tr', 'th', 'td'
  ]
};

/**
 * Props for the StorySummary component
 */
interface StorySummaryProps {
  /** Summary of the story content */
  storySummary?: string;
  /** Summary of the comment section */
  commentsSummary?: string;
  /** Status of the summary generation process */
  status?: {
    content: string;
    comments: string;
    updatedAt: number;
  };
  /** Whether the story has a URL (for Ask HN, Show HN posts) */
  hasUrl?: boolean;
  /** Index of this summary in the list */
  index: number;
  /** Hacker News ID of the story (for permalinks) */
  hnId?: number;
  /** Whether to force all content to be expanded (no collapsing) */
  forceExpanded?: boolean;
  /** Whether to hide permalink sharing buttons */
  hidePermalinks?: boolean;
}

/**
 * @description Component that displays previews of AI-generated summaries with expand/collapse functionality.
 * Relies on SummaryContext for expansion state.
 * @param {StorySummaryProps} props - The props for the component.
 * @returns {JSX.Element} The rendered StorySummary component.
 */
export const StorySummary: React.FC<StorySummaryProps> = ({
  storySummary,
  commentsSummary,
  status,
  hasUrl = true,
  index,
  hnId,
  forceExpanded = false,
  hidePermalinks = false
}) => {
  // Track when permalink is copied for UI feedback
  const [articleCopied, setArticleCopied] = useState(false);

  // Access the summary context to get expansion state and control functions
  const { isExpanded, toggleSummary, registerSummary } = useSummary();

  // Register this summary with the context on mount
  useEffect(() => {
    // Inform the context that this summary instance exists
    registerSummary(index);
    // We don't need a cleanup function to unregister, as the context
    // manages state based on the registeredIndices list which persists
  }, [index, registerSummary]);

  // Determine if this specific summary should be expanded
  // Reads directly from context, or respects forceExpanded prop
  const currentExpandedState = forceExpanded || isExpanded(index);

  /**
   * Handle clicking the "Show more" / "Show less" button.
   * Calls the context's toggle function for this summary's index.
   * @returns {void}
   */
  const handleToggleExpanded = useCallback(() => {
    // Tell the context to flip the state for this index
    toggleSummary(index);
  }, [index, toggleSummary]);

  /**
   * Generate a permalink for the current summary section.
   * @param {'article' | 'comments'} section - Which summary section to link to.
   * @returns {string} The permalink URL, or empty string if no hnId.
   */
  const generatePermalink = useCallback((section: 'article' | 'comments'): string => {
    // Check if hnId is available
    if (!hnId) {
      // Return empty string if no ID
      return '';
    }

    // Create the base URL for the story page
    const baseUrl = `/story/${hnId}`;

    // Add hash fragment for comments section if requested
    // Return the appropriate URL
    return section === 'comments' ? `${baseUrl}#comments` : baseUrl;
  }, [hnId]); // Depend only on hnId

  /**
   * Copy a permalink to the clipboard and show feedback.
   * @param {'article' | 'comments'} section - Which summary section to link to.
   * @returns {void}
   */
  const copyPermalink = useCallback((section: 'article' | 'comments') => {
    // Generate the relative URL using the helper function
    const relativeUrl = generatePermalink(section);

    // If no URL could be generated, exit early
    if (!relativeUrl) {
      // Return nothing
      return;
    }

    // Create absolute URL by combining window origin with the relative path
    const absoluteUrl = `${window.location.origin}${relativeUrl}`;

    // Use the Clipboard API to write the text
    navigator.clipboard.writeText(absoluteUrl)
      .then(() => {
        // On success, show visual feedback (checkmark)
        setArticleCopied(true);
        // Log success to console
        console.log('Permalink copied to clipboard');
        // Reset the copied state after 2 seconds
        setTimeout(() => setArticleCopied(false), 2000);
      })
      .catch(err => {
        // On failure, log the error
        console.error('Failed to copy permalink:', err);
      });
  }, [generatePermalink]); // Depend on generatePermalink callback

  /**
   * Extracts the first Markdown heading (#) from the text, or a short preview.
   * Used for the collapsed state display.
   * @param {string | undefined} text - The full text to extract the heading from.
   * @returns {string} The first heading, or a short preview if no heading is found.
   */
  const extractFirstHeading = useCallback((text?: string): string => {
    // If text is empty or undefined, return empty string
    if (!text) {
      // Return empty string
      return '';
    }

    // Regex to find the first Markdown heading (e.g., # Heading)
    // Looks for 1-6 # characters at the start of a line, followed by space, then captures the text
    const headingMatch = text.match(/^(#{1,6}\s+.+?)($|\n)/m);

    // If a heading is found
    if (headingMatch) {
      // Return the captured heading text (group 1)
      return headingMatch[1];
    }

    // If no heading found, get the first line (up to 100 chars) as a preview
    const firstLineMatch = text.match(/^(.{1,100})($|\n)/);
    // Return the first line with ellipsis, or just substring with ellipsis if no newline
    return firstLineMatch ? `${firstLineMatch[1]}...` : `${text.substring(0, 100)}...`;
  }, []); // No dependencies, this is a pure function of its input

  /**
   * Checks if the content summary is ready to be displayed based on status.
   * @returns {boolean} True if the story summary is complete and exists.
   */
  const isContentReady = useCallback((): boolean => {
    // If no status is provided, rely only on the existence of the summary string
    if (!status) {
      // Return true if storySummary is truthy
      return !!storySummary;
    }
    // Check if status indicates completion and summary exists
    // Return true only if both conditions are met
    return status.content === "completed" && !!storySummary;
  }, [status, storySummary]); // Depends on status and storySummary

  /**
   * Checks if the comments summary is ready to be displayed based on status.
   * @returns {boolean} True if the comments summary is complete and exists.
   */
  const isCommentsReady = useCallback((): boolean => {
    // If no status is provided, rely only on the existence of the summary string
    if (!status) {
      // Return true if commentsSummary is truthy
      return !!commentsSummary;
    }
    // Check if status indicates completion and summary exists
    // Return true only if both conditions are met
    return status.comments === "completed" && !!commentsSummary;
  }, [status, commentsSummary]); // Depends on status and commentsSummary

  /**
   * Gets the appropriate placeholder text based on generation status.
   * @param {'content' | 'comments'} type - The type of summary (content or comments).
   * @param {string | undefined} currentStatus - The current status string (e.g., "pending", "failed").
   * @returns {string} Placeholder text to display.
   */
  const getPlaceholderText = useCallback((type: 'content' | 'comments', currentStatus?: string): string => {
    // If no status is provided, return the default generating text
    if (!currentStatus) {
      // Return default text
      return `Generating... check back soon.`;
    }

    // Use a switch statement for different status messages
    switch (currentStatus) {
      // Case: Summary generation is pending
      case 'pending':
        // Return pending text
        return `Generating... check back soon.`;
      // Case: Summary generation is being retried
      case 'retrying':
        // Return retrying text
        return `Retrying generation... check back soon.`;
      // Case: Summary generation failed
      case 'failed':
        // Return specific failure message based on type
        return `${type === 'content' ? 'Story' : 'Comments'} summary generation failed`;
      // Case: Summary generation is complete (but content might be missing)
      case 'completed':
        // Return completion text (used if content is unexpectedly empty)
        return 'Processing complete.'; // Changed from 'Complete!' which could be confusing
      // Default case for any other status
      default:
        // Return default generating text
        return `Generating... check back soon.`;
    }
  }, []); // No dependencies, pure function of inputs

  // Check if the summaries are ready using the memoized functions
  const storySummaryReady = isContentReady();
  // Check if comments summary is ready
  const hasCommentsSummary = isCommentsReady();

  // Generate the preview text for the collapsed story summary
  // Memoized to avoid re-calculation unless dependencies change
  const storyPreview = useMemo(() => {
    // Return preview only if summary is ready, otherwise empty string
    return storySummaryReady ? extractFirstHeading(storySummary) : '';
  }, [storySummaryReady, storySummary, extractFirstHeading]); // Depends on readiness, content, and extractor function

  // Generate the preview text for the collapsed comments summary
  // Memoized to avoid re-calculation unless dependencies change
  const commentsPreview = useMemo(() => {
    // Return preview only if summary is ready, otherwise empty string
    return hasCommentsSummary ? extractFirstHeading(commentsSummary) : '';
  }, [hasCommentsSummary, commentsSummary, extractFirstHeading]); // Depends on readiness, content, and extractor function

  // If neither summary is ready to be shown, render a simple placeholder
  // This handles the initial state before summaries are generated or fetched
  if (!storySummaryReady && !hasCommentsSummary) {
    // Return placeholder div
    return (
      // Outer container with margin
      <div className="mt-2 text-xs leading-normal">
        {/* Inner div with specific styling for placeholder text */}
        <div className="italic text-[#828282] dark:text-zinc-400">
          Generating summaries... check back soon.
        </div>
      </div>
    );
  }

  // Determine if the expand/collapse button should be shown
  // Logic: Not forced expanded, AND (is an article with a summary OR is comments-only with a summary)
  const needsExpansion = !forceExpanded &&
    (hasUrl ? storySummaryReady : hasCommentsSummary);


  // Return the main summary component structure
  return (
    // Outer container with margin and text styling
    <div className="mt-2 mb-1 text-xs leading-normal">
      {/* --- Story Summary Section --- */}
      {/* Conditionally render if the story summary is ready AND it's a story with a URL */}
      {storySummaryReady && hasUrl && (
        // Container for the story summary with border, padding, and background
        <div className="mb-3 border-l-4 border-l-orange-300 dark:border-l-orange-700/50 rounded-md dark:bg-zinc-800/70 pb-3 pt-3 pr-6 pl-4 mr-4">
          {/* Header row for the story summary section */}
          <div className="flex items-center mb-3 justify-between">
            {/* Badge indicating "Article Summary" */}
            <span className="font-medium bg-orange-100 dark:bg-orange-900/40 text-orange-800 dark:text-orange-300 text-xs px-2 py-0.5 rounded-full">
              Article Summary
            </span>

            {/* Permalink Button - Conditionally render */}
            {/* Conditions: hnId exists, permalinks not hidden, and section is expanded */}
            {hnId && !hidePermalinks && currentExpandedState && (
              // Button element for copying permalink
              <button
                // Action to perform on click
                onClick={() => copyPermalink('article')}
                // Styling for the button
                className="text-gray-500 hover:text-gray-700 dark:text-zinc-400 dark:hover:text-zinc-300 hover:cursor-pointer transition-colors duration-150 focus:outline-none text-xs flex items-center"
                // Tooltip text
                title="Copy permalink to article summary"
                // Accessibility label
                aria-label="Copy permalink to article summary"
              >
                {/* Conditionally render Checkmark or Link icon based on copied state */}
                {articleCopied ? (
                  // Show checkmark icon when copied
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                ) : (
                  // Show link icon when not copied
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                  </svg>
                )}
                {/* Text label for the button */}
                <span>Permalink</span>
              </button>
            )}
          </div>

          {/* Content Area: Show full summary or preview based on expansion state */}
          {/* Container for the markdown content */}
          <div className="text-black dark:text-zinc-200 markdown-content">
            {/* Use ternary operator to display full content or preview */}
            {currentExpandedState ? (
              // Render full story summary if expanded
              <ReactMarkdown
                // Plugin for GitHub Flavored Markdown (tables, strikethrough, etc.)
                remarkPlugins={[remarkGfm]}
                // Plugin for sanitizing HTML output, using our custom schema
                rehypePlugins={[[rehypeSanitize, sanitizeSchema]]}
              >
                {/* Pass the story summary string, default to empty string */}
                {storySummary || ''}
              </ReactMarkdown>
            ) : (
              // Render preview (first heading or excerpt) if collapsed
              <ReactMarkdown
                // Plugin for GitHub Flavored Markdown
                remarkPlugins={[remarkGfm]}
                // Plugin for sanitizing HTML output
                rehypePlugins={[[rehypeSanitize, sanitizeSchema]]}
              >
                {/* Pass the generated story preview, default to empty string */}
                {storyPreview || ''}
              </ReactMarkdown>
            )}
          </div>
        </div>
      )}

      {/* --- Comments Summary Section --- */}
      {/* Conditionally render if it's comments-only OR if expanded and comments exist */}
      {((!hasUrl && hasCommentsSummary) || (currentExpandedState && hasCommentsSummary)) && (
        // Container for the comments summary with border, padding, background
        <div className="border-l-4 border-l-blue-300 dark:border-l-blue-700/50 rounded-md bg-blue-50/30 dark:bg-zinc-800/70 pb-4 pt-3 pr-6 pl-4 mr-4 comments-summary">
          {/* Header row for the comments summary section */}
          <div className="flex items-center mb-3">
            {/* Badge indicating "Comments Summary" */}
            <span className="font-medium bg-blue-100 dark:bg-blue-900/40 text-blue-800 dark:text-blue-300 text-xs px-2 py-0.5 rounded-full">
              Comments Summary
            </span>
            {/* Permalink button intentionally removed for comments as per previous requirement */}
          </div>

          {/* Content Area: Show full summary or preview based on expansion state and URL presence */}
          {/* Container for the markdown content */}
          <div className="text-black dark:text-zinc-200 markdown-content">
            {/* Determine whether to show preview or full comments summary */}
            {/* Show preview if it's comments-only AND collapsed */}
            {!hasUrl && !currentExpandedState ? (
              // Render preview if comments-only and collapsed
              <ReactMarkdown
                remarkPlugins={[remarkGfm]}
                rehypePlugins={[[rehypeSanitize, sanitizeSchema]]}
              >
                {/* Pass the comments preview string */}
                {commentsPreview || ''}
              </ReactMarkdown>
            ) : (
              // Render full comments summary otherwise (expanded or hasUrl)
              <ReactMarkdown
                remarkPlugins={[remarkGfm]}
                rehypePlugins={[[rehypeSanitize, sanitizeSchema]]}
              >
                {/* Pass the full comments summary string */}
                {commentsSummary || ''}
              </ReactMarkdown>
            )}
          </div>
        </div>
      )}

      {/* --- Comments Summary Placeholder --- */}
      {/* Show if expanded AND comments summary is NOT ready AND story summary IS ready AND status exists */}
      {currentExpandedState && !hasCommentsSummary && storySummaryReady && status && (
        // Container for the placeholder with styling similar to comments summary
        <div className="border-l-4 border-l-blue-300 dark:border-l-blue-700/50 rounded-md bg-blue-50/30 dark:bg-zinc-800/70 pb-3 pt-3 pr-6 pl-4 mr-4">
          {/* Header row */}
          <div className="flex items-center mb-3">
            {/* Badge indicating "Comments Summary" */}
            <span className="font-medium bg-blue-100 dark:bg-blue-900/40 text-blue-800 dark:text-blue-300 text-xs px-2 py-0.5 rounded-full">
              Comments Summary
            </span>
          </div>

          {/* Placeholder text area */}
          {/* Container for the italicized placeholder text */}
          <div className="text-black dark:text-zinc-200 italic">
            {/* Get the appropriate placeholder based on the comments status */}
            {getPlaceholderText('comments', status.comments)}
          </div>
        </div>
      )}

      {/* --- Expand/Collapse Button --- */}
      {/* Conditionally render the button if expansion is needed (not forced) */}
      {needsExpansion && (
        // Container for the button and optional permalink button
        <div className="mt-3 text-left flex items-center gap-2">
          {/* The "Show more" / "Show less" button */}
          <button
            // Call the handler to toggle expansion state in the context
            onClick={handleToggleExpanded}
            // Styling for the button
            className="text-gray-700 bg-gray-200 dark:bg-zinc-800 dark:text-zinc-400 hover:bg-gray-300 dark:hover:bg-zinc-700 px-3 py-1 rounded-full text-xs font-medium cursor-pointer transition-colors shadow-sm"
          >
            {/* Dynamically set button text based on current expansion state */}
            {currentExpandedState ? 'Show less' : 'Show more'}
          </button>

          {/* Adjacent Permalink Button - Conditionally render */}
          {/* Conditions: Expanded, hnId exists, permalinks not hidden, and it's an article (hasUrl) */}
          {currentExpandedState && hnId && !hidePermalinks && hasUrl && (
            // Button element for copying permalink
            <button
              // Action to perform on click
              onClick={() => copyPermalink('article')}
              // Styling for the button (slightly different appearance)
              className="text-gray-600 bg-gray-100 dark:bg-zinc-900 dark:text-zinc-400 hover:bg-gray-200 dark:hover:bg-zinc-800 px-3 py-1 rounded-full text-xs font-medium flex items-center cursor-pointer transition-colors shadow-sm"
              // Tooltip text
              title="Copy permalink to article summary"
              // Accessibility label
              aria-label="Copy permalink to article summary"
            >
              {/* Conditionally render Checkmark or Link icon */}
              {articleCopied ? (
                // Show checkmark icon when copied
                <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
              ) : (
                // Show link icon when not copied
                <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                </svg>
              )}
              {/* Text label for the button */}
              <span>Permalink</span>
            </button>
          )}
        </div>
      )}
    </div>
  );
  // End of StorySummary component
}; 