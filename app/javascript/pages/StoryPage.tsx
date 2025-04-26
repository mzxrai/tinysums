import React, { useEffect, useRef } from 'react';
import { useParams, Link, useLocation } from 'react-router-dom';
import { useSingleStory } from '../hooks/useSingleStory';
import { StorySummary } from '../components/StorySummary';
import { extractHostname } from '../utils/urlUtils';

/**
 * Page component for displaying a single story summary by ID
 * 
 * This page is accessed via /story/:id and shows both the article
 * and comments summary for a specific HN story. It handles loading
 * states, scrolling to specific sections, and error handling.
 * 
 * @returns React component
 */
export const StoryPage: React.FC = () => {
  // Extract the story ID from the URL parameters
  // The id param comes from the route definition in App.tsx
  const { id } = useParams<{ id: string }>();

  // Get location to check for hash fragments (#comments)
  const location = useLocation();

  // Convert the ID string to a number
  // The exclamation mark asserts that id is defined (from the URL)
  const hnId = id ? parseInt(id, 10) : undefined;

  // Refs to scroll to specific sections
  const commentsRef = useRef<HTMLDivElement>(null);

  // Fetch the story data using our custom hook
  const {
    data: story,
    isLoading,
    isError,
    error
  } = useSingleStory(hnId);

  // Handle scrolling to the comments section if URL has #comments
  useEffect(() => {
    // Wait until the data is loaded before attempting to scroll
    if (!isLoading && story && location.hash === '#comments') {
      // Scroll to the comments section
      commentsRef.current?.scrollIntoView({
        behavior: 'smooth',
        block: 'start'
      });
    }
  }, [isLoading, story, location.hash]);

  // Show loading state
  if (isLoading) {
    return (
      <div className="w-full min-h-screen bg-[#f6f6ef] dark:bg-zinc-900">
        <div className="w-full max-w-5xl mx-auto px-2 sm:px-6 py-4 sm:py-6">
          <div className="bg-white dark:bg-zinc-800 rounded-md shadow-sm dark:shadow-md p-4">
            <div className="h-6 bg-gray-200 dark:bg-zinc-700 rounded w-3/4 mb-4 animate-pulse"></div>
            <div className="h-4 bg-gray-100 dark:bg-zinc-600 rounded w-1/2 mb-2 animate-pulse"></div>
            <div className="h-4 bg-gray-100 dark:bg-zinc-600 rounded w-1/4 mb-6 animate-pulse"></div>
            <div className="h-32 bg-gray-50 dark:bg-zinc-700/50 rounded w-full animate-pulse"></div>
          </div>
        </div>
      </div>
    );
  }

  // Show error state
  if (isError || !story) {
    return (
      <div className="w-full min-h-screen bg-[#f6f6ef] dark:bg-zinc-900">
        <div className="w-full max-w-5xl mx-auto px-2 sm:px-6 py-4 sm:py-6">
          <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-900/50 rounded-md p-4">
            <h2 className="text-red-800 dark:text-red-400 font-medium mb-2">Error loading story</h2>
            <p className="text-red-700 dark:text-red-300 mb-4">
              {isError ? (error as Error).message : "The story could not be found"}
            </p>
            <Link
              to="/"
              className="inline-block bg-red-100 dark:bg-red-900/50 text-red-800 dark:text-red-200 px-3 py-1 rounded-md hover:bg-red-200 dark:hover:bg-red-800/40 transition-colors"
            >
              Return to Home
            </Link>
          </div>
        </div>
      </div>
    );
  }

  // Show the story
  return (
    <div className="w-full min-h-screen bg-[#f6f6ef] dark:bg-zinc-900">
      <div className="w-full max-w-5xl mx-auto px-2 sm:px-6 py-4 sm:py-6">
        {/* Back link - updated to "View current stories" */}
        <div className="mb-6">
          <Link
            to="/"
            className="text-gray-600 dark:text-gray-400 hover:underline flex items-center gap-1"
          >
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            View current stories
          </Link>
        </div>

        {/* Story card */}
        <div className="bg-white dark:bg-zinc-800 rounded-md shadow-sm dark:shadow-md p-4 mb-4">
          {/* Title - Link to article if URL exists */}
          <h1 className="text-lg font-medium mb-2 text-black dark:text-zinc-100">
            {story.url ? (
              <a
                href={story.url}
                className="hover:underline dark:hover:text-zinc-300 transition-colors duration-150"
                target="_blank"
                rel="noopener noreferrer"
              >
                {story.title}
              </a>
            ) : (
              story.title
            )}
            {/* Extract and display hostname if URL is external and valid */}
            {story.url && (
              <span className="text-[#828282] dark:text-zinc-500 ml-1 text-xs font-normal">
                ({extractHostname(story.url)})
              </span>
            )}
          </h1>

          {/* Metadata - updated to match StoryList structure */}
          <div className="text-xs flex flex-wrap gap-x-2 items-center text-[#828282] dark:text-zinc-500 mb-4">
            {/* Story Score */}
            <span className="flex items-center dark:text-emerald-500">
              <span className="font-normal">{story.score} points</span>
            </span>

            {/* Separator */}
            <span className="text-gray-400 dark:text-zinc-600">|</span>

            {/* Author Link */}
            <span className="flex items-center">
              <a
                href={`https://news.ycombinator.com/user?id=${story.by}`}
                className="text-[#828282] dark:text-zinc-500 hover:underline dark:hover:text-zinc-100 transition-colors duration-150"
                target="_blank"
                rel="noopener noreferrer"
              >
                {story.by}
              </a>
            </span>

            {/* Separator */}
            <span className="text-gray-400 dark:text-zinc-600">|</span>

            {/* Story Time */}
            {story.time && (
              <span className="text-[#828282] dark:text-zinc-500">
                {new Date(story.time * 1000).toLocaleDateString('en-US', {
                  month: 'short',
                  day: 'numeric',
                })}
              </span>
            )}

            {/* Separator */}
            <span className="text-gray-400 dark:text-zinc-600">|</span>

            {/* Comments Link */}
            <a
              href={`https://news.ycombinator.com/item?id=${story.id}`}
              className="text-[#828282] dark:text-zinc-500 hover:underline dark:hover:text-zinc-100 transition-colors duration-150 flex items-center"
              target="_blank"
              rel="noopener noreferrer"
            >
              {story.descendants ?? 0} comments
            </a>
          </div>

          {/* Comments summary reference div - used for scrolling */}
          <div ref={commentsRef}></div>

          {/* Summary component - with forceExpanded=true to always show full content */}
          <StorySummary
            storySummary={story.story_summary}
            commentsSummary={story.comments_summary}
            status={story.status}
            hasUrl={!!story.url}
            index={0}
            hnId={story.id}
            forceExpanded={true}
            hidePermalinks={true}
          />
        </div>
      </div>
    </div>
  );
}; 