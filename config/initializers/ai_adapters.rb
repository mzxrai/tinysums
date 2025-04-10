# frozen_string_literal: true

# AI Adapter Configuration
#
# This initializer configures the AI adapters used for summarization.
# The configuration is environment-specific.

# Default to OpenAI adapter in all environments
Rails.application.config.ai_adapter_class = "Ai::OpenAiAdapter"

# AI adapter options
Rails.application.config.ai_adapter_options = {
  # API key will be loaded from environment variables by the adapter
  model: ENV.fetch("OPENAI_MODEL", "gpt-4o"),
  temperature: 0.2,
  max_tokens: 2000
}

# For development/test, we can use a mock adapter if needed
if Rails.env.development? || Rails.env.test?
  # Use mock adapter if MOCK_AI=true is set
  if ENV["MOCK_AI"] == "true"
    Rails.application.config.ai_adapter_class = "Ai::MockAiAdapter"
    Rails.application.config.ai_adapter_options = {
      response_template: "This is a mock AI summary generated for testing purposes."
    }

    Rails.logger.info("Using MockAiAdapter for AI summarization")
  else
    Rails.logger.info("Using #{Rails.application.config.ai_adapter_class} for AI summarization")
  end
end