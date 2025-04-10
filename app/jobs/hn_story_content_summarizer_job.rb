# frozen_string_literal: true

# Job to summarize the content of a HN story (article)
class HnStoryContentSummarizerJob
  include Sidekiq::Worker

  # Set retry options for reliability
  sidekiq_options retry: 3

  # Redis key prefixes
  STORY_KEY_PREFIX = "hn:story".freeze
  SUMMARY_KEY_PREFIX = "hn:summary".freeze

  # Time to live for summaries
  SUMMARY_TTL = 7.days.to_i

  # Process and summarize story content
  # @param story_id [Integer] the HN story ID to summarize
  # @param adapter_provider [String, nil] optional AI adapter to use
  def perform(story_id, adapter_provider = nil)
    adapter_log = adapter_provider ? " using #{adapter_provider} adapter" : ""
    Rails.logger.info("HN_JOBS: Starting content summarization for story ##{story_id}#{adapter_log}")

    # Get story data from Redis
    story = get_story_data(story_id)
    return if story.nil?

    # For now, generate a stub summary (placeholder)
    # In the future, this would fetch the actual content and summarize it
    summary = generate_content_summary(story, adapter_provider)

    # Store the summary in Redis
    store_content_summary(story_id, summary)

    # Update the story status
    update_story_status(story_id, "completed")

    Rails.logger.info("HN_JOBS: Completed content summarization for story ##{story_id}")
  rescue StandardError => e
    Rails.logger.error("HN_JOBS: Error summarizing content for story ##{story_id}: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)

    # Handle retries exhausted case
    if Sidekiq.retries_exhausted?(self.jid)
      update_story_status(story_id, "failed")
    else
      update_story_status(story_id, "retrying")
    end

    # Re-raise to let Sidekiq handle retries
    raise
  end

  private

  # Get story data from Redis
  # @param story_id [Integer] the story ID
  # @return [Hash, nil] the story data or nil if not found
  def get_story_data(story_id)
    story_data = nil

    Fast.with do |redis|
      story_key = "#{STORY_KEY_PREFIX}:#{story_id}"
      story_hash = redis.hgetall(story_key)

      if story_hash.present?
        story_data = story_hash.symbolize_keys
      else
        Rails.logger.error("HN_JOBS: Story ##{story_id} not found in Redis")
      end
    end

    story_data
  end

  # Generate a summary of the story content
  # @param story [Hash] the story data
  # @param adapter_provider [String, nil] optional AI adapter to use
  # @return [String] the generated summary
  def generate_content_summary(story, adapter_provider = nil)
    # TODO: In the future, this would:
    # 1. Fetch the article content using a headless browser
    # 2. Clean and extract the main text
    # 3. Send to AI API for summarization

    # For now, generate a stub summary
    title = story[:title] || "Unknown Title"
    url = story[:url] || "No URL"
    by = story[:by] || "Unknown Author"

    # In a real implementation, this would use the AI adapter
    if adapter_provider
      adapter = Ai::AdapterFactory.create(adapter_provider, nil)
      Rails.logger.info("HN_JOBS: Using #{adapter_provider} adapter for content summarization")

      # Use a simple prompt for now - would be replaced with actual content
      prompt = "Create a placeholder summary for an article titled '#{title}' by #{by}, URL: #{url}"
      begin
        return adapter.generate_summary(prompt, {})
      rescue StandardError => e
        Rails.logger.error("HN_JOBS: AI adapter error: #{e.message}")
      end
    end

    # Fallback placeholder summary
    <<~SUMMARY
      This is a placeholder summary for "#{title}" posted by #{by}.

      The full article is available at: #{url}

      In the future, this will be replaced with an AI-generated summary of the article content.
    SUMMARY
  end

  # Store content summary in Redis
  # @param story_id [Integer] the story ID
  # @param summary [String] the generated summary
  def store_content_summary(story_id, summary)
    Fast.with do |redis|
      summary_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:content"

      # Store the summary content
      redis.set(summary_key, summary)
      redis.expire(summary_key, SUMMARY_TTL)

      # Also store metadata about the summary
      meta_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:content:meta"

      # Set each field individually
      redis.hset(meta_key, "generated_at", Time.now.to_i)
      redis.hset(meta_key, "word_count", summary.split.size)
      redis.hset(meta_key, "character_count", summary.length)
      redis.expire(meta_key, SUMMARY_TTL)
    end
  end

  # Update story summarization status
  # @param story_id [Integer] the story ID
  # @param status [String] the new status
  def update_story_status(story_id, status)
    Fast.with do |redis|
      status_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:status"

      # Update fields individually
      redis.hset(status_key, "content_summary", status)
      redis.hset(status_key, "updated_at", Time.now.to_i)
    end
  end
end