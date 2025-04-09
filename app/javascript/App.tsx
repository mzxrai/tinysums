import React from 'react';
// Import the Header component
import { Header } from './components/layout/Header';
// Import the HomePage component (will be created next)
import { HomePage } from './pages/HomePage';
// Import the ClickCounter for now, might be moved later
import { ClickCounter } from './components/ClickCounter';
// Import TanStack Query components
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

// Create a client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      refetchOnWindowFocus: false,
    },
  },
});

/**
 * @description The main application component.
 * Sets up the overall layout structure, including the Header,
 * and renders the main page content (currently HomePage).
 * It also includes the ClickCounter globally for now.
 */
const App: React.FC = () => {
  // Return the main application structure
  return (
    // Wrap the app with QueryClientProvider
    <QueryClientProvider client={queryClient}>
      {/* Use a React Fragment to group elements without adding an extra DOM node */}
      <>
        {/* Render the common Header component */}
        <Header />
        {/* Main content area */}
        <main>
          {/* Render the HomePage component - this will contain the StoryList */}
          {/* Later, this area will likely be controlled by a router */}
          <HomePage />
        </main>
        {/* Render the ClickCounter globally at the bottom */}
        {/* This might be moved or removed depending on future requirements */}
        <ClickCounter />
      </>
    </QueryClientProvider>
  );
};

// Export the App component as the default export
export default App; 