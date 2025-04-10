/**
 * Represents a Hacker News story status
 */
export interface StoryStatus {
  /** Status of the content summary (completed, pending, failed, etc.) */
  content: string;
  /** Status of the comments summary (completed, pending, failed, etc.) */
  comments: string;
  /** Timestamp when the status was last updated */
  updatedAt: number;
}

/**
 * Represents metadata for a summary
 */
export interface SummaryMeta {
  /** Timestamp when the summary was generated */
  generatedAt: number;
  /** Number of words in the summary */
  wordCount: number;
  /** Number of characters in the summary */
  characterCount: number;
}

/**
 * Represents a Hacker News story
 */
export interface HackerNewsStory {
  /** Unique identifier for the story */
  id: number;
  /** Title of the story */
  title: string;
  /** Username of the story submitter */
  by: string;
  /** Score (points) of the story */
  score: number;
  /** Unix timestamp when the story was submitted */
  time: number;
  /** URL to the story content (may be null for Ask HN posts) */
  url: string | null;
  /** Number of comments on the story */
  descendants: number;
  /** Type of the item (usually "story") */
  type?: string;
  /** Status of the summary generation process */
  status?: StoryStatus;
  /** AI-generated summary of the story content */
  contentSummary?: string;
  /** Metadata about the content summary */
  contentSummaryMeta?: SummaryMeta;
  /** AI-generated summary of the story's comment section */
  commentsSummary?: string;
  /** Metadata about the comments summary */
  commentsSummaryMeta?: SummaryMeta;
} 