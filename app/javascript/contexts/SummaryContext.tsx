/**
 * Context for managing the global state of summary expansions
 * Provides a way to control all summaries at once with batched rendering
 */
import React, { createContext, useState, useContext, ReactNode, useMemo, useCallback, useEffect } from 'react';

// Define the context shape
interface SummaryContextType {
  // Whether all summaries should be expanded
  globalExpanded: boolean;
  // Whether a specific summary index should be expanded
  shouldExpandIndex: (index: number) => boolean;
  // Function to expand all summaries
  expandAll: () => void;
  // Function to collapse all summaries
  collapseAll: () => void;
  // Function to toggle the state
  toggleAll: () => void;
  // Register a summary component with the context
  registerSummary: (index: number) => void;
}

// Create the context with default values
const SummaryContext = createContext<SummaryContextType>({
  globalExpanded: false,
  shouldExpandIndex: () => false,
  expandAll: () => { },
  collapseAll: () => { },
  toggleAll: () => { },
  registerSummary: () => { },
});

// Props for the provider component
interface SummaryProviderProps {
  children: ReactNode;
}

/**
 * Provider component that wraps the app to provide summary state
 * @param children - Child components that will have access to the context
 */
export const SummaryProvider: React.FC<SummaryProviderProps> = ({ children }) => {
  // State to track whether all summaries should be expanded
  const [globalExpanded, setGlobalExpanded] = useState(false);
  // State to track indices of summaries that are currently registered
  const [summaryIndices, setSummaryIndices] = useState<number[]>([]);
  // State to track indices of summaries that are currently expanded via batched processing
  const [expandedIndices, setExpandedIndices] = useState<number[]>([]);

  // Register a summary with a specific index
  const registerSummary = useCallback((index: number) => {
    setSummaryIndices(prev => {
      if (!prev.includes(index)) {
        return [...prev, index];
      }
      return prev;
    });
  }, []);

  // Handle batch expansion/collapse
  useEffect(() => {
    if (globalExpanded) {
      // Clear expanded indices first
      setExpandedIndices([]);

      // Get sorted indices to expand in order
      const orderedIndices = [...summaryIndices].sort((a, b) => a - b);

      // Gradually expand summaries with a small delay between each
      orderedIndices.forEach((index, i) => {
        setTimeout(() => {
          setExpandedIndices(prev => [...prev, index]);
        }, i * 50); // 50ms delay between each expansion
      });
    } else {
      // Collapse all at once
      setExpandedIndices([]);
    }
  }, [globalExpanded, summaryIndices]);

  // Check if a specific index should be expanded
  const shouldExpandIndex = useCallback((index: number) => {
    return expandedIndices.includes(index);
  }, [expandedIndices]);

  // Function to expand all summaries
  const expandAll = useCallback(() => setGlobalExpanded(true), []);

  // Function to collapse all summaries
  const collapseAll = useCallback(() => setGlobalExpanded(false), []);

  // Function to toggle between expanded and collapsed
  const toggleAll = useCallback(() => setGlobalExpanded(prev => !prev), []);

  // Memoize the context value to prevent unnecessary re-renders
  const value = useMemo(() => ({
    globalExpanded,
    shouldExpandIndex,
    expandAll,
    collapseAll,
    toggleAll,
    registerSummary,
  }), [globalExpanded, shouldExpandIndex, expandAll, collapseAll, toggleAll, registerSummary]);

  // Provide the context to children
  return (
    <SummaryContext.Provider value={value}>
      {children}
    </SummaryContext.Provider>
  );
};

/**
 * Custom hook for consuming the summary context
 * @returns The summary context value
 */
export const useSummary = () => useContext(SummaryContext);

export default SummaryContext; 