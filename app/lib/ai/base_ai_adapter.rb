# Defines the base adapter interface for AI providers
# All AI provider adapters must inherit from this class
class Ai::BaseAiAdapter
  # Fixed token-to-character ratio for all models
  # This approximation is used for estimating text length in tokens
  # 1 token is roughly 0.25 characters (or 4 chars per token)
  TOKEN_PER_CHAR_RATIO = 0.25

  # Reserved tokens for output generation across all models
  # This ensures we always leave enough space for the generated output
  RESERVED_OUTPUT_TOKENS = 15000

  # Class methods for adapter-specific configuration
  class << self
    # Maximum token limit for the model (input + output)
    # Override in subclasses to provide model-specific values
    # @return [Integer] maximum token limit for this model
    def max_token_limit
      8192 # Default value
    end
  end

  # Generate a summary of the provided content
  # @param content [String] the content to summarize
  # @param options [Hash] additional options for the summary generation
  # @return [String] the generated summary
  def generate_summary(content, options = {})
    raise NotImplementedError, "#{self.class.name} must implement #generate_summary"
  end

  # Generate a summary of the provided comments
  # @param comments [Array<Hash>] array of comment hashes to summarize
  # @param options [Hash] additional options for the summary generation
  # @return [String] the generated summary of comments
  def generate_comment_summary(comments, options = {})
    raise NotImplementedError, "#{self.class.name} must implement #generate_comment_summary"
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

  # Calculate maximum input size in characters based on context window
  # @return [Integer] maximum input size in characters
  def max_input_chars
    # Calculate how many tokens we can use for input
    input_tokens = self.class.max_token_limit - RESERVED_OUTPUT_TOKENS

    # Convert to characters using the fixed ratio
    (input_tokens / TOKEN_PER_CHAR_RATIO).floor
  end
end