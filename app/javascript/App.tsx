import React from 'react';
// Import React Router
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
// Import page components
import { HomePage } from './pages/HomePage';
import { CompaniesPage } from './pages/companies/CompaniesPage';
// Import the StoryPage for permalink functionality
import { StoryPage } from './pages/StoryPage';
// Import the ClickCounter for now, might be moved later
// TODO: Decide if ClickCounter should be part of the layout or placed elsewhere
import { ClickCounter } from './components/ClickCounter';
// Import TanStack Query components
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
// Import the new layout component
import { AppLayout } from './components/layout/AppLayout';

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
 * Sets up TanStack Query, routing, and the overall application layout.
 * Uses AppLayout to provide a consistent header across all routes.
 */
const App: React.FC = () => {
  // Return the main application structure
  return (
    // Wrap the app with QueryClientProvider
    <QueryClientProvider client={queryClient}>
      {/* Use BrowserRouter for client-side routing */}
      <BrowserRouter>
        {/* Use AppLayout to wrap all routes, providing the header and base structure */}
        <AppLayout>
          {/* Define the routes for the application */}
          {/* These routes will be rendered as children of AppLayout's <main> tag */}
          <Routes>
            {/* Home route */}
            {/* Renders the list of stories */}
            <Route path="/" element={<HomePage />} />
            {/* Story permalink route */}
            {/* Renders a single story's detail page */}
            <Route path="/story/:id" element={<StoryPage />} />
            {/* Companies route */}
            {/* Renders the companies page */}
            <Route path="/companies" element={<CompaniesPage />} />
            {/* Legacy route for backwards compatibility */}
            {/* Redirects /hacker_news to the root path */}
            <Route path="/hacker_news" element={<Navigate to="/" replace />} />
            {/* Default redirect for unmatched routes */}
            {/* Sends users back to the home page if the path is not recognized */}
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </AppLayout>
      </BrowserRouter>
    </QueryClientProvider>
  );
};

// Export the App component as the default export
export default App; 