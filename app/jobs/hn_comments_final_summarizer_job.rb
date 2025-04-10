# frozen_string_literal: true

# Job to create a final meta-summary from all comment chunk summaries
class HnCommentsFinalSummarizerJob
  include Sidekiq::Worker

  # Set retry options for reliability
  sidekiq_options retry: 3

  # Redis key prefixes
  STORY_KEY_PREFIX = "hn:story".freeze
  SUMMARY_KEY_PREFIX = "hn:summary".freeze
  CHUNK_KEY_PREFIX = "hn:comment_chunks".freeze

  # Time to live for data
  DATA_TTL = 7.days.to_i

  # Process all chunk summaries and create a final meta-summary
  # @param story_id [Integer] the HN story ID
  # @param adapter_provider [String, nil] optional adapter provider to use
  def perform(story_id, adapter_provider = nil)
    adapter_log = adapter_provider ? " using #{adapter_provider} adapter" : ""
    Rails.logger.info("HN_JOBS: Starting final comment summarization for story ##{story_id}#{adapter_log}")

    # Get story metadata
    story = get_story(story_id)
    return if story.nil?

    # Get all chunk summaries
    chunk_summaries = get_chunk_summaries(story_id)

    if chunk_summaries.empty?
      handle_empty_summaries(story_id)
      return
    end

    # Generate meta-summary using AI
    meta_summary = generate_meta_summary(story, chunk_summaries, adapter_provider)

    # Store the final summary
    store_final_summary(story_id, meta_summary)

    # Update story status
    update_story_status(story_id, "completed")

    Rails.logger.info("HN_JOBS: Completed final comment summarization for story ##{story_id}")
  rescue StandardError => e
    Rails.logger.error("HN_JOBS: Error generating final comment summary for story ##{story_id}: #{e.message}")
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

  # Get story metadata from Redis
  # @param story_id [Integer] the story ID
  # @return [Hash, nil] the story data or nil if not found
  def get_story(story_id)
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

  # Get all chunk summaries from Redis
  # @param story_id [Integer] the story ID
  # @return [Array<String>] array of chunk summaries
  def get_chunk_summaries(story_id)
    chunk_summaries = []
    chunk_count = 0

    # First, get the total number of chunks
    Fast.with do |redis|
      chunks_key = "#{CHUNK_KEY_PREFIX}:#{story_id}:info"
      info = redis.hgetall(chunks_key)
      chunk_count = info["total_chunks"].to_i
    end

    # Fetch each chunk summary
    Fast.with do |redis|
      chunk_count.times do |i|
        summary_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:comments:chunk:#{i}"
        summary = redis.get(summary_key)

        if summary.present?
          # Skip any summaries that look like error messages
          unless summary.include?("Error:") || summary.include?("Error connecting to")
            chunk_summaries << summary
          else
            Rails.logger.warn("HN_JOBS: Skipping error summary for chunk ##{i} of story ##{story_id}")
          end
        else
          Rails.logger.warn("HN_JOBS: Missing summary for chunk ##{i} of story ##{story_id}")
        end
      end
    end

    chunk_summaries
  end

  # Handle case where no summaries were found
  # @param story_id [Integer] the story ID
  def handle_empty_summaries(story_id)
    Rails.logger.warn("HN_JOBS: No chunk summaries found for story ##{story_id}")

    # Store a placeholder summary
    placeholder = "No comment summaries could be generated for this story."
    store_final_summary(story_id, placeholder)

    # Update story status
    update_story_status(story_id, "completed_with_errors")
  end

  # Generate a meta-summary from all chunk summaries
  # @param story [Hash] the story data
  # @param chunk_summaries [Array<String>] array of chunk summaries
  # @param adapter_provider [String, nil] optional adapter provider to use
  # @return [String] the generated meta-summary
  def generate_meta_summary(story, chunk_summaries, adapter_provider = nil)
    # Get adapter - use specific provider if given, otherwise use default
    adapter = if adapter_provider
      Rails.logger.info("HN_JOBS: Using #{adapter_provider} adapter for final summary of story ##{story[:id]}")
      Ai::AdapterFactory.create(adapter_provider, nil)
    else
      Ai::AdapterFactory.default_adapter
    end

    # Create HN Thread Summarizer
    thread_summarizer = Ai::HnThreadSummarizer.new(adapter)

    # Generate meta-summary using the existing meta-summary logic
    prompt = thread_summarizer.send(:create_meta_summary_prompt, story, chunk_summaries)

    # Summarize with the AI
    meta_summary = adapter.generate_summary(prompt, {})

    # Add a header for the meta-summary
    "# Hacker News Discussion Summary: #{story[:title]}\n\n#{meta_summary}"
  end

  # Store the final summary in Redis
  # @param story_id [Integer] the story ID
  # @param summary [String] the final summary
  def store_final_summary(story_id, summary)
    Fast.with do |redis|
      # Store the summary
      summary_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:comments"
      redis.set(summary_key, summary)
      redis.expire(summary_key, DATA_TTL)

      # Also store metadata about the summary
      meta_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:comments:meta"

      # Set each field individually
      redis.hset(meta_key, "generated_at", Time.now.to_i)
      redis.hset(meta_key, "word_count", summary.split.size)
      redis.hset(meta_key, "character_count", summary.length)
      redis.expire(meta_key, DATA_TTL)
    end
  end

  # Update story summarization status
  # @param story_id [Integer] the story ID
  # @param status [String] the new status
  def update_story_status(story_id, status)
    Fast.with do |redis|
      status_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:status"

      # Update fields individually
      redis.hset(status_key, "comments_summary", status)
      redis.hset(status_key, "updated_at", Time.now.to_i)
    end
  end
end