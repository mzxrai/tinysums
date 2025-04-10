# Defines the base adapter interface for AI providers
# All AI provider adapters must inherit from this class
class Ai::BaseAiAdapter
  # Fixed token-to-character ratio for all models
  # This approximation is used for estimating text length in tokens
  # 1 token is roughly 0.25 characters (or 4 chars per token)
  TOKEN_PER_CHAR_RATIO = 0.25

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

    # Maximum output tokens for the model
    # Override in subclasses to provide model-specific values
    # @return [Integer] maximum output tokens for this model
    def max_output_tokens
      raise NotImplementedError, "#{self.class.name} must implement #max_output_tokens"
    end
  end

  # Generate a summary of the provided content
  # This is a common interface method that should be available in all adapters
  # @param content [String] the content to summarize
  # @param options [Hash] additional options for the summary generation
  # @return [String] the generated summary
  def generate_summary(content, options = {})
    # Default implementation delegates to complete
    # Subclasses can override with provider-specific implementation if needed
    system_prompt = options[:system_prompt] || ""
    complete(system_prompt, content, options)
  end

  # Generate a summary of the provided comments
  # This is a common interface method that should be available in all adapters
  # @param comments [String] formatted comments string to summarize
  # @param options [Hash] additional options for the summary generation
  # @return [String] the generated summary of comments
  def generate_comment_summary(comments, options = {})
    # By default, just use the generate_summary method
    # Subclasses can override with provider-specific implementation if needed
    generate_summary(comments, options)
  end

  # Calculate maximum input size in characters based on context window
  # @return [Integer] maximum input size in characters
  def max_input_chars
    # Calculate how many tokens we can use for input
    max_input_tokens = self.class.context_window_size - self.class.max_output_tokens

    # Convert to characters using the fixed ratio
    (max_input_tokens / TOKEN_PER_CHAR_RATIO).floor
  end

  private

  # Create a Faraday connection
  # @return [Faraday::Connection] Faraday connection object
  def create_connection
    Faraday.new(url: self.class.base_url) do |conn|
      conn.request :json
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end

  # Generic completion method for Claude
  # @param system_prompt [String] system instructions
  # @param user_prompt [String] user message/question
  # @param options [Hash] additional options for completion
  # @return [String] the generated text
  def complete(system_prompt, user_prompt, options = {})
    opts = @options.merge(options)
    Rails.logger.info("Calling API for #{opts[:model]}")
    call_api(system_prompt, user_prompt, opts)
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
end