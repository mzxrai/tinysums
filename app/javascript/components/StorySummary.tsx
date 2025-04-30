import React, { useState, useMemo, useEffect, useCallback } from 'react';
import ReactMarkdown from 'react-markdown';
import rehypeSanitize, { defaultSchema } from 'rehype-sanitize';
import remarkGfm from 'remark-gfm';
import { useSummary } from '../contexts/SummaryContext';
import { SparklesIcon } from '@heroicons/react/24/solid';
import { DocumentTextIcon } from '@heroicons/react/24/outline';

/**
 * @description Sanitization schema for rehype-sanitize.
 * Allows specific HTML tags and attributes needed for rendering Markdown content,
 * including tables and styling attributes, while maintaining security.
 */
const sanitizeSchema = {
  // Inherit the default schema provided by rehype-sanitize.
  ...defaultSchema,
  // Extend the allowed attributes.
  attributes: {
    // Inherit default attributes.
    ...defaultSchema.attributes,
    // Allow 'className' and 'style' attributes on all tags (*).
    // Merges existing default wildcard attributes with the new ones.
    '*': [...(defaultSchema.attributes?.['*'] || []), 'className', 'style']
  },
  // Extend the allowed tag names.
  tagNames: [
    // Inherit default tag names.
    ...(defaultSchema.tagNames || []),
    // Explicitly allow table-related tags.
    'table', 'thead', 'tbody', 'tfoot', 'tr', 'th', 'td'
  ]
};

/**
 * @description Props for the StorySummary component.
 * Defines the inputs required for rendering the story and comments summaries.
 */
interface StorySummaryProps {
  /**
   * @description Summary of the story content (usually the article).
   * Optional Markdown string.
   */
  storySummary?: string;
  /**
   * @description Summary of the comment section.
   * Optional Markdown string.
   */
  commentsSummary?: string;
  /**
   * @description Status object indicating the generation progress of summaries.
   * Optional object containing content status, comments status, and last update timestamp.
   */
  status?: {
    /** Status for the main content summary ('pending', 'completed', 'failed'). */
    content: string;
    /** Status for the comments summary ('pending', 'completed', 'failed'). */
    comments: string;
    /** Unix timestamp (seconds) of the last status update. */
    updatedAt: number;
  };
  /**
   * @description Flag indicating if the original Hacker News story has an external URL.
   * Defaults to true. Used to differentiate link posts from Ask HN/Show HN.
   */
  hasUrl?: boolean;
  /**
   * @description The unique index of this summary component within its parent list.
   * Used for managing expansion state in the context.
   */
  index: number;
  /**
   * @description The Hacker News ID of the story.
   * Optional number used for generating permalinks.
   */
  hnId?: number;
  /**
   * @description If true, forces the summary content to always be displayed in expanded state.
   * Defaults to false. Overrides the context-based expansion state.
   */
  forceExpanded?: boolean;
  /**
   * @description If true, hides the 'Copy link' button.
   * Defaults to false.
   */
  hidePermalinks?: boolean;
}

/**
 * @description Displays AI-generated summaries (story and comments) in an expandable card format.
 * It handles loading states, content previewing, expansion toggling, permalink copying,
 * and Markdown rendering with sanitization.
 * @param {StorySummaryProps} props - The props for the component.
 * @returns {JSX.Element | null} The rendered summary card, a loading indicator, or null if summaries failed.
 * @example
 * <StorySummary
 *   storySummary="# Article\\nDetails..."
 *   commentsSummary="## Discussion\\nPoints..."
 *   status={{ content: 'completed', comments: 'completed', updatedAt: 1678886400 }}
 *   index={0}
 *   hnId={12345}
 * />
 * @remarks Uses `SummaryContext` for managing expansion state across multiple summaries.
 * Leverages `ReactMarkdown` for rendering and `rehype-sanitize` for security.
 */
export const StorySummary: React.FC<StorySummaryProps> = ({
  // Destructure props with default values.
  storySummary, // Optional story summary string.
  commentsSummary, // Optional comments summary string.
  status, // Optional status object.
  hasUrl = true, // Default hasUrl to true.
  index, // Required index number.
  hnId, // Optional Hacker News ID number.
  forceExpanded = false, // Default forceExpanded to false.
  hidePermalinks = false // Default hidePermalinks to false.
}) => {
  // State to manage the visual feedback for the 'Copy link' button.
  const [linkCopied, setLinkCopied] = useState(false);

  // Retrieve expansion state and control functions from the SummaryContext.
  const { isExpanded, toggleSummary, registerSummary } = useSummary();

  // Effect hook to register this summary instance with the context when the component mounts or index changes.
  useEffect(() => {
    // Call the register function from the context with the current index.
    registerSummary(index);
    // Dependency array ensures this effect runs only when index or registerSummary function changes.
  }, [index, registerSummary]);

  // Determine the current expansion state for this specific summary instance.
  // It's expanded if forceExpanded is true OR if the context indicates it's expanded for this index.
  const currentExpandedState = forceExpanded || isExpanded(index);

  /**
   * @description Callback function to toggle the expansion state of this summary.
   * Uses `useCallback` for performance optimization, preventing recreation on re-renders unless dependencies change.
   */
  const handleToggleExpanded = useCallback(() => {
    // Call the toggle function from the context with the current index.
    toggleSummary(index);
    // Dependency array ensures the callback is stable unless index or toggleSummary changes.
  }, [index, toggleSummary]);

  /**
   * @description Callback function to copy the story's permalink to the user's clipboard.
   * Uses `useCallback` for performance optimization.
   */
  const handleCopyLink = useCallback(() => {
    // Exit early if hnId is not available (e.g., permalinks hidden or data missing).
    if (!hnId) {
      // Return void, indicating no action was taken.
      return;
    }
    // Construct the absolute permalink URL using the current window origin and the hnId.
    const permalink = `${window.location.origin}/story/${hnId}`;
    // Use the Clipboard API to write the permalink text.
    navigator.clipboard.writeText(permalink).then(() => {
      // On successful copy:
      // Set the linkCopied state to true to show feedback.
      setLinkCopied(true);
      // Set a timeout to reset the feedback message after 2 seconds (2000ms).
      setTimeout(() => setLinkCopied(false), 2000);
    }).catch(err => {
      // On failed copy:
      // Log an error message to the console.
      console.error('Failed to copy permalink:', err);
    });
    // Dependency array includes hnId, as the permalink depends on it.
  }, [hnId]);

  /**
   * @description Callback function to extract the main content body from Markdown.
   * Skips an initial H1/H2 heading line if present and returns the remaining text.
   * Used to feed content to the preview renderer, which handles visual truncation (line clamping) via CSS.
   * @param {string | undefined} text - The full Markdown text.
   * @returns {string} The text after the initial heading (if any), or the original text, or an empty string.
   */
  const extractPreview = useCallback((text?: string): string => {
    // If the input text is null, undefined, or empty, return an empty string.
    if (!text) {
      // Return an empty string as there's no text to preview.
      return '';
    }

    // --- Determine the starting text (skip initial H1/H2) --- 
    let contentToPreview = text;
    const initialHeadingRegex = /^\s*(?:#|##)\s+/;
    const initialMatch = text.match(initialHeadingRegex);
    if (initialMatch && initialMatch.index === 0) {
      const newlineIndex = text.indexOf('\n', initialMatch.index);
      if (newlineIndex !== -1) {
        contentToPreview = text.substring(newlineIndex + 1).trimStart();
      } else {
        return ''; // Only heading was present
      }
    }
    // Return the content after the potential heading removal.
    return contentToPreview;
    // Empty dependency array means this callback never changes once created.
  }, []);

  /**
   * @description Callback to determine if the main story summary content is ready for display.
   * Checks both the status flag and the presence of the summary text.
   * Uses `useCallback` for optimization.
   * @returns {boolean} True if the content is ready, false otherwise.
   */
  const isContentReady = useCallback(() => {
    // If there's no status object, readiness depends solely on whether storySummary has content.
    if (!status) {
      // Return true if storySummary is truthy (not null, undefined, or empty string), false otherwise.
      return !!storySummary;
    }
    // If status exists, content is ready only if status.content is 'completed' AND storySummary has content.
    return status.content === "completed" && !!storySummary;
    // Dependencies: status object and storySummary string.
  }, [status, storySummary]);

  /**
   * @description Callback to determine if the comments summary content is ready for display.
   * Checks both the status flag and the presence of the summary text.
   * Uses `useCallback` for optimization.
   * @returns {boolean} True if the comments summary is ready, false otherwise.
   */
  const isCommentsReady = useCallback(() => {
    // If there's no status object, readiness depends solely on whether commentsSummary has content.
    if (!status) {
      // Return true if commentsSummary is truthy, false otherwise.
      return !!commentsSummary;
    }
    // If status exists, comments are ready only if status.comments is 'completed' AND commentsSummary has content.
    return status.comments === "completed" && !!commentsSummary;
    // Dependencies: status object and commentsSummary string.
  }, [status, commentsSummary]);

  // Calculate the preview for the story summary using useMemo for caching.
  const storyPreview = useMemo(() => {
    // If there is no story summary, return an empty string.
    if (!storySummary) {
      // Return empty string.
      return '';
    }
    // Otherwise, extract the preview from the story summary.
    return extractPreview(storySummary);
    // Dependencies: storySummary string and the extractPreview callback.
  }, [storySummary, extractPreview]);

  // Calculate the preview for the comments summary using useMemo for caching.
  const commentsPreview = useMemo(() => {
    // If there is no comments summary, return an empty string.
    if (!commentsSummary) {
      // Return empty string.
      return '';
    }
    // Otherwise, extract the preview from the comments summary.
    return extractPreview(commentsSummary);
    // Dependencies: commentsSummary string and the extractPreview callback.
  }, [commentsSummary, extractPreview]);

  // Determine if the article summary content is available and ready.
  const hasArticleSummary = isContentReady();
  // Determine if the comments summary content is available and ready.
  const hasCommentsSummary = isCommentsReady();

  // Determine if the "Show full" button should be displayed.
  // Show if *any* summary content (story or comments) exists, as it might be clamped by CSS.
  const needsExpansion = !!(storySummary || commentsSummary);

  /**
   * @description Custom component renderers for `ReactMarkdown`.
   * Provides specific styling and behavior for different Markdown elements.
   */
  const markdownComponents = {
    // Never render H1 elements from the Markdown.
    h1: ({ node, ...props }: any) => { /* Explicitly render nothing */ return null; },
    // Never render H2 elements from the Markdown.
    h2: ({ node, ...props }: any) => { /* Explicitly render nothing */ return null; },
    // Render H3 elements with specific styling.
    h3: ({ node, ...props }: any) => <h3 className="text-base font-semibold text-gray-900 mb-2 mt-4" {...props} />,
    // Render paragraph elements with specific styling.
    p: ({ node, ...props }: any) => <p className="mb-3 text-gray-700 leading-relaxed" {...props} />,
    // Render unordered list elements with specific styling.
    ul: ({ node, ...props }: any) => <ul className="mb-3 pl-5 list-disc text-gray-700 leading-relaxed" {...props} />,
    // Render ordered list elements with specific styling.
    ol: ({ node, ...props }: any) => <ol className="mb-3 pl-5 list-decimal text-gray-700 leading-relaxed" {...props} />,
    // Render list item elements with specific styling.
    li: ({ node, ...props }: any) => <li className="mb-1.5" {...props} />,
    // Render anchor (link) elements with specific styling and security attributes.
    a: ({ node, ...props }: any) => <a className="text-blue-600 hover:underline" target="_blank" rel="noopener noreferrer" {...props} />,
    // Render blockquote elements with specific styling.
    blockquote: ({ node, ...props }: any) => <blockquote className="border-l-4 border-gray-200 pl-4 italic text-gray-600 my-4" {...props} />,
    // Render code elements (inline and block) with specific styling.
    code: ({ node, className, children, ...props }: any) => {
      // Check if the code block has a language class (e.g., language-javascript).
      const match = /language-(\w+)/.exec(className || '');
      // If it's a language-specific block (match found):
      return match ? (
        // Render as a <pre> block for code formatting.
        <pre className="block bg-gray-100 p-3 rounded text-sm font-mono text-gray-800 overflow-x-auto my-3 leading-normal">
          {/* Render the inner <code> tag with the language class. */}
          <code className={`language-${match[1]}`} {...props}>
            {/* Render the code content. */}
            {children}
          </code>
        </pre>
      ) : (
        // If it's inline code (no language match):
        // Render as an inline <code> tag with specific styling.
        <code className="bg-gray-100 px-1 py-0.5 rounded text-sm font-mono text-gray-800" {...props}>
          {/* Render the code content. */}
          {children}
        </code>
      );
    },
    // Render table elements with specific styling.
    table: ({ node, ...props }: any) => <table className="border-collapse w-full my-4 text-sm" {...props} />,
    // Render table head elements with specific styling.
    thead: ({ node, ...props }: any) => <thead className="bg-gray-50 border-b border-gray-300" {...props} />,
    // Render table body elements.
    tbody: ({ node, ...props }: any) => <tbody {...props} />,
    // Render table row elements with specific styling.
    tr: ({ node, ...props }: any) => <tr className="border-b border-gray-100 last:border-0" {...props} />,
    // Render table header cell elements with specific styling.
    th: ({ node, ...props }: any) => <th className="border border-gray-200 px-3 py-2 text-left font-semibold text-gray-700" {...props} />,
    // Render table data cell elements with specific styling.
    td: ({ node, ...props }: any) => <td className="border border-gray-200 px-3 py-2 text-gray-800" {...props} />,
    // Render strong (bold) elements with specific styling.
    strong: ({ node, ...props }: any) => <strong className="font-semibold text-black" {...props} />,
    // Render emphasis (italic) elements with specific styling.
    em: ({ node, ...props }: any) => <em className="italic" {...props} />,
    // Render horizontal rule elements with specific styling.
    hr: ({ node, ...props }: any) => <hr className="my-4 border-t border-gray-200" {...props} />,
  };

  // Handle the initial loading state before summaries are ready.
  // If neither summary is ready:
  if (!hasArticleSummary && !hasCommentsSummary) {
    // If neither summary is ready to display for any reason (pending, failed, empty completed),
    // show the generating message. We can add more nuanced messages for failures later if needed.
    return (
      // Container for the loading message with padding and text styling.
      <div className="p-3 text-sm text-gray-500">
        {/* Loading message text. */}
        Cooking summaries. Check back soon...
      </div>
    );
  }

  // Main return statement for the component's JSX structure.
  return (
    // Outermost container div.
    <div>
      {/* Container for the summary content itself, with zero padding initially. */}
      <div className="p-0 text-sm">
        {/* Conditional rendering based on the expansion state. */}
        {currentExpandedState ? (
          // --- RENDER EXPANDED VIEW ---
          // Container for expanded content with vertical spacing between sections.
          <div className="space-y-4">
            {/* Conditionally render the full Article Summary section if it's available. */}
            {hasArticleSummary && (
              // Container for the article summary section.
              <div>
                {/* Badge indicating "Article Summary". Add sparkles icon. */}
                <span className="inline-flex items-center rounded-full bg-orange-100 px-2.5 py-0.5 text-xs font-medium text-orange-700 mb-2">
                  {/* Sparkles Icon (Heroicons) */}
                  <SparklesIcon className="w-3 h-3 mr-1" />
                  Article Summary
                </span>
                {/* Render the full article summary Markdown content. */}
                <ReactMarkdown
                  components={markdownComponents}
                  rehypePlugins={[[rehypeSanitize, { schema: sanitizeSchema }]]}
                  remarkPlugins={[remarkGfm]}
                >
                  {storySummary || ''}
                </ReactMarkdown>
              </div>
            )}
            {/* Conditionally render the full Comments Summary section if it's available. */}
            {hasCommentsSummary && (
              // Container for the comments summary section. Apply top margin/border if article summary is also present.
              <div className={`${hasArticleSummary ? 'mt-4 pt-4 border-t border-gray-100' : ''}`}>
                {/* Badge indicating "Comments Summary". Add sparkles icon. */}
                <span className="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-700 mb-2">
                  {/* Sparkles Icon (Heroicons) */}
                  <SparklesIcon className="w-3 h-3 mr-1" />
                  Comments Summary
                </span>
                {/* Render the full comments summary Markdown content. */}
                <ReactMarkdown
                  components={markdownComponents}
                  rehypePlugins={[[rehypeSanitize, { schema: sanitizeSchema }]]}
                  remarkPlugins={[remarkGfm]}
                >
                  {commentsSummary || ''}
                </ReactMarkdown>
              </div>
            )}
          </div>
        ) : (
          // --- RENDER COLLAPSED VIEW ---
          // Container for collapsed content.
          <div>
            {/* Case 1: Article Summary exists (show its badge and preview). */}
            {hasArticleSummary && (
              // Container for the article summary preview.
              // Added summary-preview-clamp class for CSS line clamping.
              <div className="summary-preview-clamp">
                {/* Badge indicating "Article Summary". Add sparkles icon. */}
                <span className="inline-flex items-center rounded-full bg-orange-100 px-2.5 py-0.5 text-xs font-medium text-orange-700 mb-2">
                  {/* Sparkles Icon (Heroicons) */}
                  <SparklesIcon className="w-3 h-3 mr-1" />
                  Article Summary
                </span>
                {/* Render the article summary preview using Markdown components. */}
                <ReactMarkdown
                  components={markdownComponents}
                  rehypePlugins={[[rehypeSanitize, { schema: sanitizeSchema }]]}
                  remarkPlugins={[remarkGfm]}
                >
                  {storyPreview}
                </ReactMarkdown>
              </div>
            )}
            {/* Case 2: ONLY Comments Summary exists (show its badge and preview). */}
            {/* This condition ensures we don't show comments preview if article preview is already shown. */}
            {!hasArticleSummary && hasCommentsSummary && (
              // Container for the comments summary preview.
              // Added summary-preview-clamp class for CSS line clamping.
              <div className="summary-preview-clamp">
                {/* Badge indicating "Comments Summary". Add sparkles icon. */}
                <span className="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-700 mb-2">
                  {/* Sparkles Icon (Heroicons) */}
                  <SparklesIcon className="w-3 h-3 mr-1" />
                  Comments Summary
                </span>
                {/* Render the comments summary preview using Markdown components. */}
                <ReactMarkdown
                  components={markdownComponents}
                  rehypePlugins={[[rehypeSanitize, { schema: sanitizeSchema }]]}
                  remarkPlugins={[remarkGfm]}
                >
                  {commentsPreview}
                </ReactMarkdown>
              </div>
            )}
          </div>
        )}

        {/* --- Combined Action Buttons Area --- */}
        {/* Conditionally render this action bar only if either the expansion button or the copy link button needs to be shown. */}
        {(needsExpansion || (!hidePermalinks && hnId)) && (
          // Container for action buttons. Flex layout, space between items, top margin.
          <div className={`flex items-center justify-between mt-2`}>

            {/* Conditionally render the "Show more" / "Show less" button if expansion is needed. */}
            {needsExpansion ? (
              // Button element to toggle expansion state.
              <button
                // Attach the click handler.
                onClick={handleToggleExpanded}
                // Styling for the button (link-like appearance).
                // Add cursor-pointer class.
                className="flex items-center text-xs text-gray-500 hover:text-blue-700 transition-colors duration-150 cursor-pointer"
              >
                {/* Dynamically set button text based on expansion state. */}
                {currentExpandedState ? 'Show less' : 'Show more'}
                {/* Chevron icon indicating expansion/collapse action. */}
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className={`w-4 h-4 ml-0 transition-transform ${currentExpandedState ? 'rotate-180' : ''}`}>
                  {/* SVG path data for the chevron icon. */}
                  <path fillRule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 10.94l3.71-3.71a.75.75 0 111.06 1.06l-4.25 4.25a.75.75 0 01-1.06 0L5.23 8.29a.75.75 0 01.02-1.06z" clipRule="evenodd" />
                </svg>
              </button>
            ) : (
              // If no expansion button is needed, render an empty span to maintain layout spacing with justify-between.
              <span></span>
            )}

            {/* Conditionally render the "Copy link" button if permalinks are not hidden and hnId exists. */}
            {!hidePermalinks && hnId && (
              // Button element to copy the permalink.
              <button
                // Attach the click handler.
                onClick={handleCopyLink}
                // Styling: flex layout, text size, transition. Dynamically change text color based on 'linkCopied' state.
                // Add cursor-pointer class.
                className={`flex items-center text-xs transition-colors duration-150 cursor-pointer ${linkCopied ? 'text-green-600' : 'text-gray-500 hover:text-blue-600'}`}
              >
                {/* Dynamically set button text based on 'linkCopied' state. */}
                {linkCopied ? 'Copied!' : 'Copy link'}
                {/* Link icon. */}
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 ml-1">
                  {/* SVG path data for the link icon. */}
                  <path d="M12.232 4.232a2.5 2.5 0 013.536 3.536l-1.225 1.224a.75.75 0 001.061 1.06l1.224-1.224a4 4 0 00-5.656-5.656l-3 3a4 4 0 00.225 5.865.75.75 0 00.977-1.138 2.5 2.5 0 01-.142-3.667l3-3z" />
                  {/* More SVG path data. */}
                  <path d="M11.603 7.963a.75.75 0 00-.977 1.138 2.5 2.5 0 01.142 3.667l-3 3a2.5 2.5 0 01-3.536-3.536l1.225-1.224a.75.75 0 00-1.061-1.06l-1.224 1.224a4 4 0 105.656 5.656l3-3a4 4 0 00-.225-5.865z" />
                </svg>
              </button>
            )}

          </div>
        )}
      </div>
    </div>
  );
}; 