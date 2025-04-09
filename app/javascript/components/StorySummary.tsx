import React, { useState } from 'react';

/**
 * Props for the StorySummary component
 */
interface StorySummaryProps {
  /** Summary of the story content */
  contentSummary?: string;
  /** Summary of the comment section */
  commentSummary?: string;
}

/**
 * @description Component that displays previews of AI-generated summaries with expand/collapse functionality
 * Uses a minimal design that integrates well with the HN aesthetic while providing modern UX
 */
export const StorySummary: React.FC<StorySummaryProps> = ({
  contentSummary,
  commentSummary
}) => {
  // Single state to track if the entire summary is expanded
  const [isExpanded, setIsExpanded] = useState(false);

  // Function to get a preview of text (first 140 characters)
  const getPreview = (text?: string) => {
    if (!text) return '';
    // Return the first ~140 characters plus ellipsis if longer
    return text.length > 140 ? `${text.substring(0, 140)}...` : text;
  };

  // If neither summary exists, render nothing
  if (!contentSummary && !commentSummary) return null;

  // Check if the content is long enough to need expansion or if there's a comment summary
  const needsExpansion = (contentSummary?.length || 0) > 140 || commentSummary !== undefined;

  // Return the summary component
  return (
    <div className="mt-2 text-xs leading-normal border-l-2 border-l-orange-200 dark:border-l-zinc-700 pl-3">
      {/* Content Summary Section */}
      {contentSummary && (
        <div className="mb-2">
          <div className="flex items-center mb-1">
            <span className="font-medium text-[#828282] dark:text-zinc-400 text-xs">
              Summary
            </span>
          </div>

          {/* Show either preview or full content based on expanded state */}
          <p className="text-black dark:text-zinc-300">
            {isExpanded ? contentSummary : getPreview(contentSummary)}
          </p>
        </div>
      )}

      {/* Comment Summary Section - Only visible when expanded */}
      {isExpanded && commentSummary && (
        <div className="mb-2">
          <div className="flex items-center mb-1">
            <span className="font-medium text-[#828282] dark:text-zinc-400 text-xs">
              Comments
            </span>
          </div>

          {/* Always show full comment summary when expanded */}
          <p className="text-black dark:text-zinc-300">
            {commentSummary}
          </p>
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