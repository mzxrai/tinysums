# Implementation of the AI adapter for Google's Gemini models
class Ai::Adapters::GoogleAdapter < Ai::BaseAiAdapter
  # Class methods for adapter-specific configuration
  class << self
    # Maximum token limit for the model (input + output)
    # @return [Integer] maximum token limit for this model
    def context_window_size
      1000000 # 1 million tokens
    end

    # API version
    # @return [String] API version
    def api_version
      "v1beta".freeze
    end

    # Base URL for the API
    # @return [String] base URL for the API
    def base_url
      "https://generativelanguage.googleapis.com/#{api_version}".freeze
    end

    # Default options for Google's Gemini models with thinking capabilities
    # @return [Hash] Default options for Google's Gemini models with thinking capabilities
    def default_completion_options
      # Default options for Google's Gemini models with thinking capabilities
      {
        model: "gemini-2.5-pro-preview-03-25", # Gemini 2.5 Pro Preview, supports thinking
        max_tokens: 20000
      }.freeze
    end
  end

  private

  # Get the API key from environment variables
  # @return [String] the Google Gemini API key
  def api_key
    ENV.fetch("GOOG_GEM_API_KEY")
  end

  # Call the Google Gemini API using Faraday
  # @param system_prompt [String] The system prompt to send to the API
  # @param user_prompt [String] The user prompt to send to the API
  # @return [String] The generated text
  # @raise [StandardError] If the API call fails
  def call_api(system_prompt, user_prompt)
    # Prepare the API request payload
    payload = {
      contents: [
        {
          role: "user",
          parts: [
            { text: user_prompt }
          ]
        }
      ],
      generation_config: {
        max_output_tokens: options[:max_tokens]
      }
    }

    # Add system instruction if provided
    if system_prompt.present?
      payload[:system_instruction] = { parts: [ { text: system_prompt } ] }
    end

    begin
      # Make the API request
      response = connection.post do |req|
        req.url "models/#{options[:model]}:generateContent"
        req.params["key"] = api_key
        req.headers["content-type"] = "application/json"
        req.body = payload.to_json
      end

      # Process the response
      if response.success?
        # Extract the text from the response
        # Gemini API response structure:
        # {
        #   "candidates": [                      # Array of potential response candidates
        #     {
        #       "content": {                     # Content object containing the response
        #         "parts": [                     # Array of content parts (text, images, etc.)
        #           { "text": "Response text" }, # Text part containing the actual response
        #           { ... }                      # Potentially other parts (images, etc.)
        #         ],
        #         "role": "model"               # Role of the message creator
        #       },
        #       "finishReason": "STOP",         # Reason the generation finished
        #       ...                             # Other metadata
        #     }
        #   ],
        #   ...                                 # Other response metadata
        # }
        candidates = response.body["candidates"]

        # If there are candidates and the first candidate has content, extract the text parts
        if candidates.present? && candidates.first["content"].present?
          # Extract all text parts from the first candidate's content
          text_parts = candidates.first["content"]["parts"].select { |part| part["text"].present? }

          # Join all text parts with newlines to create a complete response
          text_parts.map { |part| part["text"] }.join("\n")
        # Otherwise, return nil
        else
          nil
        end
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