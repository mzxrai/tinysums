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
class Ai::AdapterFactory
  # Mapping of provider symbols to their corresponding adapter class names
  # @return [Hash{Symbol => String}] Provider to class name mapping
  ADAPTER_TYPES = {
    # Anthropic's Claude model adapter
    anthropic: "Ai::Adapters::AnthropicAdapter",
    # OpenAI's GPT model adapter
    openai: "Ai::Adapters::OpenaiAdapter",
    # Google's Gemini model adapter
    google: "Ai::Adapters::GoogleAdapter"
  }.freeze

  # The default AI provider to use when none is specified
  # @return [Symbol] Default provider symbol
  DEFAULT_PROVIDER = :google

  # Environment variable names for each provider's API key
  # @return [Hash{Symbol => String}] Provider to environment variable mapping
  ENV_API_KEYS = {
    # Google Gemini API key environment variable
    google: "GOOG_GEM_API_KEY",
    # OpenAI API key environment variable
    openai: "OPEN_AI_API_KEY",
    # Anthropic API key environment variable
    anthropic: "ANTH_API_KEY"
  }.freeze

  class << self
    # Creates an AI adapter instance for the specified provider
    # @param provider [Symbol, String] The provider type (:anthropic, :openai, :google)
    # @param api_key [String] The API key for authenticating with the provider
    # @param options [Hash] Additional configuration options for the adapter
    # @option options [String] :model The specific model to use
    # @option options [Hash] :other_options Provider-specific configuration
    # @return [Ai::BaseAiAdapter] An instance of the appropriate adapter class
    # @raise [ArgumentError] If the provider type is invalid or API key is missing
    # @example
    #   adapter = Ai::AdapterFactory.create(:openai, "api-key-123")
    def create(provider, api_key, options = {})
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
      adapter_class.new(api_key, options)
    end

    # Retrieves the default adapter based on application configuration
    # The provider and API key are determined by:
    # 1. Rails configuration (config.x.ai.provider and config.x.ai.api_key)
    # 2. Environment variables (fallback)
    # @param options [Hash] Optional configuration to override defaults
    # @return [Ai::BaseAiAdapter] An instance of the default adapter
    # @raise [ArgumentError] If no API key is configured
    # @example
    #   adapter = Ai::AdapterFactory.default_adapter
    def default_adapter(options = {})
      # Get provider from Rails config, fallback to default if not set
      provider = Rails.configuration.x.ai&.provider || DEFAULT_PROVIDER
      # Convert to symbol for consistent comparison
      provider_sym = provider.to_sym

      # Get API key - try Rails config first, then environment variable
      api_key = Rails.configuration.x.ai&.api_key || fetch_api_key_from_env(provider_sym)

      # Create and return adapter instance
      create(provider_sym, api_key, options)
    end

    private

    # Retrieves the API key from the appropriate environment variable
    # @param provider [Symbol] The provider type
    # @return [String] The API key from environment
    # @raise [ArgumentError] If the API key is not configured
    # @example
    #   api_key = fetch_api_key_from_env(:openai)
    def fetch_api_key_from_env(provider)
      # Get the environment variable name for this provider
      env_var = ENV_API_KEYS[provider]
      # Fetch the API key from environment, raise error if not found
      api_key = ENV.fetch(env_var) do
        raise ArgumentError, "No API key found for #{provider}. Please set the #{env_var} environment variable."
      end

      # Return the found API key
      api_key
    end
  end
end