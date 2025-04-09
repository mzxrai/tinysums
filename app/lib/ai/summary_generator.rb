# Service for generating AI summaries for Hacker News stories and comments
# Uses adapter pattern to support multiple AI providers
class Ai::SummaryGenerator
  # Default options for summary generation
  DEFAULT_OPTIONS = {
    max_length: 500,
    language: "en"
  }.freeze

  # Initialize the summary generator with a specific adapter
  # @param adapter [Ai::BaseAiAdapter] the AI adapter to use for summary generation
  # @param options [Hash] default options to use for this instance
  def initialize(adapter, options = {})
    # Store the AI adapter for making summarization requests
    @adapter = adapter
    # Merge default options with provided options
    @options = DEFAULT_OPTIONS.merge(options)
    # Create a thread summarizer using our adapter
    @thread_summarizer = Ai::HnThreadSummarizer.new(adapter)
  end

  # Generate a summary of an article's content
  # @param content [String] the content to summarize
  # @param options [Hash] additional options to override instance defaults
  # @return [String] the generated summary
  def generate_content_summary(content, options = {})
    # Merge instance options with method-specific options
    opts = @options.merge(options)

    # Log the summarization request
    Rails.logger.info("Generating content summary with #{@adapter.class.name}")

    # Use the adapter to generate a summary
    @adapter.generate_summary(content, opts)
  end

  # Generate a summary of an article's comments
  # @param story_id [Integer] the HN story ID to fetch comments for
  # @param options [Hash] additional options to override instance defaults
  # @return [String] the generated comment summary
  def generate_comment_summary(story_id, options = {})
    # Merge instance options with method-specific options
    opts = @options.merge(options)

    # Log the summarization request
    Rails.logger.info("Generating comment summary for story ##{story_id} with #{@adapter.class.name}")

    # Use our specialized thread summarizer for HN comments
    @thread_summarizer.generate_thread_summary(story_id, opts)
  end

  # Generate both content and comment summaries for a story
  # @param story_id [Integer] the HN story ID
  # @param content [String, nil] optional content if already fetched
  # @param options [Hash] additional options to override instance defaults
  # @return [Hash] hash with :content_summary and :comment_summary keys
  def generate_story_summaries(story_id, content = nil, options = {})
    # Merge instance options with method-specific options
    opts = @options.merge(options)

    # Fetch content if not provided
    content ||= fetch_content(story_id)

    # Generate summaries
    content_summary = generate_content_summary(content, opts)
    comment_summary = generate_comment_summary(story_id, opts)

    # Return both summaries in a hash
    {
      content_summary: content_summary,
      comment_summary: comment_summary
    }
  end

  private

  # Fetch the comments for a story (stubbed implementation)
  # @param story_id [Integer] the HN story ID to fetch comments for
  # @return [Array<Hash>] array of comment hashes
  def fetch_comments(story_id)
    # This is now handled by the HnThreadSummarizer
    Rails.logger.info("Comment fetching handled by HnThreadSummarizer for story ##{story_id}")
    []
  end

  # Fetch the content for a story (stubbed implementation)
  # @param story_id [Integer] the HN story ID to fetch content for
  # @return [String] the article content
  def fetch_content(story_id)
    # Stub implementation - will fetch real content in the future
    Rails.logger.info("Fetching content for story ##{story_id}")

    # Return placeholder text for now
    "This is a placeholder for article content that would be fetched from the URL."
  end
end