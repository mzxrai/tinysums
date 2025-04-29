/**
 * Context for managing the expansion state of story summaries.
 * Provides a centralized way to track and control which summaries are expanded or collapsed.
 */
import React, { createContext, useState, useContext, ReactNode, useMemo, useCallback, useEffect } from 'react';

// Define the shape of the expansion state object
// Keys are summary indices, values are boolean (true = expanded, false = collapsed)
interface ExpansionState {
  [index: number]: boolean;
}

// Define the context shape
interface SummaryContextType {
  // Function to check if a specific summary index should be expanded
  isExpanded: (index: number) => boolean;
  // Function to toggle the expansion state of a single summary
  toggleSummary: (index: number) => void;
  // Function to expand all registered summaries
  expandAll: () => void;
  // Function to collapse all registered summaries
  collapseAll: () => void;
  // Function to register a summary component with the context
  registerSummary: (index: number) => void;
  // Function to get the current global expansion state (all expanded or not)
  // Useful for the Expand/Collapse All button text
  isAllExpanded: () => boolean;
}

// Create the context with default no-op implementations
const SummaryContext = createContext<SummaryContextType>({
  isExpanded: () => false,
  toggleSummary: () => { },
  expandAll: () => { },
  collapseAll: () => { },
  registerSummary: () => { },
  isAllExpanded: () => false,
});

// Props for the provider component
interface SummaryProviderProps {
  children: ReactNode;
}

/**
 * Provider component that wraps the app to provide summary expansion state.
 * Manages a single state object tracking the expansion of all registered summaries.
 * @param {SummaryProviderProps} props - The props for the component.
 * @param {ReactNode} props.children - Child components that will have access to the context.
 * @returns {JSX.Element} Provider component with context.
 */
export const SummaryProvider: React.FC<SummaryProviderProps> = ({ children }) => {
  // State to track the expansion state of all summaries { index: isExpanded }
  const [expansionState, setExpansionState] = useState<ExpansionState>({});

  // State to track the indices of all currently registered summary components
  const [registeredIndices, setRegisteredIndices] = useState<number[]>([]);

  /**
   * Register a summary with a specific index.
   * Adds the index to the list of known summaries.
   * @param {number} index - The index of the summary to register.
   * @returns {void}
   */
  const registerSummary = useCallback((index: number) => {
    // Add index to registered list if not already present
    setRegisteredIndices(prev => prev.includes(index) ? prev : [...prev, index]);

    // Initialize the expansion state for this new summary to false (collapsed)
    // if it doesn't have an entry yet.
    setExpansionState(prev => {
      // Check if state already exists for this index
      if (prev[index] === undefined) {
        // If not, initialize it to collapsed (false)
        return { ...prev, [index]: false };
      }
      // Otherwise, return the state unchanged
      return prev;
    });
  }, []);

  /**
   * Check if a specific summary index is currently expanded.
   * Reads directly from the expansionState object.
   * @param {number} index - The index to check.
   * @returns {boolean} True if the summary is expanded, false otherwise.
   */
  const isExpanded = useCallback((index: number): boolean => {
    // Return the state for the index, defaulting to false if not found
    return expansionState[index] || false;
  }, [expansionState]);

  /**
   * Toggle the expansion state of a single summary index.
   * Flips the boolean value for the given index in the expansionState.
   * @param {number} index - The index of the summary to toggle.
   * @returns {void}
   */
  const toggleSummary = useCallback((index: number) => {
    // Update the state by flipping the value for the specific index
    setExpansionState(prev => ({
      ...prev,
      // Get the current state, default to false, then flip it
      [index]: !(prev[index] || false),
    }));
  }, []);

  /**
   * Expand all registered summaries.
   * Sets the state for all registered indices to true.
   * @returns {void}
   */
  const expandAll = useCallback(() => {
    // Create a new state object
    const newState: ExpansionState = {};
    // Iterate over all registered indices
    registeredIndices.forEach(index => {
      // Set each registered index to expanded (true)
      newState[index] = true;
    });
    // Set the new state
    setExpansionState(newState);
  }, [registeredIndices]);

  /**
   * Collapse all registered summaries.
   * Sets the state for all registered indices to false.
   * @returns {void}
   */
  const collapseAll = useCallback(() => {
    // Create a new state object
    const newState: ExpansionState = {};
    // Iterate over all registered indices
    registeredIndices.forEach(index => {
      // Set each registered index to collapsed (false)
      newState[index] = false;
    });
    // Set the new state
    setExpansionState(newState);
  }, [registeredIndices]);

  /**
   * Check if all registered summaries are currently expanded.
   * Useful for determining the state of the Expand/Collapse All button.
   * @returns {boolean} True if all registered summaries are expanded, false otherwise.
   */
  const isAllExpanded = useCallback((): boolean => {
    // If there are no registered summaries, consider them collapsed (not expanded)
    if (registeredIndices.length === 0) {
      return false;
    }
    // Check if *every* registered index has a true value in expansionState
    return registeredIndices.every(index => expansionState[index] === true);
  }, [registeredIndices, expansionState]);

  // Memoize the context value to prevent unnecessary re-renders
  const value = useMemo(() => ({
    isExpanded,
    toggleSummary,
    expandAll,
    collapseAll,
    registerSummary,
    isAllExpanded,
  }), [isExpanded, toggleSummary, expandAll, collapseAll, registerSummary, isAllExpanded]);

  // Provide the context to children
  return (
    <SummaryContext.Provider value={value}>
      {children}
    </SummaryContext.Provider>
  );
};

/**
 * Custom hook for consuming the summary context.
 * Simplifies accessing the context values in components.
 * @returns {SummaryContextType} The summary context value.
 */
export const useSummary = () => useContext(SummaryContext);

export default SummaryContext; 