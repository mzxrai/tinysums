import React, { useState, useEffect } from 'react';

/**
 * ClickCounter component displays a counter of clicks anywhere on the page
 */
export const ClickCounter: React.FC = () => {
  // State to track the number of clicks
  const [clickCount, setClickCount] = useState<number>(0);

  useEffect(() => {
    // Event handler to increment the counter
    const handleClick = () => {
      setClickCount((prevCount) => prevCount + 1);
    };

    // Add the event listener to the document
    document.addEventListener('click', handleClick);

    // Clean up the event listener when component unmounts
    return () => {
      document.removeEventListener('click', handleClick);
    };
  }, []); // Empty dependency array means this effect runs once on mount

  return (
    <div className="fixed bottom-4 right-4 bg-zinc-800 text-white px-4 py-2 rounded-lg shadow-lg border border-zinc-700 z-50">
      <div className="flex items-center gap-2">
        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-emerald-400" viewBox="0 0 20 20" fill="currentColor">
          <path fillRule="evenodd" d="M6.672 1.911a1 1 0 10-1.932.518l.259.966a1 1 0 001.932-.518l-.26-.966zM2.429 4.74a1 1 0 10-.517 1.932l.966.259a1 1 0 00.517-1.932l-.966-.26zm8.814-.569a1 1 0 00-1.415-1.414l-.707.707a1 1 0 101.415 1.415l.707-.708zm-7.071 7.072l.707-.707A1 1 0 003.465 9.12l-.708.707a1 1 0 001.415 1.415zm3.2-5.171a1 1 0 00-1.3 1.3l4 10a1 1 0 001.823.075l1.38-2.759 3.018 3.02a1 1 0 001.414-1.415l-3.019-3.02 2.76-1.379a1 1 0 00-.076-1.822l-10-4z" clipRule="evenodd" />
        </svg>
        <span className="font-medium">Clicks: </span>
        <span className="text-emerald-400 font-bold">{clickCount}</span>
      </div>
    </div>
  );
};