# Service for summarizing Hacker News story articles
# Uses AI to fetch and summarize article content
class Ai::HnStorySummarizer
  # Default options for story summarization
  DEFAULT_OPTIONS = {
    # Enable caching of summaries
    cache_summaries: true
  }.freeze

  # Define attribute readers for instance variables
  attr_reader :adapter, :hn_client, :options

  # Initialize the story summarizer
  # @param adapter [Ai::BaseAiAdapter] the AI adapter to use for summarization
  # @param hn_client [HnApiClient] client for interacting with HN API
  # @param options [Hash] options to override defaults
  def initialize(adapter, hn_client = nil, options = {})
    # Save the AI adapter for making summarization requests
    @adapter = adapter

    # Create or use provided HN API client
    @hn_client = hn_client || HnApiClient.new

    # Merge default options with provided options
    @options = DEFAULT_OPTIONS.merge(options)
  end

  # Generate a summary of a HN story's article content
  # @param story_id [Integer] the HN story ID
  # @return [String] the generated summary or nil if story not found
  def generate_story_summary(story_id)
    # Fetch story and validate its URL
    story = fetch_and_validate_story(story_id)

    # Generate a unique hash for this URL to use as a cache key
    content_hash = generate_content_hash(story["url"])

    # Check if we have a cached summary and return it if available
    cached = get_cached_summary_if_enabled(content_hash, story["id"])

    # Return the cached summary if we found one
    return cached if cached

    # Execute the main summarization process to generate a new summary
    summary = execute_summarization(story)

    # Save the generated summary to our cache if caching is enabled
    cache_summary(content_hash, summary) if options[:cache_summaries]

    # Return the newly generated summary
    summary
  end

  private

  # Fetch story details and validate it has a URL
  # @param story_id [Integer] the HN story ID
  # @return [Hash] the validated story details
  # @raise [RuntimeError] if story not found or has no URL
  def fetch_and_validate_story(story_id)
    # Fetch the story details from the HN API
    story = fetch_story_details(story_id)

    # Log the story details for debugging purposes
    Rails.logger.debug("Story details: #{story.inspect}")

    # Raise an error if no story was found with this ID
    raise "Story not found" unless story

    # Raise an error if the story doesn't have a URL to summarize
    raise "No URL available for this story" unless story["url"]

    # Return the validated story object
    story
  end

  # Get cached summary if caching is enabled
  # @param content_hash [String] the hash to look up
  # @param story_id [String] the story ID for logging
  # @return [String, nil] the cached summary or nil if not found/disabled
  def get_cached_summary_if_enabled(content_hash, story_id)
    puts "GET CACHED SUMMARY IF ENABLED: #{options[:cache_summaries]}"

    # Check if caching is enabled and if we have a cached summary for this hash
    if options[:cache_summaries] && (cached_summary = get_cached_summary(content_hash))
      # Log that we're using a cached summary instead of generating a new one
      Rails.logger.info("Using CACHED SUMMARY for story ##{story_id}")

      # Return the cached summary we found
      return cached_summary
    end

    # Return nil if caching is disabled or no cached summary was found
    nil
  end

  # Execute the article summarization
  # @param story [Hash] the story being summarized
  # @return [String] the final summary
  # @raise [RuntimeError] if summarization fails
  def execute_summarization(story)
    # Log that we're starting the summarization process
    Rails.logger.info("Summarizing article from URL for story ##{story['id']}: #{story['url']}")

    # Create the system and user prompts for the AI
    system_prompt, user_prompt = create_prompts(story)

    begin
      # Call the AI adapter to generate the summary
      summary = adapter.complete(system_prompt, user_prompt)

      # Check if the generated summary is empty or invalid
      if !summary || summary.strip.empty?
        # Raise an error if we got an empty summary
        raise "Empty summary generated for URL: #{story['url']}"
      end

      # Log that the summarization completed successfully
      Rails.logger.info("COMPLETE: Successfully generated summary for story ##{story['id']}")

      # Return the generated summary
      summary
    rescue StandardError => e
      # Log the error that occurred during summarization
      Rails.logger.error("Summarization failed: #{e.message}")

      # Re-raise the error with a more descriptive message
      raise "Failed to summarize article: #{e.message}"
    end
  end

  # Generate a hash for URL to use as cache key
  # @param url [String] the URL to hash
  # @return [String] the SHA-256 hash string of the URL
  def generate_content_hash(url)
    # Create a SHA-256 hash of the URL for caching purposes
    Digest::SHA256.hexdigest(url)
  end

  # Check if a summary exists in cache for given content
  # @param content_hash [String] the hash of the content
  # @return [String, nil] the cached summary or nil if not found
  def get_cached_summary(content_hash)
    # Look up the summary in our cache using the hash
    summary_cache[content_hash]
  end

  # Store a summary in the cache
  # @param content_hash [String] the hash of the content
  # @param summary [String] the summary to cache
  def cache_summary(content_hash, summary)
    # Store the summary in our cache using the hash as key
    summary_cache[content_hash] = summary
  end

  # Fetch a story's details
  # @param story_id [Integer] the HN story ID to fetch
  # @return [Hash, nil] the story details or nil if not found
  def fetch_story_details(story_id)
    # Use the HN API client to fetch basic story info
    hn_client.get_item(story_id)
  end

  # Create prompts for article summarization
  # @param story [Hash] the story being summarized
  # @return [Array<String>] [system_prompt, user_prompt]
  def create_prompts(story)
    # System prompt instructs the model on the summarization task
    system_prompt = <<~SYSTEM
      You are an expert at accessing URLs and creating comprehensive technical summaries for developer audiences.

      When given a URL, your task is to:
      1. Access the URL and read the entire article
      2. Create an exhaustive technical summary that captures ALL important information
      3. Include verbatim quotes of key points, maintaining their exact wording
      4. Preserve all technical details, data points, numbers, and statistics
      5. Include any code snippets exactly as they appear
      6. Capture methodologies, algorithms, and technical approaches described

      Your summary should be thorough and comprehensive, not missing any significant technical information.
      It should be written for a sophisticated technical audience of software developers and engineers.
    SYSTEM

    # User prompt specifies the URL and summarization requirements
    user_prompt = <<~USER
      Please access this URL and provide an exhaustive technical rundown: #{story['url']}

      This article was posted on Hacker News with the title: "#{story['title']}"

      I need a concise yet detailed overview that:
      - Includes ALL key technical concepts, approaches and methodologies
      - Preserves verbatim quotes from key figures or experts
      - Includes ALL important data points, numbers, and statistics
      - Captures ALL technical specs, parameters, and benchmarks
      - Includes any high-value code examples exactly as they appear
      - Preserves ALL algorithm details, architectural decisions, and design patterns mentioned
      - Highlights trade-offs, limitations, and technical challenges mentioned
      - Includes ALL relevant URLs, references to tools, libraries, or resources **verbatim**
      - Uses simple, understandable, blunt language avoiding unnecessarily large words

      Ensure the overview is comprehensive while being well-organized and readable.

      Format the overview in valid Markdown. Don't include any introductory text like "Here's an overview...";
      instead, return the overview by itself.
    USER

    puts "SYSTEM PROMPT: #{system_prompt}"
    puts "USER PROMPT: #{user_prompt}"

    # Return an array containing both the system prompt and user prompt
    [ system_prompt, user_prompt ]
  end
end