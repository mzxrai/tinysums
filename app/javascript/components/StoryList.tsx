import React from 'react';
import { HackerNewsStory } from '../types/HackerNews';

/**
 * Props for the StoryList component
 */
interface StoryListProps {
  /** Array of Hacker News stories to display */
  stories: HackerNewsStory[];
}

/**
 * Extracts the hostname from a URL string
 * @param url - The URL to extract the hostname from
 * @returns The extracted hostname or null if invalid
 */
const extractHostname = (url: string): string | null => {
  try {
    const hostname = new URL(url).hostname;
    return hostname === 'news.ycombinator.com' ? null : hostname;
  } catch (e) {
    return null;
  }
};

/**
 * StoryList - A component that displays a list of Hacker News stories
 */
export const StoryList: React.FC<StoryListProps> = ({ stories }) => {
  return (
    <div className="w-full max-w-5xl mx-auto px-6 py-10">
      {/* Page Header */}
      <h1 className="text-2xl font-semibold mb-6 text-zinc-100">Top {stories.length} Hacker News Stories</h1>

      {/* Stories List Container */}
      <div className="bg-zinc-900 rounded-lg shadow-md overflow-hidden ring-1 ring-zinc-800">
        <ul className="divide-y divide-zinc-800">
          {stories.map((story, index) => (
            <li
              key={story.id}
              className="flex py-4 px-5 hover:bg-zinc-800 transition-colors duration-150"
            >
              {/* Story Rank */}
              <span className="text-zinc-500 font-medium w-10 text-right pr-4 pt-0 text-xs">{index + 1}.</span>

              {/* Story Content */}
              <div className="flex-1">
                {/* Story Title */}
                <h2 className="text-sm font-medium mb-1.5 leading-normal">
                  {story.url ? (
                    <>
                      {/* Story Link */}
                      <a
                        href={story.url}
                        className="text-zinc-100 hover:text-zinc-300 transition-colors duration-150"
                      >
                        {story.title}
                      </a>

                      {/* Extract and display hostname if URL is external */}
                      {extractHostname(story.url) && (
                        <span className="text-zinc-500 ml-1.5 text-xs">
                          ({extractHostname(story.url)})
                        </span>
                      )}
                    </>
                  ) : (
                    /* Link to HN comments page if no external URL */
                    <a
                      href={`https://news.ycombinator.com/item?id=${story.id}`}
                      className="text-zinc-100 hover:text-zinc-300 transition-colors duration-150"
                    >
                      {story.title}
                    </a>
                  )}
                </h2>

                {/* Story Metadata */}
                <div className="text-sm flex flex-wrap gap-x-4 items-center">
                  {/* Story Score */}
                  <span className="flex items-center text-emerald-500">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5 mr-1" viewBox="0 0 20 20" fill="currentColor">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                    <span className="font-medium">{story.score}</span>
                  </span>

                  {/* Author Link */}
                  <a
                    href={`https://news.ycombinator.com/user?id=${story.by}`}
                    className="text-zinc-500 hover:text-zinc-100 transition-colors duration-150"
                  >
                    {story.by}
                  </a>

                  {/* Story Time (if available) */}
                  {story.time && (
                    <span className="text-zinc-500">
                      {new Date(story.time * 1000).toLocaleDateString('en-US', {
                        month: 'short',
                        day: 'numeric'
                      })}
                    </span>
                  )}

                  {/* Comments Link */}
                  <a
                    href={`https://news.ycombinator.com/item?id=${story.id}`}
                    className="text-zinc-500 hover:text-zinc-100 transition-colors duration-150 flex items-center"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5 mr-1" viewBox="0 0 20 20" fill="currentColor">
                      <path fillRule="evenodd" d="M18 10c0 3.866-3.582 7-8 7a8.741 8.741 0 01-4.412-1.175L3.235 17.24a.5.5 0 01-.638-.64l1.205-2.964A6.96 6.96 0 014 10c0-3.866 3.582-7 8-7s8 3.134 8 7zM7 9a1 1 0 112 0v2a1 1 0 11-2 0V9zm4 0a1 1 0 112 0v2a1 1 0 11-2 0V9z" clipRule="evenodd" />
                    </svg>
                    {story.descendants || 0}
                  </a>
                </div>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}; 