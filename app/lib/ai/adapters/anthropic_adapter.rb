# Implementation of the AI adapter for Anthropic's Claude models
class Ai::Adapters::AnthropicAdapter < Ai::BaseAiAdapter
  # Default options for Anthropic's Claude models with thinking capabilities
  DEFAULT_COMPLETION_OPTIONS = {
    model: "claude-3-7-sonnet-20250219", # Using Claude 3.7 Sonnet
    thinking: {
      type: "enabled",                   # Enable thinking by default
      budget_tokens: 4096                # Default thinking token budget
    }
  }.freeze

  # Base URL for the Anthropic API
  BASE_URL = "https://api.anthropic.com/v1".freeze

  # API version
  API_VERSION = "2023-06-01"

  # Class methods for adapter-specific configuration
  class << self
    # Maximum token limit for the model (input + output)
    # @return [Integer] maximum token limit for this model
    def context_window_size
      200000
    end
  end

  # Initialize the Anthropic adapter
  # @param options [Hash] Configuration options for the adapter
  def initialize(options = {})
    @options = DEFAULT_COMPLETION_OPTIONS.merge(options)
    @connection = create_connection
  end

  # Generic completion method for Claude
  # @param system_prompt [String] system instructions
  # @param user_prompt [String] user message/question
  # @param options [Hash] additional options for completion
  # @return [String] the generated text
  def complete(system_prompt, user_prompt, options = {})
    opts = @options.merge(options)
    Rails.logger.info("Calling Claude API (#{opts[:model]})")
    call_api(system_prompt, user_prompt, opts)
  end

  private

  # Create a Faraday connection
  # @return [Faraday::Connection] Faraday connection object
  def create_connection
    Faraday.new(url: BASE_URL) do |conn|
      conn.request :json
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end

  # Get the API key from environment variables
  # @return [String] the Anthropic API key
  def api_key
    ENV.fetch("ANTH_API_KEY")
  end

  # Call the Anthropic API using Faraday
  # @param system_prompt [String] The system prompt to send to the API
  # @param user_prompt [String] The user prompt to send to the API
  # @param options [Hash] Configuration options for the API call
  # @return [String] The generated text
  # @raise [StandardError] If the API call fails
  def call_api(system_prompt, user_prompt, options = {})
    # Prepare the API request payload
    payload = DEFAULT_COMPLETION_OPTIONS.merge(
      system: system_prompt,
      messages: [
        { role: "user", content: user_prompt }
      ],
      max_tokens: RESERVED_OUTPUT_TOKENS
    )

    begin
      # Make the API request
      response = @connection.post do |req|
        req.url "messages"
        req.headers["x-api-key"] = api_key
        req.headers["anthropic-version"] = API_VERSION
        req.headers["content-type"] = "application/json"
        req.body = payload.to_json
      end

      # Process the response
      if response.success?
        # Extract the generated text from the response
        response.body.dig("content", 0, "text")
      else
        # Handle API error - raise an exception instead of returning an error message
        error_message = response.body["error"]["message"] rescue "Unknown error (HTTP #{response.status})"
        Rails.logger.error("Anthropic API Error: #{error_message}")
        raise StandardError, "Anthropic API Error: #{error_message}"
      end
    rescue StandardError => e
      # Log the error and re-raise it
      Rails.logger.error("Anthropic API Request Error: #{e.message}")
      raise
    end
  end
end