import React from 'react';
import { createRoot } from 'react-dom/client';
import { StoryList } from './components/StoryList';
import { ClickCounter } from './components/ClickCounter';
import { HackerNewsStory } from './types/HackerNews';

/**
 * App component that wraps our StoryList and includes the ClickCounter
 */
const App: React.FC<{ stories: HackerNewsStory[] }> = ({ stories }) => {
  return (
    <>
      <StoryList stories={stories} />
      <ClickCounter />
    </>
  );
};

/**
 * Main entry point for the React application
 * This function looks for a data element in the DOM with the stories data
 * and renders the App component with that data
 */
document.addEventListener('DOMContentLoaded', () => {
  const container = document.getElementById('react-root');

  // If there's no container, don't try to render
  if (!container) return;

  // Get the stories data from the data attribute
  const storiesDataElement = document.getElementById('stories-data');

  if (!storiesDataElement) {
    console.error('Stories data element not found');
    return;
  }

  // Parse the stories data from the data attribute
  const storiesJson = storiesDataElement.getAttribute('data-stories');

  if (!storiesJson) {
    console.error('No stories data found');
    return;
  }

  try {
    // Parse the JSON data
    const stories = JSON.parse(storiesJson) as HackerNewsStory[];

    // Create the React root and render the app
    const root = createRoot(container);
    root.render(<App stories={stories} />);
  } catch (e) {
    console.error('Error parsing stories data:', e);
  }
}); 