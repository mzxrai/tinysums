# Example usage of the HN Thread Summarizer
# Run this code in Rails console to generate summaries
#
# Example:
#   load 'app/lib/ai/examples/hn_summarizer_example.rb'
#   HnSummarizerExample.summarize_thread(story_id: 37782393)
#
class HnSummarizerExample
  class << self
    # Generate a summary for a HN thread
    # @param story_id [Integer] the HN story ID to summarize
    # @param adapter_type [Symbol] the AI provider to use (:anthropic, :openai, :google)
    # @param api_key [String, nil] optional API key (uses app config if nil)
    # @param options [Hash] additional options for summarization
    # @return [String] the generated summary
    def summarize_thread(story_id:, adapter_type: nil, api_key: nil, options: {})
      # Log the start of summarization
      Rails.logger.info("Starting summary generation for HN story ##{story_id}")

      # Get the adapter (use default or specified)
      adapter = get_adapter(adapter_type, api_key)

      # Create a summary generator with our adapter
      summary_generator = Ai::SummaryGenerator.new(adapter, options)

      # Generate comment summary
      comment_summary = summary_generator.generate_comment_summary(story_id, options)

      # Log completion
      Rails.logger.info("Summary generation completed for HN story ##{story_id}")

      # Return the summary
      comment_summary
    end

    private

    # Get the appropriate AI adapter
    # @param adapter_type [Symbol, nil] the adapter type to use
    # @param api_key [String, nil] optional API key
    # @return [Ai::BaseAiAdapter] the configured adapter
    def get_adapter(adapter_type, api_key)
      if adapter_type.nil?
        # Use the default adapter from config
        Ai::AdapterFactory.default_adapter
      else
        # Use the specified adapter type with given or default API key
        api_key ||= Rails.configuration.x.ai.api_key
        Ai::AdapterFactory.create(adapter_type, api_key)
      end
    end
  end
end

# Usage examples:
#
# 1. Using default adapter (from Rails config):
#    summary = HnSummarizerExample.summarize_thread(story_id: 37782393)
#
# 2. Using a specific adapter:
#    summary = HnSummarizerExample.summarize_thread(
#      story_id: 37782393,
#      adapter_type: :anthropic
#    )
#
# 3. With custom options:
#    summary = HnSummarizerExample.summarize_thread(
#      story_id: 37782393,
#      options: {
#        small_thread_percentage: 80,
#        large_thread_percentage: 25
#      }
#    )
#
# 4. With your own API key:
#    summary = HnSummarizerExample.summarize_thread(
#      story_id: 37782393,
#      adapter_type: :openai,
#      api_key: "your-api-key-here"
#    )