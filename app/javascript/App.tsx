import React from 'react';
// Import React Router
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
// Import page components
import { HomePage } from './pages/HomePage';
import { CompaniesPage } from './pages/companies/CompaniesPage';
// Import the StoryPage for permalink functionality
import { StoryPage } from './pages/StoryPage';
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
 * Sets up the overall layout structure, 
 * and renders the main page content using React Router.
 * Routes are configured here to enable direct URL navigation.
 */
const App: React.FC = () => {
  // Return the main application structure
  return (
    // Wrap the app with QueryClientProvider
    <QueryClientProvider client={queryClient}>
      {/* Use BrowserRouter for client-side routing */}
      <BrowserRouter>
        {/* Main content area */}
        <main>
          {/* Define the routes for the application */}
          <Routes>
            {/* Home route */}
            <Route path="/" element={<HomePage />} />
            {/* Story permalink route - for direct linking to summaries */}
            <Route path="/story/:id" element={<StoryPage />} />
            {/* Companies route */}
            <Route path="/companies" element={<CompaniesPage />} />
            {/* Legacy route for backwards compatibility */}
            <Route path="/hacker_news" element={<Navigate to="/" replace />} />
            {/* Add additional routes here as needed, e.g.: */}
            {/* <Route path="/company/:id" element={<CompanyDetailPage />} /> */}
            {/* Default redirect for unmatched routes */}
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>
        {/* Render the ClickCounter globally at the bottom */}
        {/* This might be moved or removed depending on future requirements */}
        <ClickCounter />
      </BrowserRouter>
    </QueryClientProvider>
  );
};

// Export the App component as the default export
export default App; 