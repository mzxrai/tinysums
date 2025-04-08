# Module for centralizing URL configuration across different environments
# Provides consistent access to frontend and API URLs throughout the application
module AppUrls
  # Private module to encapsulate configuration logic
  # @api private
  module Config
    # Returns the configuration hash, initializing it on first access
    # @return [Hash] Frozen hash of URL configurations
    def self.urls
      @urls ||= {
        app: ENV.fetch("APP_URL") # Rails app server
      }.freeze
    end
  end

  # Returns the API URL
  # @return [String] The API URL (e.g., "http://localhost:3001" in development)
  def self.app_url
    Config.urls[:app]
  end
end