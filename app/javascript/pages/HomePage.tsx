import React from 'react';
// Import the StoryList component
import { StoryList } from '../components/StoryList';
// Import the story type definition
import { HackerNewsStory } from '../types/HackerNews';

// Placeholder data - eventually this will be fetched from an API
const placeholderStories: HackerNewsStory[] = [
  {
    id: 1,
    title: "Placeholder Story 1: Loading...",
    by: "placeholder_user",
    score: 100,
    time: Math.floor(Date.now() / 1000) - 3600, // 1 hour ago
    url: "https://example.com/story1",
    descendants: 50,
    type: "story",
  },
  {
    id: 2,
    title: "Ask HN: How do you implement theme switching?",
    by: "dev_user",
    score: 75,
    time: Math.floor(Date.now() / 1000) - 7200, // 2 hours ago
    url: null, // Example of an Ask HN post with no external URL
    descendants: 30,
    type: "story",
  },
  {
    id: 3,
    title: "Show HN: My New Tailwind Project",
    by: "another_user",
    score: 120,
    time: Math.floor(Date.now() / 1000) - 10800, // 3 hours ago
    url: "https://example.com/showhn",
    descendants: 80,
    type: "story",
  },
];

/**
 * @description The main page component for displaying the list of Hacker News stories.
 * Includes mock AI-generated summaries to demonstrate the feature.
 */
export const HomePage: React.FC = () => {
  console.log('HomePage component rendering');

  // Log a test output to verify basic console logging works
  console.log('Test array:', [1, 2, 3]);

  // Create stories with AI summaries for demonstration
  return (
    <StoryList
      stories={[
        {
          id: 1,
          title: "Show HN: A new framework for building responsive web applications",
          by: "developer123",
          score: 253,
          time: Math.floor(Date.now() / 1000) - 3600,
          url: "https://example.com/new-framework",
          descendants: 87,
          type: "story",
          contentSummary: "This project introduces a lightweight (~5kb) framework for building responsive web applications with a focus on performance and developer experience. Key features include a virtual DOM implementation that's 3x faster than React for common operations, built-in state management without Redux, and a CSS-in-JS solution with zero runtime overhead. The author spent 18 months optimizing the framework for applications with frequent updates and complex UIs.",
          commentSummary: "The discussion is predominantly positive, with many developers impressed by the performance benchmarks. Several commenters have successfully used it for production applications and report 30-40% performance improvements. Main criticisms focus on documentation gaps and potential issues with SSR. The creator is actively responding to feedback and has committed to addressing documentation concerns in the next release."
        },
        {
          id: 2,
          title: "Ask HN: How do you manage work-life balance in tech?",
          by: "balanceseeker",
          score: 186,
          time: Math.floor(Date.now() / 1000) - 7200,
          url: null,
          descendants: 142,
          type: "story",
          contentSummary: "The poster describes struggling with work-life balance after 5 years in tech, working 60+ hour weeks regularly. They're experiencing burnout symptoms and are seeking advice from others who've successfully maintained boundaries. They specifically ask about setting expectations with management, practical scheduling techniques, and how to disconnect mentally after work hours.",
          commentSummary: "The comment section contains diverse perspectives, with the top comment emphasizing that consistently working over 40 hours is unsustainable and often counterproductive. Many commenters share personal stories of burnout and subsequent recovery. Common recommendations include: 1) Strict calendar blocking for personal time, 2) Deliberately disconnecting from work communications after hours, 3) Regular exercise, 4) Seeking employers with explicit work-life balance cultures. Several noted that changing jobs was ultimately necessary to restore balance."
        },
        {
          id: 3,
          title: "Researchers publish breakthrough in quantum computing error correction",
          by: "quantumfan",
          score: 327,
          time: Math.floor(Date.now() / 1000) - 10800,
          url: "https://example.com/quantum-breakthrough",
          descendants: 94,
          type: "story",
          contentSummary: "Researchers at MIT and Google have demonstrated a new quantum error correction technique that achieves a 100x improvement over previous methods. The approach uses a novel lattice arrangement of qubits that enables more efficient detection and correction of both bit-flip and phase-flip errors. The paper suggests this could be a critical step toward fault-tolerant quantum computers. Initial experiments on a 48-qubit system showed sustained coherence for up to 5 minutes versus previous records of only a few seconds.",
        }
      ]}
    />
  );
}; 