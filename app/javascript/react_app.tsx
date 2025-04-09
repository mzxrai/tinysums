import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';

// Define the ID of the root DOM element where the React app will be mounted
const ROOT_ELEMENT_ID = 'react-root';

/**
 * @description Main entry point for the React SPA.
 * Finds the root DOM element and renders the main App component into it.
 */
document.addEventListener('DOMContentLoaded', () => {
  // Find the container element in the HTML using its ID
  const container = document.getElementById(ROOT_ELEMENT_ID);

  // Ensure the container element exists before attempting to render
  if (container) {
    // Create a React root attached to the container element
    const root = createRoot(container);
    // Render the top-level App component
    // The App component will manage the rest of the application structure and routing
    root.render(
      // StrictMode is a tool for highlighting potential problems in an application.
      // It activates additional checks and warnings for its descendants.
      <React.StrictMode>
        <App />
      </React.StrictMode>
    );
    // If the container element is not found in the DOM
  } else {
    // Log an error to the console to help with debugging
    console.error(`React root element with ID '${ROOT_ELEMENT_ID}' not found.`);
  }
}); 