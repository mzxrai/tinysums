# Implementation of the AI adapter for Google's Gemini models
class Ai::Adapters::GoogleAdapter < Ai::BaseAiAdapter
  # Default options for Google's Gemini models with thinking capabilities
  DEFAULT_OPTIONS = {
    model: "gemini-2.5-pro-preview-03-25" # Using the latest thinking model
  }.freeze

  # Base URL for the Google Generative Language API
  BASE_URL = "https://generativelanguage.googleapis.com/v1beta".freeze

  # Initialize the Google adapter
  # @param api_key [String] The Google API key
  # @param options [Hash] Configuration options for the adapter
  def initialize(api_key, options = {})
    @api_key = api_key
    @options = DEFAULT_OPTIONS.merge(options)
    @connection = create_connection
  end

  # Returns model-specific context window limits for Gemini models
  # @return [Hash] context window information
  def context_window_info
    {
      # Gemini Pro 2.5 has a 1M token context window
      max_token_limit: 1000000,

      # Optimal chunk size (very large due to Gemini's massive context window)
      optimal_chunk_size: 800000
    }
  end

  # Generate a summary of the provided content
  # @param content [String] The content to summarize
  # @param options [Hash] Additional options for the summary generation
  # @return [String] The generated summary
  def generate_summary(content, options = {})
    opts = @options.merge(options)

    # Create a prompt for the content summary
    prompt = "Summarize the following article in a concise, informative manner. " \
             "Focus on the key points, main arguments, and important details. " \
             "The summary should be comprehensive yet easy to read:\n\n#{content}"

    Rails.logger.info("Generating content summary with Google Gemini (#{opts[:model]})")

    # Call the API
    call_api(prompt, opts)
  end

  # Generate a summary of the provided comments
  # @param comments [Array<Hash>] Array of comment hashes to summarize
  # @param options [Hash] Additional options for the summary generation
  # @return [String] The generated summary of comments
  def generate_comment_summary(comments, options = {})
    opts = @options.merge(options)

    # Format comments into a text representation
    comments_text = format_comments(comments)

    # Create a prompt for the comment summary
    prompt = "Analyze and summarize the following discussion from Hacker News comments. " \
             "Highlight key perspectives, popular viewpoints, technical insights, and areas of debate. " \
             "Create a coherent summary that captures the essence of the conversation:\n\n#{comments_text}"

    Rails.logger.info("Generating comment summary with Google Gemini (#{opts[:model]}) for #{comments.size} comments")

    # Call the API
    call_api(prompt, opts)
  end

  private

  # Format comments into a text representation
  # @param comments [Array<Hash>] Array of comment hashes
  # @return [String] Formatted comments text
  def format_comments(comments)
    # If no comments, return empty string
    return "" if comments.empty?

    # Format each comment
    comments.map.with_index do |comment, index|
      "Comment ##{index + 1} by #{comment['author'] || 'Anonymous'} (Score: #{comment['score'] || 'N/A'}):\n" \
      "#{comment['text']}\n\n"
    end.join("---\n\n")
  end

  # Create a Faraday connection
  # @return [Faraday::Connection] Faraday connection object
  def create_connection
    Faraday.new(url: BASE_URL) do |conn|
      conn.request :json
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end

  # Call the Google Gemini API using Faraday
  # @param prompt [String] The prompt to send to the API
  # @param options [Hash] Configuration options for the API call
  # @return [String] The generated text
  # @raise [StandardError] If the API call fails
  def call_api(prompt, options = {})
    # Prepare the request payload
    payload = {
      contents: [
        {
          parts: [
            { text: prompt }
          ]
        }
      ],
      generationConfig: {
        maxOutputTokens: options[:max_output_tokens],
        temperature: options[:temperature]
      }
    }

    begin
      # Make the API request
      response = @connection.post do |req|
        req.url "models/#{options[:model]}:generateContent"
        req.params[:key] = @api_key
        req.headers["Content-Type"] = "application/json"
        req.body = payload.to_json
      end

      # Process the response
      if response.success?
        # Extract the generated text from the response
        response.body.dig("candidates", 0, "content", "parts", 0, "text")
      else
        # Handle API error - raise an exception instead of returning an error message
        error_message = response.body["error"]["message"] rescue "Unknown error (HTTP #{response.status})"
        Rails.logger.error("Google Gemini API Error: #{error_message}")
        raise StandardError, "Google Gemini API Error: #{error_message}"
      end
    rescue StandardError => e
      # Log the error and re-raise it
      Rails.logger.error("Google Gemini API Request Error: #{e.message}")
      raise
    end
  end
end