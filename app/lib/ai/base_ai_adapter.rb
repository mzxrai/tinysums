# Defines the base adapter interface for AI providers
# All AI provider adapters must inherit from this class
class Ai::BaseAiAdapter
  # Fixed token-to-character ratio for all models
  # This approximation is used for estimating text length in tokens
  # 1 token is roughly 0.25 characters (or 4 chars per token)
  TOKEN_PER_CHAR_RATIO = 0.25

  # Define attribute readers
  attr_reader :options, :connection

  # Class methods for adapter-specific configuration
  class << self
    # Maximum token limit for the model (input + output)
    # Override in subclasses to provide model-specific values
    # @return [Integer] maximum token limit for this model
    def context_window_size
      128000 # Default value
    end

    # Base URL for the API
    # Override in subclasses to provide model-specific values
    # @return [String] base URL for the API
    def base_url
      raise NotImplementedError, "#{self.class.name} must implement #base_url"
    end

    # Default completion options for the model
    # Override in subclasses to provide model-specific values
    # @return [Hash] default completion options for the model
    def default_completion_options
      {
        max_tokens: 20000 # Default value
      }
    end

    # Maximum output tokens for the model
    # @return [Integer] maximum output tokens for this model
    def max_output_tokens
      default_completion_options[:max_tokens]
    end
  end

  # Initialize the Anthropic adapter
  # @param options [Hash] Configuration options for the adapter
  def initialize(options = {})
    @options = self.class.default_completion_options.merge(options)
    @connection = create_connection
  end

  # Calculate maximum input size in characters based on context window
  # @return [Integer] maximum input size in characters
  def max_input_chars
    # Calculate how many tokens we can use for input
    max_input_tokens = self.class.context_window_size - self.class.max_output_tokens

    # Convert to characters using the fixed ratio
    (max_input_tokens / TOKEN_PER_CHAR_RATIO).floor
  end

  # Executes a completion request requiring structured JSON output conforming to a schema.
  # Specific adapters must implement this to handle provider-specific mechanisms
  # for enforcing structured output (e.g., Gemini's response_schema, OpenAI's JSON mode).
  #
  # @param system_prompt [String] The system prompt for the AI.
  # @param user_prompt [String] The user prompt for the AI.
  # @param json_schema [Hash] The JSON schema the response must conform to.
  # @return [String] The raw JSON string response from the AI.
  # @raise [NotImplementedError] If the concrete adapter does not support this feature.
  # @raise [StandardError] If the API call itself fails.
  def complete_with_json_schema(system_prompt, user_prompt, json_schema)
    # Raise error by default, forcing subclasses to implement.
    raise NotImplementedError, "#{self.class.name} does not implement structured JSON completion"

    # Ensure meticulous documentation, including inline comments.
    # Adhere to the <= 10 LOC guideline for the implementing methods.
  end

  # Generic completion method - primary public interface for adapters.
  # Executes the prompt using the configured model and options.
  # @param system_prompt [String] system instructions
  # @param user_prompt [String] user message/question
  # @return [String] the generated text
  def complete(system_prompt, user_prompt)
    Rails.logger.info("Calling API for #{options[:model]}")
    call_api(system_prompt, user_prompt)
  end

  private

  # Create a Faraday connection
  # @return [Faraday::Connection] Faraday connection object
  def create_connection
    Faraday.new(url: self.class.base_url) do |conn|
      conn.request :json
      conn.response :json
      conn.options.timeout = 180 # Read timeout of 180 seconds
      conn.adapter Faraday.default_adapter
    end
  end

  # Get the API key from environment variables
  # @return [String] the API key
  def api_key
    raise NotImplementedError, "#{self.class.name} must implement #api_key"
  end

  # Estimate tokens in text based on character count
  # This is a rough estimation using a fixed ratio
  # @param text [String] text to estimate token count for
  # @return [Integer] estimated token count
  def estimate_tokens(text)
    return 0 if text.nil? || text.empty?

    # Use the fixed token-to-character ratio
    (text.length * TOKEN_PER_CHAR_RATIO).ceil
  end

  # Call the API for a given system prompt and user prompt, returning the generated text.
  # @param system_prompt [String] system instructions
  # @param user_prompt [String] user message/question
  # @return [String] the generated text
  def call_api(system_prompt, user_prompt)
    raise NotImplementedError, "#{self.class.name} must implement #call_api"
  end
end