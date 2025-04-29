# Implementation of the AI adapter for Perplexity's Sonar-Pro model
class Ai::Adapters::PerplexityAdapter < Ai::BaseAiAdapter
  # Class methods for adapter-specific configuration
  class << self
    # Maximum token limit for the model (input + output)
    # @return [Integer] maximum token limit for this model
    def context_window_size
      128000
    end

    # Base URL for the API
    # @return [String] base URL for the API
    def base_url
      "https://api.perplexity.ai".freeze
    end

    # Default completion options for Perplexity's Sonar-Pro model
    # @return [Hash] Default options for Perplexity's Sonar-Pro model
    def default_completion_options
      # Default options for Perplexity's Sonar-Pro model
      {
        model: "sonar-pro", # Sonar-Pro is their most capable model
        max_tokens: 4096    # Default max tokens for output
      }.freeze
    end
  end

  private

  # Get the API key from environment variables
  # @return [String] the Perplexity API key
  def api_key
    ENV.fetch("PERP_API_KEY")
  end

  # Call the Perplexity API using Faraday
  # @param system_prompt [String] The system prompt to send to the API
  # @param user_prompt [String] The user prompt to send to the API
  # @return [Array<String, Array>] An array where the first element is the generated text and the second element is the
  #   citations array
  # @raise [StandardError] If the API call fails
  def call_api(system_prompt, user_prompt)
    # Prepare the API request payload
    payload = {
      model: options[:model],
      messages: []
    }

    # Add system message if provided
    if system_prompt.present?
      payload[:messages] << { role: "system", content: system_prompt }
    end

    # Add user message
    payload[:messages] << { role: "user", content: user_prompt }

    # Add optional parameters if they exist in options
    [ :max_tokens, :temperature ].each do |param|
      payload[param] = options[param] if options[param]
    end

    begin
      # Make the API request
      response = connection.post do |req|
        req.url "chat/completions"
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.headers["Content-Type"] = "application/json"
        req.body = payload.to_json
      end

      # Process the response
      if response.success?
        puts response.body

        # Extract the content and citations from the response
        content = response.body["choices"][0]["message"]["content"]
        citations = response.body["citations"] || []

        # Return both content and citations
        [ content, citations ]
      else
        # Handle API error
        error_message = response.body["error"]["message"] rescue "Unknown error (HTTP #{response.status})"
        Rails.logger.error("Perplexity API Error: #{error_message}")
        raise StandardError, "Perplexity API Error: #{error_message}"
      end
    rescue StandardError => e
      # Log the error and re-raise it
      Rails.logger.error("Perplexity API Request Error: #{e.message}")
      raise
    end
  end
end