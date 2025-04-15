import React from 'react';
// Import React Router
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
// Import the Header component
import { Header } from './components/layout/Header';
// Import page components
import { HomePage } from './pages/HomePage';
import { CompaniesPage } from './pages/companies/CompaniesPage';
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
 * and renders the main page content using React Router.
 * Routes are configured here to enable direct URL navigation.
 */
const App: React.FC = () => {
  // Apply background color to root element to prevent flash
  React.useLayoutEffect(() => {
    // Get the root HTML element
    const root = document.documentElement;

    // Set a base background color that works for both light/dark modes
    // This is removed when the app is loaded
    const appRoot = document.getElementById('react-root');
    if (appRoot) {
      appRoot.style.backgroundColor = root.getAttribute('data-theme') === 'dark'
        ? 'rgb(9, 9, 11)' // dark mode bg color
        : '#f6f6ef'; // light mode bg color
    }

    // Cleanup function
    return () => {
      if (appRoot) {
        appRoot.style.backgroundColor = '';
      }
    };
  }, []);

  // Return the main application structure
  return (
    // Wrap the app with QueryClientProvider
    <QueryClientProvider client={queryClient}>
      {/* Use BrowserRouter for client-side routing */}
      <BrowserRouter>
        {/* Render the common Header component */}
        <Header />
        {/* Main content area */}
        <main>
          {/* Define the routes for the application */}
          <Routes>
            {/* Home route */}
            <Route path="/" element={<HomePage />} />
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