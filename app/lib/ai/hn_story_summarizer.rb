# Service for summarizing Hacker News story articles
# Uses a two-stage AI approach to extract content and create dev-focused summaries
class Ai::HnStorySummarizer
  # Default options for story summarization
  DEFAULT_OPTIONS = {
    # Enable caching of summaries
    cache_summaries: true,

    # Maximum story text length for summarization
    max_text_length: 8000,

    # If true, include full story text in prompt
    # If false, include only truncated text if it exceeds max_text_length
    include_full_text: false,

    # Include summary context like score, comment count
    include_context: true,

    # Custom summary instructions (can be nil to use defaults)
    custom_instructions: nil
  }.freeze

  # Define attribute readers/accessors for instance variables
  attr_reader :extraction_adapter, :summary_adapter, :hn_client, :options, :story

  # Initialize the story summarizer
  # @param extraction_adapter [Ai::BaseAiAdapter] the AI adapter to use for content extraction
  # @param summary_adapter [Ai::BaseAiAdapter] the AI adapter to use for dev-focused summarization
  # @param story_id [Integer] the HN story ID to summarize
  # @param options [Hash] options to override defaults
  def initialize(extraction_adapter, summary_adapter, story_id, options = {})
    # Save the AI adapter for content extraction (Stage 1)
    @extraction_adapter = extraction_adapter

    # Save the AI adapter for dev-focused summarization (Stage 2)
    @summary_adapter = summary_adapter

    # Create a new HN API client
    @hn_client = HnApiClient.new

    # Merge default options with provided options
    @options = DEFAULT_OPTIONS.merge(options)

    # Fetch and validate the story using the provided ID
    @story = fetch_and_validate_story(story_id)
  end

  # Generate a summary of the HN story's article content
  # @return [String] the generated summary
  def generate_story_summary
    # Check if we have a cached summary and return it if available
    cached = get_cached_summary_if_enabled

    # Return the cached summary if we found one
    return cached if cached

    # STAGE 1: Extract detailed content from the article URL
    content, citations = extract_technical_content

    puts "CITATIONS: #{citations}"

    # STAGE 2: Generate dev-focused summary from the technical content
    final_summary = generate_dev_summary(content, citations)

    # Save the generated summary to our cache if caching is enabled
    cache_summary_if_enabled(final_summary)

    # Return the newly generated summary
    final_summary
  end

  private

  # Get the content hash for the current story
  # This is memoized so it's only calculated once per story
  # @return [String] the SHA-256 hash for the story URL
  def content_hash
    # Calculate and store the hash of the story URL
    @content_hash ||= Digest::SHA256.hexdigest(story["url"])
  end

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
  # @return [String, nil] the cached summary or nil if not found/disabled
  def get_cached_summary_if_enabled
    # Check if caching is enabled and if we have a cached summary for this hash
    if options[:cache_summaries] && (cached_summary = get_cached_summary)
      # Log that we're using a cached summary instead of generating a new one
      Rails.logger.info("Using CACHED SUMMARY for story ##{story['id']}")

      # Return the cached summary we found
      return cached_summary
    end

    # Return nil if caching is disabled or no cached summary was found
    nil
  end

  # STAGE 1: Extract technical content from the article URL
  # @return [Array] [content, citations] where content is the extracted technical content and citations is an array of
  # citation URLs
  # @raise [RuntimeError] if extraction fails
  def extract_technical_content
    # Log the start of extraction with story ID and URL for tracking in logs
    Rails.logger.info("STAGE 1: Extracting technical content from URL for story ##{story['id']}: #{story['url']}")

    # Generate prompts for the extraction AI model
    system_prompt, user_prompt = create_extraction_prompts

    # Debug output to help troubleshoot prompt issues
    puts "SYSTEM PROMPT: #{system_prompt}"
    puts "USER PROMPT: #{user_prompt}"

    begin
      # Call the AI adapter (e.g., Perplexity API) to process the URL and extract relevant content
      # Response is an array where first element is content, second is citations
      content, citations = extraction_adapter.complete(system_prompt, user_prompt)

      # Validate that we have actual content to work with
      if !content || content.strip.empty?
        raise "Empty content extracted for URL: #{story['url']}"
      end

      # Log successful extraction for monitoring
      Rails.logger.info("STAGE 1 COMPLETE: Successfully extracted technical content")

      # Log citation count for analytics and debugging
      unless citations.empty?
        Rails.logger.info("Found #{citations.length} citations in extracted content")
      end

      # Return both the extracted content and any citations as an array
      [ content, citations ]
    rescue StandardError => e
      # Log the specific error details for debugging
      Rails.logger.error("Content extraction failed: #{e.message}")

      # Re-raise with a more user-friendly message that maintains the original error context
      raise "Failed to extract article content: #{e.message}"
    end
  end

  # STAGE 2: Generate dev-focused summary from technical content
  # @param content [String] the technical content from Stage 1
  # @param citations [Array] array of citation URLs from Stage 1
  # @return [String] the dev-focused summary
  # @raise [RuntimeError] if summarization fails
  def generate_dev_summary(content, citations = [])
    # Log that we're starting the dev summary generation process
    Rails.logger.info("STAGE 2: Generating dev-focused summary for story ##{story['id']}")

    # Create the system and user prompts for dev summarization
    system_prompt, user_prompt = create_dev_summary_prompts(content, citations)

    begin
      # Call the summary adapter to generate the dev-focused summary
      # The summary adapter will return a string, not an array with citations
      summary = summary_adapter.complete(system_prompt, user_prompt)

      # Check if the generated summary is empty or invalid
      if !summary || summary.strip.empty?
        # Raise an error if we got an empty summary
        raise "Empty dev summary generated for URL: #{story['url']}"
      end

      # Log that the summarization completed successfully
      Rails.logger.info("STAGE 2 COMPLETE: Successfully generated dev-focused summary")

      # Return the generated summary
      summary
    rescue StandardError => e
      # Log the error that occurred during summarization
      Rails.logger.error("Dev summarization failed: #{e.message}")

      # Re-raise the error with a more descriptive message
      raise "Failed to generate dev summary: #{e.message}"
    end
  end

  # Check if a summary exists in cache for given content
  # @return [String, nil] the cached summary or nil if not found
  def get_cached_summary
    # Look up the summary in Rails cache
    Rails.cache.read(cache_key)
  end

  # Store a summary in the cache
  # @param summary [String] the summary to cache
  def cache_summary_if_enabled(summary)
    # Store the summary in Rails cache if caching is enabled
    Rails.cache.write(cache_key, summary) if options[:cache_summaries]
  end

  # Generate a cache key for the current story
  # @return [String] the formatted cache key
  def cache_key
    # Format: hnsum:story:summary:{hash}
    "hnsum:story:summary:#{content_hash}".freeze
  end

  # Fetch a story's details
  # @param story_id [Integer] the HN story ID to fetch
  # @return [Hash, nil] the story details or nil if not found
  def fetch_story_details(story_id)
    # Use the HN API client to fetch basic story info
    hn_client.get_item(story_id)
  end

  # Create prompts for Stage 1: Technical content extraction
  # @return [Array<String>] [system_prompt, user_prompt]
  def create_extraction_prompts
    # System prompt instructs the model on the extraction task
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

    # User prompt specifies the URL and extraction requirements
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

    # Return an array containing both the system prompt and user prompt
    [ system_prompt, user_prompt ]
  end

  # Create prompts for Stage 2: Dev-focused summary generation
  # @param content [String] the technical content from Stage 1
  # @param citations [Array] array of citation URLs from Stage 1
  # @return [Array<String>] [system_prompt, user_prompt]
  def create_dev_summary_prompts(content, citations = [])
    # Instructions that we'll use both in the system prompt and the user prompt
    instructions = <<~SYSTEM
      You're an expert at summarizing articles shared on Hacker News for a blunt developer audience.

      When provided with an article's detailed technical overview, you prepare the ultra-readable, dev-focused summary.

      Maintain key technical details, but make it a little more concise and engaging.

      Reproduce important data points, specific quotes, URLs., etc., **verbatim**. Do NOT make details up.

      In essence, your summary should be just as informative as the summary you're provided with, but more readable.

      If you find any citations in the technical overview, use them to create a list of numbered references at the end
      of your summary. Format the citations as an ordered Markdown list.

      Produce your summary in *valid Markdown*. Return JUST the summary, no preface or post-text. In other words, don't
      start your summary with, "Ok devs, here's your summary..." or anything like that. Just return the summary starting
      with the first Markdown heading.
    SYSTEM

    # Set the system prompt to the instructions
    system_prompt = instructions

    # Format citations as numbered references if present
    formatted_citations = ""
    unless citations.empty?
      formatted_citations = "\n\n## Citations\n\n"
      citations.each_with_index do |citation, index|
        formatted_citations += "[#{index + 1}] #{citation}\n"
      end
    end

    # User prompt provides the technical content for summarization
    user_prompt = <<~USER
      Here is the technical overview of an article titled "#{story['title']}" that was posted on Hacker News.

      I will provide the technical overview for you, and then provide your instructions to generate the summary.


      --------------- BEGIN TECHNICAL OVERVIEW ---------------

      #{content}
      #{formatted_citations}

      --------------- END TECHNICAL OVERVIEW ---------------



      --------------- BEGIN INSTRUCTIONS FOR SUMMARY GENERATION ---------------

      To create your summary, please follow these instructions:

      #{instructions}

      --------------- END INSTRUCTIONS FOR SUMMARY GENERATION ---------------
    USER

    puts "USER PROMPT: #{user_prompt}"

    # Return an array containing both the system prompt and user prompt
    [ system_prompt, user_prompt ]
  end
end