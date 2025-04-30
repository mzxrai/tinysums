# Service for summarizing Hacker News story articles
# Uses a two-stage AI approach to extract content and create dev-focused summaries
class Ai::HnStorySummarizer
  # Custom error for extraction failures
  class ExtractionError < StandardError; end

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
    max_attempts: 5
  }.freeze

  # JSON schema for Gemini classification response.
  # Ensures the response contains a 'status' field with specific allowed values.
  # Reference: https://ai.google.dev/gemini-api/docs/structured-output?lang=rest
  CLASSIFICATION_SCHEMA = {
    # Specify the top-level type as OBJECT.
    type: "OBJECT",
    # Define the properties within the object.
    properties: {
      # Define the 'status' property.
      status: {
        # Specify the type as STRING.
        type: "STRING",
        # Specify the allowed enum values for status.
        enum: [ "success", "failure" ],
        # Provide a description for the status field.
        description: "Indicates if the text suggests successful URL access and content extraction ('success') or a failure ('failure')."
      },
      # Define the 'reason' property (optional).
      reason: {
        # Specify the type as STRING.
        type: "STRING",
        # Provide a description for the reason field.
        description: "Optional brief explanation if status is 'failure'."
      }
    },
    # Specify that the 'status' property is required.
    required: [ "status" ]
  }.freeze

  # Define attribute readers/accessors for instance variables
  attr_reader :extraction_adapter, :summary_adapter, :extraction_classifier_adapter, :hn_client, :options, :story, :logger

  # Initialize the story summarizer
  # @param extraction_adapter [Ai::BaseAiAdapter] the AI adapter to use for content extraction (e.g., Perplexity)
  # @param summary_adapter [Ai::BaseAiAdapter] the AI adapter to use for dev-focused summarization
  # @param extraction_classifier_adapter [Ai::BaseAiAdapter] the AI adapter used for classifying extraction results
  # @param story_id [Integer] the HN story ID to summarize
  # @param options [Hash] options to override defaults
  # @param logger [Logger] optional logger instance to use (will create one if not provided)
  def initialize(extraction_adapter, summary_adapter, extraction_classifier_adapter, story_id, options = {}, logger = nil)
    # Initialize HN client early for fetching.
    @hn_client = HnApiClient.new

    # Fetch story details first to get the ID for logging.
    # This raises an error if the story is not found, halting initialization.
    @story = fetch_and_validate_story(story_id)

    # Use provided logger or create a new logger instance tagged with the story ID.
    @logger = logger || Rails.logger.tagged("Story ##{@story ? @story['id'] : 'n/a'}")

    # Save the AI adapter for content extraction (Stage 1)
    @extraction_adapter = extraction_adapter

    # Save the AI adapter for dev-focused summarization (Stage 2)
    @summary_adapter = summary_adapter

    # Save the AI adapter for classifying extraction results
    @extraction_classifier_adapter = extraction_classifier_adapter

    # Merge default options with provided options
    @options = DEFAULT_OPTIONS.merge(options)
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

    # Raise an error if no story was found with this ID
    raise "Story not found" unless story

    # Return the validated story object
    story
  end

  # STAGE 1: Extract technical content from the article URL
  # @return [Array] [content, citations] where content is the extracted technical content and citations is an array of
  # citation URLs
  def extract_technical_content
    # Log the start of extraction with story ID and URL for tracking in logs
    logger.info("Stage 1: Extracting technical content from URL: #{story['url']}")

    # Get the maximum number of attempts from options
    max_attempts = options[:max_attempts]

    # Try to extract content with retries if needed
    content, citations = attempt_extraction_with_retries(max_attempts)

    # Return the content and citations, even if extraction failed
    [ content, citations ]
  end

  # Helper method to attempt content extraction with retries
  # @param max_attempts [Integer] maximum number of attempts to try
  # @return [Array] [content, citations] from the extraction on success
  # @raise [ExtractionError] if extraction fails after all attempts
  def attempt_extraction_with_retries(max_attempts)
    # Initialize attempt counter to first attempt
    attempt_count = 1

    # Variable to store the last error encountered
    last_error = nil

    # Loop until we get successful content or exhaust retry attempts
    while attempt_count <= max_attempts
      # Log current attempt if not the first attempt
      logger.info("Attempt #{attempt_count}/#{max_attempts} for extracting content from URL: #{story['url']}") \
        if attempt_count > 1

      # Try a single extraction, catching our specific error
      begin
        # Attempt the extraction, which might raise ExtractionError
        content, citations = try_single_extraction

        # If successful, return the content and citations immediately
        return [ content, citations ]

      # If extraction fails with our specific error
      rescue ExtractionError => e
        # Store the error details
        last_error = e

        # Log the failure for this attempt
        logger.error("Content extraction attempt #{attempt_count}/#{max_attempts} failed: #{e.message}")

        # Increment attempt counter
        attempt_count += 1

        # Sleep for a random amount of time between attempts
        sleep(rand(1..5))

        # Continue to the next iteration if attempts remain
        next
      end
    end

    # If the loop finishes, it means all attempts failed
    # Raise a final error indicating persistent failure, including the last error message
    raise ExtractionError, "*Failure!* Content extraction failed after #{max_attempts} attempts. Last error: #{last_error&.message}"
  end

  # Helper method to try a single extraction
  # @return [Array] [content, citations] from the extraction
  # @raise [ExtractionError] if content extraction fails due to access issues or other errors
  def try_single_extraction
    # Generate system and user prompts for the extraction AI model
    system_prompt, user_prompt = create_extraction_prompts

    # Initialize a var for the extraction summary content and a var for the citations array
    content = nil
    citations = []

    # Try to extract content from the adapter
    begin
      # Call the AI adapter to process the URL and extract content
      content, citations = extraction_adapter.complete(system_prompt, user_prompt)

      # Check if the AI model reported an access failure
      if content_has_access_failure?(content)
        # Raise specific error for access failure
        raise ExtractionError, "Model unable to access URL: #{story['url']}"
      end

      # Log success information only if we have valid content (which implies no error was raised)
      logger.info("Stage 1 complete: Successfully extracted technical content") unless content.nil? || \
                                                                                       content.strip.empty?

      # Return the extracted content and citations on success
      [ content, citations ]
    # Rescue standard errors from the adapter call itself
    rescue StandardError => e
      # Log the specific error details for debugging
      logger.error("Content extraction failed during adapter call: #{e.message}")

      # Wrap the original error in our custom extraction error
      raise ExtractionError, "Extraction adapter failed: #{e.message}", cause: e
    end
  end

  # STAGE 2: Generate dev-focused summary from technical content
  # @param content [String] the technical content from Stage 1
  # @param citations [Array] array of citation URLs from Stage 1
  # @return [String] the dev-focused summary
  # @raise [RuntimeError] if the generated summary is empty
  # @raise [StandardError] Propagates errors from the summary adapter
  def generate_dev_summary(content, citations = [])
    # Log that we're starting the dev summary generation process
    logger.info("Stage 2: Generating dev-focused summary...")

    # Create the system and user prompts for dev summarization
    system_prompt, user_prompt = create_dev_summary_prompts(content, citations)

    # Call the summary adapter to generate the dev-focused summary
    # The summary adapter will return a string, not an array with citations
    # Any StandardError from the adapter will propagate
    summary = summary_adapter.complete(system_prompt, user_prompt)

    # Check if the generated summary is empty or invalid
    if !summary || summary.strip.empty?
      # Raise an error if we got an empty summary
      raise "Empty dev summary generated for URL: #{story['url']}"
    end

    # Log that the summarization completed successfully
    logger.info("Stage 2 complete: Successfully generated dev-focused summary")

    # Return the generated summary
    summary
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
    instructions = <<~INSTRUCTIONS
      Using the article's content as your ground truth, I'd like you to provide a detailed overview in Markdown that:

      1. Includes key technical concepts, approaches and methodologies
      2. Reproduces interesting/important quotes or excerpts from the article **verbatim**
      3. Includes mentioned or cited URLs **verbatim**
      4. Includes important data points, numbers, and statistics **verbatim**
      5. Captures interesting technical specs, parameters, and benchmarks exactly as they appear
      6. Includes any high-value code examples exactly as they appear
      7. Preserves any algorithm details, architectural decisions, and design patterns mentioned
      8. Highlights trade-offs, limitations, and technical challenges mentioned
      9. Uses simple, understandable, blunt language, avoiding unnecessarily large words
    INSTRUCTIONS

    # System prompt instructs the model on the extraction task
    system_prompt = <<~SYSTEM
      You are an expert at accessing URLs and creating comprehensive technical summaries for a software developer
      audience.

      #{instructions}

      Your summary should be thorough and comprehensive, not missing any significant technical information.
      It should be written for a demanding technical audience of skeptical software developers and engineers.
    SYSTEM

    # User prompt specifies the URL and extraction requirements
    user_prompt = <<~USER
      Please access this URL and provide an exhaustive technical overview, formatted in Markdown: #{story['url']}

      This article was posted on Hacker News with the title: "#{story['title']}"

      #{instructions}

      If the article includes code snippets or code samples, and you choose to include them in your overview (which is
      encouraged), reproduce them **verbatim** in Markdown code blocks. Do not modify them in any way.

      Important: If you're unable to access the provided URL, simply return the string "unable to access url" as your
      response. This is essential, as it lets us detect whether the retrieval has failed.

      ---

      To reiterate: Format the overview in valid Markdown. Don't include any introductory text like "Here's an
      overview..."; instead, return the overview itself starting with the first Markdown heading, which should read
      like a punchy headline summarizing the article.
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
      You're an expert at summarizing articles shared on Hacker News for a blunt and discerning software developer
      audience. You write in a moderately spicy tl;dr style without being annoyingly so.

      ## General instructions

      When provided with an article's detailed technical overview, you prepare the ultra-readable, software developer-
      oriented summary.

      Maintain key technical details. At the same time, make your summary a little more concise and engaging. Think less
      "boring blog article no one will ever read" and more "insightful tl;dr for skeptical, quick-witted developers".

      Reproduce important data points, specific quotes, URLs., etc., **verbatim**. Do NOT make details up.

      In essence, your summary should be just as informative as the summary you're provided with, but more readable.
      The goal is to produce awesome summaries that devs will actually want to read on the train or bus each morning.

      ## Summary format

      Produce your summary in *valid Markdown*. Return JUST the summary starting with the first Markdown heading (which
      should be a second-level ("##") heading).

      If you find any citations in the technical overview, use them to create a list of numbered references at the end
      of your summary. Format the citations as proper **Markdown links** in an ordered Markdown list.

      Do not include any preface or post-text. In other words, don't start your summary with, "Ok devs, here's your
      summary..." or anything like that. Also, don't title your summary a "summary for devs" or speak to developers
      directly; the summary is *for* them, but not written *to* them. Developers will be presented with many of these
      summaries on the same webpage side by side, so speaking to them directly would be redundant and annoying.

      If you include URLs in your summary, which is highly encouraged, format them as Markdown links so users can
      easily click through. Make sure to reproduce the URLs verbatim so they're actual functioning links for our users.

      If the overview we provide you includes code snippets or code samples, and you choose to include them in your
      summary, reproduce them **verbatim** with proper Markdown formatting. Do not modify the code in any way.

      When generating Markdown, if you choose to include blockquotes, ensure you first start a **blank new line** and
      then add a ">" character followed by a space then the quote.

      Use proper, valid Markdown syntax for all Markdown elements you include like tables, links, lists, headings, etc.

      ---

      To reiterate: Return your summary starting with the first Markdown heading, which should be descriptive and
      attention-grabbing (punchy, if you will). Immediately grab the reader's attention -- you have 5 seconds to either
      hook them or lose them. Write prose that will appeal to a skeptical, quick-witted software developer audience.
      Quick-witted humor is encouraged, but only if it's appropriate and adds value to the summary.

      Write in a moderately spicy tl;dr style without being annoyingly so. Never be condescending or patronizing.
    SYSTEM

    # Set the system prompt to the instructions
    system_prompt = instructions

    # Format citations as numbered references if present
    # Initialize an empty string to hold the formatted citations.
    formatted_citations = ""
    # Check if the citations array is not empty.
    unless citations.empty?
      # If citations exist, start the formatted string with a Markdown heading for citations, preceded by newlines for spacing.
      formatted_citations = "\n\n## Citations\n\n"
      # Iterate over each citation along with its index (starting from 0).
      citations.each_with_index do |citation, index|
        # Append the formatted citation (e.g., "[1] http://example.com") followed by a newline.
        # We add 1 to the index because list numbering typically starts from 1, not 0.
        formatted_citations += "[#{index + 1}] #{citation}\n"
      end
    end

    # User prompt provides the technical content for summarization
    user_prompt = <<~USER
      Here is the technical overview of an article titled "#{story['title']}" that was posted on Hacker News.

      I will provide the technical overview for you, and then reiterate your instructions to generate the summary.


      --------------- BEGIN TECHNICAL OVERVIEW ---------------

      #{content}
      #{formatted_citations}

      --------------- END TECHNICAL OVERVIEW ---------------



      --------------- BEGIN INSTRUCTIONS FOR SUMMARY GENERATION ---------------

      To create your summary, follow these instructions precisely:

      #{instructions}

      --------------- END INSTRUCTIONS FOR SUMMARY GENERATION ---------------
    USER

    # Return an array containing both the system prompt and user prompt
    [ system_prompt, user_prompt ]
  end

  # Builds the system and user prompts for the Gemini classification request.
  #
  # @param content [String] The text content to be classified.
  # @return [Array<String>] An array containing [system_prompt, user_prompt].
  def build_classification_prompts(content)
    # Define the system prompt instructing Gemini on its classification task.
    system_prompt = <<~SYSTEM
      You are an expert text classifier. You analyze text provided to you, which is the output from another AI model
      whose task was to access a URL and extract its technical content. Your job is to determine if the provided text
      indicates that the original AI *successfully* accessed the URL and extracted meaningful content, or if it
      indicates a *failure* in the AI's URL access/content extraction process.

      *Failures* include: explicit error messages, "unable to access", generic boilerplate, empty/short responses,
      error page content, etc.

      *Success* means the text looks like a plausible summary or extraction of article content. For a summary to be
      considered a success, it should contain no indication that the extraction process failed.

      Respond as valid JSON only using the provided JSON schema.
    SYSTEM

    # Define the user prompt providing the text to classify.
    user_prompt = <<~USER
      Please classify the following text based on whether it indicates successful content extraction or a failure.

      Use the provided JSON schema for your response.

      Text to classify:

      ```
      #{content}
      ```
    USER

    # Return the prompts.
    [ system_prompt, user_prompt ]
  end

  # Calls the configured extraction classifier adapter with the given prompts.
  # Uses the adapter's dedicated method for structured JSON output based on a schema.
  # Handles potential errors during the API call.
  #
  # @param system_prompt [String] The system prompt for the classifier.
  # @param user_prompt [String] The user prompt for the classifier.
  # @return [String, nil] The raw JSON response text from the classifier, or nil if an error occurred.
  def call_extraction_classifier(system_prompt, user_prompt)
    # Log the attempt to call the classifier adapter.
    logger.info("Attempting to classify extraction output via structured JSON...")

    # Call the dedicated adapter method for structured JSON output, passing the required schema.
    @extraction_classifier_adapter.complete_with_json_schema(
      system_prompt,
      user_prompt,
      CLASSIFICATION_SCHEMA
    )

  # Rescue standard errors from the adapter call.
  rescue StandardError => e
    # Log the error encountered during the API call.
    logger.error("Error calling extraction classifier adapter: #{e.message}")

    # Return nil to indicate failure.
    nil
  end

  # Parses and validates the JSON response from the extraction classifier.
  # Ensures the response has the required structure and valid status.
  #
  # @param response_text [String, nil] The raw JSON response text from the classifier.
  # @return [String] The validated status ("success" or "failure"), defaulting to "failure".
  def parse_and_validate_classification(response_text)
    # Default status to failure.
    classification_status = "failure"

    # Proceed only if response text is present.
    if response_text.present?
      # Parse the JSON response.
      parsed_response = JSON.parse(response_text)

      # Validate structure and status value.
      classification_status = validate_parsed_status(parsed_response, response_text)
    else
      # Log warning if response text was empty.
      logger.warn("Extraction classifier returned empty response.")
    end

    # Return the determined status (defaults to "failure").
    classification_status
  # Rescue JSON parsing errors.
  rescue JSON::ParserError => e
    # Log the parsing error.
    logger.error("Error parsing extraction classification response: #{e.message}")

    # Ensure status remains "failure".
    "failure"
  end

  # Validates the status field within the parsed classification response.
  # Helper for `parse_and_validate_classification`.
  #
  # @param parsed_response [Object] The result of JSON.parse.
  # @param raw_response_text [String] The original JSON string (for logging).
  # @return [String] "success" or "failure".
  def validate_parsed_status(parsed_response, raw_response_text)
    # Check if the parsed response is a hash and contains the required 'status' key.
    if parsed_response.is_a?(Hash) && parsed_response.key?("status")
      # Extract the status value.
      status = parsed_response["status"]

      # Return status if valid, otherwise log warning and return "failure".
      return status if [ "success", "failure" ].include?(status)
      logger.warn("Extraction classifier returned invalid status: '#{status}'.")
    else
      # Log warning if JSON structure is invalid.
      logger.warn("Extraction classifier response invalid structure: #{raw_response_text}")
    end

    # Default to failure if validation fails.
    "failure"
  end

  # Classifies the raw output from the extraction AI (Stage 1) using a classification model.
  # Orchestrates calls to helper methods for prompt building, API call, and validation.
  #
  # @param content [String, nil] The raw text content produced by the extraction adapter.
  # @return [String] Returns "success" if classification indicates successful extraction,
  #   "failure" otherwise.
  def classify_extraction_output(content)
    # Handle nil or empty content immediately.
    return "failure" if content.nil? || content.strip.empty?

    # Build the prompts for the classifier.
    system_prompt, user_prompt = build_classification_prompts(content)

    # Call the classifier adapter.
    response_text = call_extraction_classifier(system_prompt, user_prompt)

    # Parse and validate the response.
    classification_status = parse_and_validate_classification(response_text)

    # Log the final classification result.
    logger.info("Extraction classification final status: #{classification_status}")

    # Return the final status.
    classification_status
  end

  # Helper method to check if content has access failure message.
  # Uses a classifier model to analyze the content and determine if it indicates
  # a successful extraction or a failure.
  #
  # @param content [String] the content to check
  # @return [Boolean] true if content indicates URL access failure based on classification
  def content_has_access_failure?(content)
    # Use the new classification system instead of simple string matching.
    # Classify the content using the dedicated classifier method.
    status = classify_extraction_output(content)

    # Return true only if the classification status is "failure".
    status == "failure"
  end
end