import React, { useEffect, useRef } from 'react';
import { useParams, Link, useLocation } from 'react-router-dom';
import { useSingleStory } from '../hooks/useSingleStory';
import { StorySummary } from '../components/StorySummary';
import { extractHostname } from '../utils/urlUtils';
// Import the new reusable metadata component
import { StoryMetadata } from '../components/StoryMetadata';

/**
 * Page component for displaying a single story summary by ID
 * 
 * This page is accessed via /story/:id and shows both the article
 * and comments summary for a specific HN story. It handles loading
 * states, scrolling to specific sections, and error handling.
 * The overall page structure (header, min-height, background) is handled by AppLayout.
 * Metadata display is now handled by the StoryMetadata component.
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
  // Use a fallback of 0 if id is somehow undefined, although route should guarantee it
  const hnId = id ? parseInt(id, 10) : 0;

  // Refs to scroll to specific sections
  const commentsRef = useRef<HTMLDivElement>(null);

  // Fetch the story data using our custom hook
  // Provide the hnId to the hook
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
        // Use smooth scrolling for a better user experience
        behavior: 'smooth',
        // Align the top of the comments section with the top of the viewport
        block: 'start'
      });
    }
    // Dependency array includes values that trigger the effect
  }, [isLoading, story, location.hash]);

  // Show loading state
  // Use a simplified container as AppLayout provides the main structure
  if (isLoading) {
    // Return loading skeleton UI
    return (
      // Container for loading state, centered with padding
      // Background is now inherited from AppLayout/global styles
      <div className="w-full max-w-5xl mx-auto px-2 sm:px-6 py-4 sm:py-6">
        {/* Skeleton card mimicking the story layout */}
        <div className="bg-white dark:bg-zinc-800 rounded-md shadow-sm dark:shadow-md p-4">
          {/* Skeleton for title */}
          <div className="h-6 bg-gray-200 dark:bg-zinc-700 rounded w-3/4 mb-4 animate-pulse"></div>
          {/* Skeleton for metadata line 1 */}
          <div className="h-4 bg-gray-100 dark:bg-zinc-600 rounded w-1/2 mb-2 animate-pulse"></div>
          {/* Skeleton for metadata line 2 */}
          <div className="h-4 bg-gray-100 dark:bg-zinc-600 rounded w-1/4 mb-6 animate-pulse"></div>
          {/* Skeleton for summary content */}
          <div className="h-32 bg-gray-50 dark:bg-zinc-700/50 rounded w-full animate-pulse"></div>
        </div>
      </div>
      // Removed outer div with background/min-height
    );
  }

  // Show error state
  // Use a simplified container as AppLayout provides the main structure
  if (isError || !story) {
    // Return error message UI
    return (
      // Container for error state, centered with padding
      // Background is now inherited from AppLayout/global styles
      <div className="w-full max-w-5xl mx-auto px-2 sm:px-6 py-4 sm:py-6">
        {/* Error message card with distinct styling */}
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-900/50 rounded-md p-4">
          {/* Error title */}
          <h2 className="text-red-800 dark:text-red-400 font-medium mb-2">Error loading story</h2>
          {/* Error details paragraph */}
          <p className="text-red-700 dark:text-red-300 mb-4">
            {/* Display specific error message or a generic one */}
            {isError ? (error as Error).message : "The story could not be found"}
          </p>
          {/* Link to navigate back to the home page */}
          <Link
            to="/"
            // Styling for the link button
            className="inline-block bg-red-100 dark:bg-red-900/50 text-red-800 dark:text-red-200 px-3 py-1 rounded-md hover:bg-red-200 dark:hover:bg-red-800/40 transition-colors"
          >
            {/* Link text */}
            Return to Home
          </Link>
        </div>
      </div>
      // Removed outer div with background/min-height
    );
  }

  // Show the story details
  // The main container div no longer needs explicit background or min-height
  return (
    // Container for the story content, centered with padding
    // Background and min-height are handled by AppLayout
    <div className="w-full max-w-5xl mx-auto px-2 sm:px-6 py-4 sm:py-6">
      {/* Back link - allows navigation back to the story list */}
      <div className="mb-6">
        {/* Link component pointing to the root path */}
        <Link
          to="/"
          // Styling for the back link, including icon and hover effect
          className="text-gray-600 dark:text-gray-400 hover:underline flex items-center gap-1"
        >
          {/* Back arrow SVG icon */}
          <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
          </svg>
          {/* Link text - Updated to be more specific */}
          View all HN stories
        </Link>
      </div>

      {/* Story card - contains all details about the story */}
      {/* Apply dark mode background and standard styling */}
      <div className="bg-white dark:bg-zinc-800 rounded-md shadow-sm dark:shadow-md p-4 mb-4">
        {/* Story Title */}
        {/* Links to the original article URL if available */}
        <h1 className="text-lg font-medium mb-2 text-black dark:text-zinc-100">
          {/* Conditional rendering: Link if URL exists, otherwise just title */}
          {story.url ? (
            // Anchor tag linking to the external story URL
            <a
              href={story.url}
              // Styling for the title link, including dark mode adjustments
              className="hover:underline dark:hover:text-zinc-300 transition-colors duration-150"
              target="_blank" // Open in new tab
              rel="noopener noreferrer" // Security best practice
            >
              {/* Display the story title as link text */}
              {story.title}
            </a>
          ) : (
            // Display title as plain text if no URL
            story.title
          )}
        </h1>

        {/* Render the reusable StoryMetadata component */}
        {/* Pass the necessary props from the fetched story data */}
        <StoryMetadata
          storyId={story.id}
          score={story.score}
          author={story.by}
          time={story.time}
          commentCount={story.descendants}
          url={story.url === null ? undefined : story.url}
        />

        {/* Comments summary reference div - used as scroll target */}
        {/* Allows scrolling directly to the comments summary via URL hash */}
        <div ref={commentsRef}></div>

        {/* Render the StorySummary component */}
        {/* Pass necessary props, including summaries, status, and flags */}
        <StorySummary
          storySummary={story.story_summary}
          commentsSummary={story.comments_summary}
          status={story.status}
          hasUrl={!!story.url} // Convert URL presence to boolean
          index={0} // Index not relevant here, but required by prop type
          hnId={story.id}
          forceExpanded={true} // Always show the full summary on the detail page
          hidePermalinks={true} // Permalinks not needed on the detail page itself
        />
      </div>
    </div>
  );
}; 