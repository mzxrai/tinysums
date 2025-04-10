# Implementation of the AI adapter for Anthropic's Claude models
class Ai::Adapters::AnthropicAdapter < Ai::BaseAiAdapter
  # Class methods for adapter-specific configuration
  class << self
    # Maximum token limit for the model (input + output)
    # @return [Integer] maximum token limit for this model
    def context_window_size
      200000
    end

    # API version
    # @return [String] API version
    def api_version
      "2023-06-01".freeze
    end

    # Base URL for the API
    # @return [String] base URL for the API
    def base_url
      "https://api.anthropic.com/v1".freeze
    end

    # Default options for Anthropic's Claude models with thinking capabilities
    # @return [Hash] Default options for Anthropic's Claude models with thinking capabilities
    def default_completion_options
      # Default options for Anthropic's Claude models with thinking capabilities
      {
        model: "claude-3-7-sonnet-20250219", # Claude 3.7 Sonnet, supports extended thinking
        thinking: {
          type: "enabled",                   # Enable thinking by default
          budget_tokens: 4096                # Default thinking token budget
        },
        max_tokens: 20000
      }.freeze
    end
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
  # @return [String] The generated text
  # @raise [StandardError] If the API call fails
  def call_api(system_prompt, user_prompt)
    # Prepare the API request payload
    payload = @options.merge(
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
        req.headers["anthropic-version"] = self.class.api_version
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