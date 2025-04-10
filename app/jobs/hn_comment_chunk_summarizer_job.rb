# frozen_string_literal: true

# Job to summarize a chunk of HN comments using AI
class HnCommentChunkSummarizerJob
  include Sidekiq::Worker

  # Set retry options for reliability - using more retries since AI APIs are flaky
  sidekiq_options retry: 5

  # Redis key prefixes
  SUMMARY_KEY_PREFIX = "hn:summary".freeze
  CHUNK_KEY_PREFIX = "hn:comment_chunks".freeze
  # Redis key for tracking attempts
  ATTEMPTS_KEY_PREFIX = "hn:chunk_attempts".freeze

  # Time to live for data
  DATA_TTL = 7.days.to_i
  # Max attempts before considering failed
  MAX_ATTEMPTS = 5

  # Process and summarize a chunk of comments
  # @param story_id [Integer] the HN story ID
  # @param chunk_index [Integer] the index of the chunk to process
  # @param adapter_provider [String, nil] optional adapter provider to use
  def perform(story_id, chunk_index, adapter_provider = nil)
    adapter_log = adapter_provider ? " using #{adapter_provider} adapter" : ""
    Rails.logger.info("HN_JOBS: Summarizing comment chunk ##{chunk_index} for story ##{story_id}#{adapter_log}")

    # Increment attempt counter atomically in Redis
    attempt_count = increment_attempt_counter(story_id, chunk_index)

    # Get the chunk content from Redis
    chunk_content = get_chunk_content(story_id, chunk_index)
    return if chunk_content.nil?

    # Use our AI adapter to summarize the chunk
    summary = generate_chunk_summary(story_id, chunk_content, chunk_index, adapter_provider)

    # Store the summary in Redis
    store_chunk_summary(story_id, chunk_index, summary)

    # Update chunk status and check if all chunks are complete
    check_if_all_chunks_complete(story_id, adapter_provider)

    Rails.logger.info("HN_JOBS: Completed comment chunk ##{chunk_index} for story ##{story_id}")
  rescue StandardError => e
    Rails.logger.error("HN_JOBS: Error summarizing comment chunk ##{chunk_index} for story ##{story_id}: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)

    # Get current attempt count
    attempt_count = get_attempt_count(story_id, chunk_index)

    # Handle the last retry attempt
    if attempt_count >= MAX_ATTEMPTS
      # Mark chunk as failed
      Fast.with do |redis|
        chunks_key = "#{CHUNK_KEY_PREFIX}:#{story_id}:info"
        redis.hincrby(chunks_key, "failed_chunks", 1)
        redis.hincrby(chunks_key, "pending_chunks", -1)

        # Store the error as the summary
        summary_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:comments:chunk:#{chunk_index}"
        redis.set(summary_key, "Error: Failed to summarize this comment chunk after multiple attempts.")
        redis.expire(summary_key, DATA_TTL)

        # Check if all chunks are now accounted for
        check_if_all_chunks_complete(story_id, adapter_provider)
      end
    end

    # Re-raise to let Sidekiq handle retries
    raise
  end

  private

  # Increment attempt counter in Redis
  # @param story_id [Integer] the story ID
  # @param chunk_index [Integer] the chunk index
  # @return [Integer] the new attempt count
  def increment_attempt_counter(story_id, chunk_index)
    attempts = 0

    Fast.with do |redis|
      attempts_key = "#{ATTEMPTS_KEY_PREFIX}:#{story_id}:#{chunk_index}"
      attempts = redis.incr(attempts_key)
      # Set expiration to ensure cleanup of attempt counters
      redis.expire(attempts_key, DATA_TTL)
    end

    attempts
  end

  # Get current attempt count from Redis
  # @param story_id [Integer] the story ID
  # @param chunk_index [Integer] the chunk index
  # @return [Integer] the current attempt count
  def get_attempt_count(story_id, chunk_index)
    attempts = 0

    Fast.with do |redis|
      attempts_key = "#{ATTEMPTS_KEY_PREFIX}:#{story_id}:#{chunk_index}"
      attempts_str = redis.get(attempts_key)
      attempts = attempts_str.to_i if attempts_str
    end

    attempts
  end

  # Get chunk content from Redis
  # @param story_id [Integer] the story ID
  # @param chunk_index [Integer] the chunk index
  # @return [String, nil] the chunk content or nil if not found
  def get_chunk_content(story_id, chunk_index)
    chunk_content = nil

    Fast.with do |redis|
      chunk_key = "#{CHUNK_KEY_PREFIX}:#{story_id}:#{chunk_index}"
      chunk_content = redis.get(chunk_key)

      if chunk_content.nil?
        Rails.logger.error("HN_JOBS: Comment chunk ##{chunk_index} for story ##{story_id} not found in Redis")
      end
    end

    chunk_content
  end

  # Generate a summary of the comment chunk using AI
  # @param story_id [Integer] the story ID
  # @param content [String] the formatted comment content
  # @param chunk_index [Integer] the chunk index
  # @param adapter_provider [String, nil] optional adapter provider to use
  # @return [String] the generated summary
  def generate_chunk_summary(story_id, content, chunk_index, adapter_provider = nil)
    # Get adapter - use specific provider if given, otherwise use default
    adapter = if adapter_provider
                Rails.logger.info("HN_JOBS: Using #{adapter_provider} adapter for chunk ##{chunk_index} of story ##{story_id}")
                Ai::AdapterFactory.create(adapter_provider, nil)
    else
                Ai::AdapterFactory.default_adapter
    end

    # Create HN Thread Summarizer
    thread_summarizer = Ai::HnThreadSummarizer.new(adapter)

    # Extract story title from chunk content
    title_match = content.match(/# Hacker News Discussion: (.+)$/)
    title = title_match ? title_match[1] : "Unknown Story"

    # Create a story-like hash for the summarizer
    story = { "id" => story_id, "title" => title }

    # Generate chunk summary using the existing chunk summarization logic
    prompt = thread_summarizer.send(:create_chunk_prompt, story, content, chunk_index + 1, -1) # -1 as total is unknown

    summary = adapter.generate_summary(prompt, {})

    # Add a header to identify this chunk summary
    "## Comment Chunk #{chunk_index + 1} Summary\n\n#{summary}"
  end

  # Store chunk summary in Redis
  # @param story_id [Integer] the story ID
  # @param chunk_index [Integer] the chunk index
  # @param summary [String] the generated summary
  def store_chunk_summary(story_id, chunk_index, summary)
    Fast.with do |redis|
      # Store the summary
      summary_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:comments:chunk:#{chunk_index}"
      redis.set(summary_key, summary)
      redis.expire(summary_key, DATA_TTL)

      # Update the chunk tracking information
      chunks_key = "#{CHUNK_KEY_PREFIX}:#{story_id}:info"
      redis.hincrby(chunks_key, "completed_chunks", 1)
      redis.hincrby(chunks_key, "pending_chunks", -1)
    end
  end

  # Check if all chunks are complete and trigger final summarization if so
  # @param story_id [Integer] the story ID
  # @param adapter_provider [String, nil] optional adapter provider to use
  def check_if_all_chunks_complete(story_id, adapter_provider = nil)
    complete = false

    Fast.with do |redis|
      chunks_key = "#{CHUNK_KEY_PREFIX}:#{story_id}:info"
      info = redis.hgetall(chunks_key)

      # Check if all chunks are accounted for (completed + failed = total)
      completed = info["completed_chunks"].to_i
      failed = info["failed_chunks"].to_i
      total = info["total_chunks"].to_i

      if completed + failed >= total
        complete = true
        # Update the info to show we're moving to meta-summarization
        redis.hset(chunks_key, "status", "all_chunks_processed")
      end
    end

    # Schedule the final summarization job if all chunks are complete
    if complete
      HnCommentsFinalSummarizerJob.perform_async(story_id, adapter_provider)
      adapter_log = adapter_provider ? " with #{adapter_provider} adapter" : ""
      Rails.logger.info("HN_JOBS: All comment chunks processed for story ##{story_id}, scheduled final summarization#{adapter_log}")
    end
  end
end