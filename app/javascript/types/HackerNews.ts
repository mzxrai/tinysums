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
  type: string;
  /** AI-generated summary of the story content (optional) */
  contentSummary?: string;
  /** AI-generated summary of the story's comment section (optional) */
  commentSummary?: string;
} 