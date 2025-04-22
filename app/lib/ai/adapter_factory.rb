# Factory for creating AI adapters based on configuration
# This factory class handles the creation and configuration of AI adapters for different providers
# (Anthropic, OpenAI, Google). It manages API key retrieval and adapter instantiation.
#
# @example Creating a specific adapter
#   adapter = Ai::AdapterFactory.create(:openai, "api-key-123", { model: "gpt-4" })
#
# @example Getting the default adapter
#   adapter = Ai::AdapterFactory.default_adapter
#
# @see Ai::BaseAiAdapter
# @see Ai::Adapters::AnthropicAdapter
# @see Ai::Adapters::OpenaiAdapter
# @see Ai::Adapters::GoogleAdapter
# @see Ai::Adapters::PerplexityAdapter
class Ai::AdapterFactory
  # Mapping of provider symbols to their corresponding adapter class names
  # @return [Hash{Symbol => String}] Provider to class name mapping
  ADAPTER_TYPES = {
    # Anthropic's Claude model adapter
    anthropic: "Ai::Adapters::AnthropicAdapter",
    # OpenAI's GPT model adapter
    openai: "Ai::Adapters::OpenaiAdapter",
    # Google's Gemini model adapter
    google: "Ai::Adapters::GoogleAdapter",
    # Perplexity's Sonar model adapter
    perplexity: "Ai::Adapters::PerplexityAdapter"
  }.freeze

  # The default AI provider to use for summary generation when none is specified
  # @return [Symbol] Default provider symbol
  DEFAULT_SUMMARY_PROVIDER = :google

  # The default AI provider to use for extraction when none is specified
  # @return [Symbol] Default provider symbol
  DEFAULT_EXTRACTION_PROVIDER = :perplexity

  class << self
    # Creates an AI adapter instance for the specified provider
    # @param provider [Symbol, String] The provider type (:anthropic, :openai, :google, :perplexity)
    # @param options [Hash] Additional configuration options for the adapter
    # @option options [String] :model The specific model to use
    # @option options [Hash] :other_options Provider-specific configuration
    # @return [Ai::BaseAiAdapter] An instance of the appropriate adapter class
    # @raise [ArgumentError] If the provider type is invalid or API key is missing
    # @example
    #   adapter = Ai::AdapterFactory.create(:openai, "api-key-123")
    def create(provider, options = {})
      # Use default provider if none specified
      provider ||= DEFAULT_PROVIDER

      # Convert to symbol for consistent comparison
      provider_sym = provider.to_sym

      # Validate provider type exists in our known providers
      unless ADAPTER_TYPES.key?(provider_sym)
        # Create error message with available providers
        available = ADAPTER_TYPES.keys.join(", ")
        raise ArgumentError, "Unknown AI provider: #{provider}. Available providers: #{available}"
      end

      # Get the adapter class name and convert to actual class
      adapter_class = ADAPTER_TYPES[provider_sym].constantize

      # Create and return new adapter instance
      adapter_class.new(options)
    end

    # Creates an instance of the default summary adapter and returns it
    # @return [Ai::BaseAiAdapter] An instance of the default summary adapter
    def default_summary_adapter
      create(DEFAULT_SUMMARY_PROVIDER)
    end

    # Creates an instance of the default extraction adapter and returns it
    # @return [Ai::BaseAiAdapter] An instance of the default extraction adapter
    def default_extraction_adapter
      create(DEFAULT_EXTRACTION_PROVIDER)
    end
  end
end