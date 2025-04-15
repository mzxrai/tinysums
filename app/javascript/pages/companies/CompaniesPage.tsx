import React from 'react';

/**
 * @description The Companies page component.
 * This is a placeholder component for demonstration of routing.
 * In the future, this will display a list of companies.
 */
export const CompaniesPage: React.FC = () => {
  return (
    <div className="w-full min-h-screen bg-[#f6f6ef] dark:bg-zinc-950/95">
      <div className="w-full max-w-5xl mx-auto px-2 sm:px-6 py-4 sm:py-6">
        <div className="bg-transparent dark:bg-zinc-900 rounded-none dark:rounded-lg dark:shadow-md overflow-hidden ring-0 dark:ring-1 dark:ring-zinc-800 p-6">
          <h1 className="text-2xl font-bold mb-4">Companies</h1>
          <p className="text-gray-700 dark:text-gray-300">
            This is a placeholder for the Companies page. In the future, this will display a list of companies.
          </p>
        </div>
      </div>
    </div>
  );
};

export default CompaniesPage; 