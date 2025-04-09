# Factory for creating AI adapters based on configuration
class Ai::AdapterFactory
  # Known adapter types and their corresponding classes
  ADAPTER_TYPES = {
    anthropic: "Ai::Adapters::AnthropicAdapter",
    openai: "Ai::Adapters::OpenaiAdapter",
    google: "Ai::Adapters::GoogleAdapter"
  }.freeze

  # Default provider to use if none configured
  DEFAULT_PROVIDER = :google

  # Environment variable names for API keys
  ENV_API_KEYS = {
    google: "GOOG_GEM_API_KEY",
    openai: "OPEN_AI_API_KEY",
    anthropic: "ANTH_API_KEY"
  }.freeze

  class << self
    # Create an AI adapter instance based on provider type
    # @param provider [Symbol, String] The provider type (:anthropic, :openai, etc.)
    # @param api_key [String] The API key for the provider
    # @param options [Hash] Configuration options for the adapter
    # @return [Ai::BaseAiAdapter] An instance of the appropriate adapter
    # @raise [ArgumentError] If the provider type is invalid
    def create(provider, api_key, options = {})
      # Handle nil provider by using default
      provider ||= DEFAULT_PROVIDER
      provider_sym = provider.to_sym

      unless ADAPTER_TYPES.key?(provider_sym)
        available = ADAPTER_TYPES.keys.join(", ")
        raise ArgumentError, "Unknown AI provider: #{provider}. Available providers: #{available}"
      end

      adapter_class = ADAPTER_TYPES[provider_sym].constantize
      adapter_class.new(api_key, options)
    end

    # Get the default adapter based on application configuration
    # @param options [Hash] Optional configuration to override defaults
    # @return [Ai::BaseAiAdapter] An instance of the default adapter
    def default_adapter(options = {})
      # Get provider from Rails config, fallback to default if not set
      provider = Rails.configuration.x.ai&.provider || DEFAULT_PROVIDER
      provider_sym = provider.to_sym

      # Get API key - try Rails config first, then environment variable
      api_key = Rails.configuration.x.ai&.api_key || fetch_api_key_from_env(provider_sym)

      create(provider_sym, api_key, options)
    end

    private

    # Fetch the API key from the appropriate environment variable based on provider
    # @param provider [Symbol] The provider type
    # @return [String] The API key from environment
    # @raise [ArgumentError] If the API key is not configured
    def fetch_api_key_from_env(provider)
      env_var = ENV_API_KEYS[provider]
      api_key = ENV.fetch(env_var) do
        raise ArgumentError, "No API key found for #{provider}. Please set the #{env_var} environment variable."
      end

      api_key
    end
  end
end