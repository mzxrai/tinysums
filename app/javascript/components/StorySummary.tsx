import React, { useState } from 'react';
import ReactMarkdown from 'react-markdown';
import rehypeSanitize, { defaultSchema } from 'rehype-sanitize';
import remarkGfm from 'remark-gfm';

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
}

/**
 * @description Component that displays previews of AI-generated summaries with expand/collapse functionality
 * Uses a minimal design that integrates well with the HN aesthetic while providing modern UX
 */
export const StorySummary: React.FC<StorySummaryProps> = ({
  storySummary,
  commentsSummary,
  status
}) => {
  // Single state to track if the entire summary is expanded
  const [isExpanded, setIsExpanded] = useState(false);

  /**
   * Gets a preview of the text (first 140 characters)
   * @param text - The full text to get a preview from
   * @returns A shortened preview of the text with ellipsis if needed
   */
  const getPreview = (text?: string) => {
    if (!text) return '';
    // Return the first ~140 characters plus ellipsis if longer
    return text.length > 140 ? `${text.substring(0, 140)}...` : text;
  };

  /**
   * Renders markdown content with proper sanitization
   * @param text - The markdown text to render
   * @param isPreview - Whether this is a preview (truncated) version
   * @returns React component with rendered markdown
   */
  const renderMarkdown = (text?: string, isPreview: boolean = false) => {
    if (!text) return null;

    // For preview, use the truncated text
    const contentToRender = isPreview ? getPreview(text) : text;

    return (
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        rehypePlugins={[[rehypeSanitize, sanitizeSchema]]}
      >
        {contentToRender}
      </ReactMarkdown>
    );
  };

  /**
   * Checks if the content summary is ready to be displayed
   * @returns Boolean indicating if the content summary should be shown
   */
  const isContentReady = () => {
    // If no status is provided, default to showing the summary if it exists
    if (!status) return !!storySummary;

    // Only show if content status is "completed" and the summary exists
    return status.content === "completed" && !!storySummary;
  };

  /**
   * Checks if the comments summary is ready to be displayed
   * @returns Boolean indicating if the comments summary should be shown
   */
  const isCommentsReady = () => {
    // If no status is provided, default to showing the summary if it exists
    if (!status) return !!commentsSummary;

    // Only show if comments status is "completed" and the summary exists
    return status.comments === "completed" && !!commentsSummary;
  };

  /**
   * Gets the appropriate placeholder text based on status
   * @param type - The type of summary (content or comments)
   * @param currentStatus - The current status of the summary
   * @returns Placeholder text to display
   */
  const getPlaceholderText = (type: 'content' | 'comments', currentStatus?: string) => {
    if (!currentStatus) return `${type === 'content' ? 'Content' : 'Comment'} summary not available`;

    switch (currentStatus) {
      case 'pending':
        return `${type === 'content' ? 'Content' : 'Comment'} summary is being generated...`;
      case 'retrying':
        return `Retrying ${type === 'content' ? 'content' : 'comment'} summary generation...`;
      case 'failed':
        return `${type === 'content' ? 'Content' : 'Comment'} summary generation failed`;
      default:
        return `${type === 'content' ? 'Content' : 'Comment'} summary not available`;
    }
  };

  // If neither summary exists or is ready, render nothing
  if (!isContentReady() && !isCommentsReady() && !status) return null;

  // Check if the content is long enough to need expansion or if there's a comment summary
  const needsExpansion =
    (storySummary && storySummary.length > 140) ||
    (status && status.comments !== "pending");

  // Return the summary component
  return (
    <div className="mt-2 text-xs leading-normal border-l-2 border-l-orange-200 dark:border-l-zinc-700 pl-3">
      {/* Content Summary Section */}
      {(storySummary || (status && status.content)) && (
        <div className="mb-2">
          <div className="flex items-center mb-1">
            <span className="font-medium text-[#828282] dark:text-zinc-400 text-xs">
              Summary
            </span>
          </div>

          {/* Show either preview or full content based on expanded state */}
          <div className="text-black dark:text-zinc-300 markdown-content">
            {isContentReady() ? (
              // Content is ready, show actual content
              isExpanded ? (
                renderMarkdown(storySummary)
              ) : (
                renderMarkdown(storySummary, true)
              )
            ) : (
              // Content is not ready, show placeholder
              <span className="italic text-[#828282] dark:text-zinc-500">
                {getPlaceholderText('content', status?.content)}
              </span>
            )}
          </div>
        </div>
      )}

      {/* Comment Summary Section - Only visible when expanded */}
      {isExpanded && (commentsSummary || (status && status.comments)) && (
        <div className="mb-2">
          <div className="flex items-center mb-1">
            <span className="font-medium text-[#828282] dark:text-zinc-400 text-xs">
              Comments
            </span>
          </div>

          {/* Show comments depending on ready state */}
          <div className="text-black dark:text-zinc-300 markdown-content">
            {isCommentsReady() ? (
              // Comments are ready, show actual content
              renderMarkdown(commentsSummary)
            ) : (
              // Comments are not ready, show placeholder
              <span className="italic text-[#828282] dark:text-zinc-500">
                {getPlaceholderText('comments', status?.comments)}
              </span>
            )}
          </div>
        </div>
      )}

      {/* Show expand/collapse button at the bottom if needed */}
      {needsExpansion && (
        <div className="mt-2">
          <button
            onClick={() => setIsExpanded(!isExpanded)}
            className="text-[#828282] dark:text-zinc-500 hover:underline text-xs cursor-pointer"
          >
            {isExpanded ? 'Show less' : 'More'}
          </button>
        </div>
      )}
    </div>
  );
}; 