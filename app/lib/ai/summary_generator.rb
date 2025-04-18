# Service for generating AI summaries for Hacker News stories and comments
# Uses adapter pattern to support multiple AI providers
class Ai::SummaryGenerator
  # Default options for summary generation
  DEFAULT_OPTIONS = {}.freeze

  # Define attribute readers for instance variables
  attr_reader :adapter, :story_id, :options, :thread_summarizer, :story_summarizer
  attr_accessor :article_content

  # Initialize the summary generator with a specific adapter
  # @param adapter [Ai::BaseAiAdapter] the AI adapter to use for summary generation
  # @param story_id [Integer] the HN story ID to generate summaries for
  # @param options [Hash] default options to use for this instance
  def initialize(adapter, story_id, options = {})
    # Store the AI adapter for making summarization requests
    @adapter = adapter

    # Store the story ID
    @story_id = story_id

    # Merge default options with provided options
    @options = DEFAULT_OPTIONS.merge(options)

    # Create a thread summarizer using our adapter
    @thread_summarizer = Ai::HnThreadSummarizer.new(adapter)

    # Create a story summarizer using our adapter
    @story_summarizer = Ai::HnStorySummarizer.new(adapter)

    # Initialize the article content instance var
    @article_content = nil
  end

  # Generate both content and comment summaries for a story
  # @return [Hash] hash with :content_summary and :comment_summary keys
  def generate_summaries
    # Return both summaries in a hash
    {
      story_summary: generate_story_summary
      # comments_summary: generate_comments_summary
    }
  end

  private

  # Generate a summary of an article's content
  # @return [String] the generated summary
  def generate_story_summary
    # Log the summarization request
    Rails.logger.info("Generating story summary with #{adapter.class.name}")

    # Use our specialized story summarizer
    story_summarizer.generate_story_summary(story_id)
  end

  # Generate a summary of an article's comments
  # @return [String] the generated comment summary
  def generate_comments_summary
    # Log the summarization request
    Rails.logger.info("Generating comments summary for story ##{story_id} with #{adapter.class.name}")

    # Use our specialized thread summarizer for HN comments
    thread_summarizer.generate_thread_summary(story_id)
  end
end