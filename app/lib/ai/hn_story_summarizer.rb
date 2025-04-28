# Service for summarizing Hacker News story articles
# Uses a two-stage AI approach to extract content and create dev-focused summaries
class Ai::HnStorySummarizer
  # Default options for story summarization
  DEFAULT_OPTIONS = {
    # Maximum story text length for summarization
    max_text_length: 8000,

    # If true, include full story text in prompt
    # If false, include only truncated text if it exceeds max_text_length
    include_full_text: false,

    # Include summary context like score, comment count
    include_context: true,

    # Custom summary instructions (can be nil to use defaults)
    custom_instructions: nil,

    # Maximum number of extraction attempts (initial + retries)
    max_attempts: 3
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
  # @return [nil] if the story doesn't have a URL to summarize
  def generate_story_summary
    # Return nil if this is a text post without a URL
    return nil unless story["url"]

    # STAGE 1: Extract detailed content from the article URL
    content, citations = extract_technical_content

    # STAGE 2: Generate dev-focused summary from the technical content
    final_summary = generate_dev_summary(content, citations)

    # Return the newly generated summary
    final_summary
  end

  private

  # Fetch story details and validate it has a URL
  # @param story_id [Integer] the HN story ID
  # @return [Hash] the validated story details
  # @return [nil] if the story doesn't have a URL (e.g., Ask HN or Show HN posts)
  # @raise [RuntimeError] if story not found
  def fetch_and_validate_story(story_id)
    # Fetch the story details from the HN API
    story = fetch_story_details(story_id)

    # Log the story details for debugging purposes
    Rails.logger.debug("Story details: #{story.inspect}")

    # Raise an error if no story was found with this ID
    raise "Story not found" unless story

    # For Ask HN or Show HN posts that don't have a URL, return the story but log a message
    unless story["url"]
      Rails.logger.info("Story ##{story_id} is a text post without URL, will skip content summary")
      return story
    end

    # Return the validated story object
    story
  end

  # STAGE 1: Extract technical content from the article URL
  # @return [Array] [content, citations] where content is the extracted technical content and citations is an array of
  # citation URLs
  def extract_technical_content
    # Log the start of extraction with story ID and URL for tracking in logs
    Rails.logger.info("Stage 1: Extracting technical content from URL for story ##{story['id']}: #{story['url']}")

    # Get the maximum number of attempts from options
    max_attempts = options[:max_attempts]

    # Try to extract content with retries if needed
    content, citations = attempt_extraction_with_retries(max_attempts)

    # Return the content and citations, even if extraction failed
    [ content, citations ]
  end

  # Helper method to attempt content extraction with retries
  # @param max_attempts [Integer] maximum number of attempts to try
  # @return [Array] [content, citations] from the extraction
  def attempt_extraction_with_retries(max_attempts)
    # Initialize attempt counter to first attempt
    attempt_count = 1

    # Loop until we get successful content or exhaust retry attempts
    while attempt_count <= max_attempts
      # Log current attempt if not the first attempt
      log_extraction_attempt(attempt_count, max_attempts) if attempt_count > 1

      # Try a single extraction using helper method
      content, citations = try_single_extraction

      # Check if extraction failed due to URL access issue
      if content_has_access_failure?(content)
        # Log this specific failure type for monitoring
        Rails.logger.error("Content extraction attempt #{attempt_count}/#{max_attempts} failed: Model unable to access URL")

        # Increment attempt counter for next try
        attempt_count += 1

        # Try again if we haven't reached maximum attempts
        next if attempt_count <= max_attempts
      end

      # Return result (either success or final failed attempt)
      return [ content, citations ]
    end
  end

  # Helper method to check if content has access failure message
  # @param content [String] the content to check
  # @return [Boolean] true if content indicates URL access failure
  def content_has_access_failure?(content)
    # Check if content exists and contains the "unable to access" phrase
    content && content.match?(/unable to access/i)
  end

  # Helper method to log extraction attempt
  # @param attempt_count [Integer] current attempt number
  # @param max_attempts [Integer] maximum number of attempts
  def log_extraction_attempt(attempt_count, max_attempts)
    # Log the current retry attempt number and URL being accessed
    Rails.logger.info("Attempt #{attempt_count}/#{max_attempts} for extracting content from URL: #{story['url']}")
  end

  # Helper method to try a single extraction
  # @return [Array] [content, citations] from the extraction
  def try_single_extraction
    # Generate system and user prompts for the extraction AI model
    system_prompt, user_prompt = create_extraction_prompts

    # Try to extract content, handling potential errors
    begin
      # Call the AI adapter to process the URL and extract content
      content, citations = extraction_adapter.complete(system_prompt, user_prompt)

      # Log success information if we have valid content
      log_extraction_success(content, citations) unless content.nil? || content.strip.empty?

      # Return the extracted content and citations
      [ content, citations ]
    rescue StandardError => e
      # Log the specific error details for debugging
      Rails.logger.error("Content extraction failed: #{e.message}")

      # Return error message as content with empty citations
      [ "Failed to extract article content: #{e.message}", [] ]
    end
  end

  # Helper method to log extraction success information
  # @param content [String] the extracted content
  # @param citations [Array] array of citation URLs
  def log_extraction_success(content, citations)
    # Log successful extraction for monitoring
    Rails.logger.info("Stage 1 complete: Successfully extracted technical content")

    # Log citation count for analytics and debugging
    unless citations.empty?
      # Log the number of citations found in the content
      Rails.logger.info("Found #{citations.length} citations in extracted content")
    end
  end

  # STAGE 2: Generate dev-focused summary from technical content
  # @param content [String] the technical content from Stage 1
  # @param citations [Array] array of citation URLs from Stage 1
  # @return [String] the dev-focused summary
  # @raise [RuntimeError] if summarization fails
  def generate_dev_summary(content, citations = [])
    # Log that we're starting the dev summary generation process
    Rails.logger.info("Stage 2: Generating dev-focused summary for story ##{story['id']}")

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
      Rails.logger.info("Stage 2 complete: Successfully generated dev-focused summary")

      # Return the generated summary
      summary
    rescue StandardError => e
      # Log the error that occurred during summarization
      Rails.logger.error("Dev summarization failed: #{e.message}")

      # Re-raise the error with a more descriptive message
      raise "Failed to generate dev summary: #{e.message}"
    end
  end

  # Fetch a story's details
  # @param story_id [Integer] the HN story ID to fetch
  # @return [Hash, nil] the story details as a hash or nil if not found
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

      If the article includes code snippets or code samples, and you choose to include them in your rundown, reproduce
      them **verbatim**. Do not modify them in any way.

      If you're unable to access the provided URL, simply return the string "unable to access" verbatim somewhere in
      your response. This is important, as it lets us detect whether the retrieval has failed.

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

      ## General instructions

      When provided with an article's detailed technical overview, you prepare the ultra-readable, dev-focused summary.

      Maintain key technical details, but make it a little more concise and engaging.

      Reproduce important data points, specific quotes, URLs., etc., **verbatim**. Do NOT make details up.

      In essence, your summary should be just as informative as the summary you're provided with, but more readable.

      If you find any citations in the technical overview, use them to create a list of numbered references at the end
      of your summary. Format the citations as proper **Markdown links** in an ordered Markdown list.

      ## Summary format

      Produce your summary in *valid Markdown*. Return JUST the summary starting with the first Markdown heading (which
      should be a second-level ("##") heading). Do not include any preface or post-text. In other words, don't start
      your summary with, "Ok devs, here's your summary..." or anything like that. Also, don't title your summary a
      "summary for devs" or speak to developers directly; the summary is *for* them, but not written *to* them.
      Developers will be presented with many of these summaries on the same webpage side by side, so speaking to them
      directly would be redundant and annoying.

      If you include URLs in your summary, format them as Markdown links so users can easily click through.

      If the overview we provide you includes code snippets or code samples, and you choose to include them in your
      summary, reproduce them **verbatim**. Do not modify them in any way.

      When generating Markdown, if you choose to include blockquotes, ensure you first start a **blank new line** and
      then add a ">" character followed by a space then the quote.

      Use proper, valid Markdown syntax for all Markdown elements you include like tables, links, lists, headings, etc.

      ---

      Simply return your summary starting with the first Markdown heading, which should be descriptive and
      attention-grabbing.
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

    # Return an array containing both the system prompt and user prompt
    [ system_prompt, user_prompt ]
  end
end