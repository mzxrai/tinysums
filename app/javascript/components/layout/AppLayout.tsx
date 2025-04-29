import React from 'react';
// Import the newly created AppHeader component
import { AppHeader } from './AppHeader';

/**
 * @description A layout component that provides a consistent structure
 * including the header for all pages within the React application.
 * It renders the AppHeader and the page-specific content passed as children.
 * 
 * @param {object} props - The component props.
 * @param {React.ReactNode} props.children - The page content to render within the layout.
 * @returns {React.ReactElement} The rendered layout component.
 * 
 * @example
 * <AppLayout>
 *   <SpecificPageComponent />
 * </AppLayout>
 */
export const AppLayout: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  // Return the layout structure
  return (
    // Root container ensuring minimum screen height
    // The background color will be inherited from global styles (e.g., body)
    // ensuring consistency across all pages using this layout.
    <div className="min-h-screen">
      {/* Render the consistent application header */}
      {/* This header will now appear on all pages */}
      <AppHeader />

      {/* Main content area */}
      {/* This semantic tag wraps the primary content of each page */}
      <main>
        {/* Render the child components */}
        {/* This is where the content of HomePage, StoryPage, etc., will be injected */}
        {children}
      </main>
    </div>
  );
}; 