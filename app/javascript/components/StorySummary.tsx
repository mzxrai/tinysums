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
  /** Whether the story has a URL (for Ask HN, Show HN posts) */
  hasUrl?: boolean;
}

/**
 * @description Component that displays previews of AI-generated summaries with expand/collapse functionality
 * Uses a minimal design that integrates well with the HN aesthetic while providing modern UX
 */
export const StorySummary: React.FC<StorySummaryProps> = ({
  storySummary,
  commentsSummary,
  status,
  hasUrl = true
}) => {
  // Single state to track if the entire summary is expanded
  const [isExpanded, setIsExpanded] = useState(false);

  /**
   * Extracts the first Markdown heading from the text
   * @param text - The full text to extract the heading from
   * @returns Just the first heading or a short preview if no heading is found
   */
  const extractFirstHeading = (text?: string) => {
    if (!text) return '';

    // Look for a Markdown heading (starts with one or more # followed by text)
    const headingMatch = text.match(/^(#{1,6}\s+.+?)($|\n)/m);

    if (headingMatch) {
      return headingMatch[1];
    }

    // If no heading found, return a short preview
    const firstLineMatch = text.match(/^(.{1,100})($|\n)/);
    return firstLineMatch ? `${firstLineMatch[1]}...` : `${text.substring(0, 100)}...`;
  };

  /**
   * Renders markdown content with proper sanitization
   * @param text - The markdown text to render
   * @param isPreview - Whether this is a preview (first heading only) version
   * @returns React component with rendered markdown
   */
  const renderMarkdown = (text?: string, isPreview: boolean = false) => {
    if (!text) return null;

    // For preview, use just the first heading
    const contentToRender = isPreview ? extractFirstHeading(text) : text;

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
    if (!currentStatus) return `Generating... check back soon.`;

    switch (currentStatus) {
      case 'pending':
        return `Generating... check back soon.`;
      case 'retrying':
        return `Retrying generation... check back soon.`;
      case 'failed':
        return `${type === 'content' ? 'Story' : 'Comments'} summary generation failed`;
      case 'completed':
        return 'Complete!';
      default:
        return `Generating... check back soon.`;
    }
  };

  // Check if we have any completed summaries
  const hasContentSummary = isContentReady();
  const hasCommentsSummary = isCommentsReady();

  // If no summaries are ready, just show a simple placeholder
  if (!hasContentSummary && !hasCommentsSummary) {
    return (
      <div className="mt-2 text-xs leading-normal">
        <div className="italic text-[#828282] dark:text-zinc-400">
          Generating summaries... check back soon.
        </div>
      </div>
    );
  }

  // Only show the expand/collapse button if we have long enough content or comments summary
  const needsExpansion =
    (hasContentSummary && storySummary && storySummary.length > 100) ||
    (hasCommentsSummary && commentsSummary && commentsSummary.length > 100);

  // Return the summary component
  return (
    <div className="mt-2 text-xs leading-normal">
      {/* Content Summary Section - Only show for stories with URLs and if content summary exists */}
      {hasContentSummary && hasUrl && (
        <div className="mb-3 border-l-4 border-l-orange-300 dark:border-l-orange-700/50 rounded-md bg-orange-50/30 dark:bg-zinc-800/70 pb-1 pt-3 px-6 mr-4">
          <div className="flex items-center mb-3">
            <span className="font-medium bg-orange-100 dark:bg-orange-900/40 text-orange-800 dark:text-orange-300 text-xs px-2 py-0.5 rounded-full">
              Article Summary
            </span>
          </div>

          {/* Show either preview or full content based on expanded state */}
          <div className="text-black dark:text-zinc-200 markdown-content">
            {isExpanded ? renderMarkdown(storySummary) : renderMarkdown(storySummary, true)}
          </div>
        </div>
      )}

      {/* Comments Summary Section - Show for stories without URLs, stories with just comments, or when expanded */}
      {(hasCommentsSummary || (!hasUrl && !hasContentSummary) || (isExpanded && hasUrl)) && (
        <div className="border-l-4 border-l-blue-300 dark:border-l-blue-700/50 rounded-md bg-blue-50/30 dark:bg-zinc-800/70 pb-2 pt-3 px-6 mr-4">
          <div className="flex items-center mb-3">
            <span className="font-medium bg-blue-100 dark:bg-blue-900/40 text-blue-800 dark:text-blue-300 text-xs px-2 py-0.5 rounded-full">
              Comments Summary
            </span>
          </div>

          <div className="text-black dark:text-zinc-200 markdown-content">
            {hasCommentsSummary ? (
              // Comments are ready, show preview or full content based on expanded state
              !hasUrl && !isExpanded ?
                renderMarkdown(commentsSummary, true) :
                renderMarkdown(commentsSummary)
            ) : (
              // Comments are not ready, show placeholder (only shown when expanded or for stories without URLs)
              <span className="italic text-[#828282] dark:text-zinc-400">
                {getPlaceholderText('comments', status?.comments)}
              </span>
            )}
          </div>
        </div>
      )}

      {/* Show expand/collapse button if we have summaries worth expanding */}
      {needsExpansion && (
        <div className="mt-3 text-left">
          <button
            onClick={() => setIsExpanded(!isExpanded)}
            className="text-gray-700 bg-gray-200 dark:bg-zinc-800 dark:text-zinc-400 hover:bg-gray-300 dark:hover:bg-zinc-700 px-3 py-1 rounded-full text-xs font-medium cursor-pointer transition-colors shadow-sm"
          >
            {isExpanded ? 'Show less' : 'Show more'}
          </button>
        </div>
      )}
    </div>
  );
}; 