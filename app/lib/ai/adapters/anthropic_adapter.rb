# Implementation of the AI adapter for Anthropic's Claude models
class Ai::Adapters::AnthropicAdapter < Ai::BaseAiAdapter
  # Default options for Anthropic's Claude models with thinking capabilities
  DEFAULT_COMPLETION_OPTIONS = {
    model: "claude-3-7-sonnet-20250219", # Using Claude 3.7 Sonnet
    thinking: {
      type: "enabled",                   # Enable thinking by default
      budget_tokens: 4096                # Default thinking token budget
    },
    max_tokens: 20000
  }.freeze

  # API version
  API_VERSION = "2023-06-01"

  # Class methods for adapter-specific configuration
  class << self
    # Maximum token limit for the model (input + output)
    # @return [Integer] maximum token limit for this model
    def context_window_size
      200000
    end

    # Maximum output tokens for the model
    # @return [Integer] maximum output tokens for this model
    def max_output_tokens
      DEFAULT_COMPLETION_OPTIONS[:max_tokens]
    end

    # Base URL for the API
    # @return [String] base URL for the API
    def base_url
      "https://api.anthropic.com/v1".freeze
    end
  end

  # Initialize the Anthropic adapter
  # @param options [Hash] Configuration options for the adapter
  def initialize(options = {})
    @options = DEFAULT_COMPLETION_OPTIONS.merge(options)
    @connection = create_connection
  end

  private

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
      ]
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
        # Find the text content in the response
        # Anthropic responses contain an array of content objects
        # We need to find the one with type: "text"
        text_content = response.body["content"].find { |item| item["type"] == "text" }

        # Extract the text from the content object
        text_content ? text_content["text"] : nil
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