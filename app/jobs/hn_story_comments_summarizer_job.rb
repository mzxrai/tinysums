# frozen_string_literal: true

# Job to coordinate summarization of HN story comments
class HnStoryCommentsSummarizerJob
  include Sidekiq::Worker

  # Set retry options for reliability
  sidekiq_options retry: 3

  # Redis key prefixes
  STORY_KEY_PREFIX = "hn:story".freeze
  SUMMARY_KEY_PREFIX = "hn:summary".freeze
  CHUNK_KEY_PREFIX = "hn:comment_chunks".freeze

  # Time to live for data
  DATA_TTL = 7.days.to_i

  # Default chunk size (max number of comments per chunk)
  DEFAULT_CHUNK_SIZE = 100

  # Process and coordinate comment summarization
  # @param story_id [Integer] the HN story ID to summarize comments for
  # @param adapter_provider [String, nil] optional AI adapter to use
  # @param chunk_size [Integer] maximum number of comments per chunk
  def perform(story_id, adapter_provider = nil, chunk_size = DEFAULT_CHUNK_SIZE)
    adapter_log = adapter_provider ? " using #{adapter_provider} adapter" : ""
    Rails.logger.info("HN_JOBS: Starting comments coordination for story ##{story_id}#{adapter_log}")

    # Fetch story with comments
    client = HnApiClient.new
    story = client.get_story_with_comments(story_id)

    if story.nil? || story["comments"].blank?
      Rails.logger.info("HN_JOBS: No comments found for story ##{story_id}")
      update_story_status(story_id, "completed")
      return
    end

    # Add karma information to comments (for better scoring)
    thread_summarizer = Ai::HnThreadSummarizer.new(nil, client)
    thread_summarizer.send(:enrich_comments_with_karma, story)

    # Select which comments to summarize - make sure we pass options with default values
    begin
      selected_comments = thread_summarizer.send(:select_comments_for_summarization, story, thread_summarizer.instance_variable_get(:@options) || {})
    rescue StandardError => e
      Rails.logger.error("HN_JOBS: Error selecting comments: #{e.message}")
      # If there's an error, use all available comments
      selected_comments = story["comments"] || []
    end

    # Safety check - ensure we have valid comments to process
    selected_comments = selected_comments.compact

    # If the comments are empty, we can't process them, so we'll mark the story as completed
    # and return
    if selected_comments.empty?
      Rails.logger.info("HN_JOBS: No valid comments to process for story ##{story_id}")
      update_story_status(story_id, "completed")
      return
    end

    # Split comments into chunks
    chunks = create_comment_chunks(selected_comments, chunk_size)

    # Store chunk information in Redis
    store_chunk_info(story_id, chunks.size)

    # Enqueue a job for each chunk
    process_chunks(story_id, story, chunks, adapter_provider)

    Rails.logger.info("HN_JOBS: Scheduled #{chunks.size} comment chunks for story ##{story_id}#{adapter_log}")
  rescue StandardError => e
    Rails.logger.error("HN_JOBS: Error processing comments for story ##{story_id}: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
    update_story_status(story_id, "failed")
  end

  private

  # Create chunks of comments for processing
  # @param comments [Array<Hash>] comments to chunk
  # @param chunk_size [Integer] max comments per chunk
  # @return [Array<Array<Hash>>] array of comment chunks
  def create_comment_chunks(comments, chunk_size)
    comments.each_slice(chunk_size).to_a
  end

  # Store chunk information in Redis
  # @param story_id [Integer] the story ID
  # @param chunk_count [Integer] number of chunks
  def store_chunk_info(story_id, chunk_count)
    Fast.with do |redis|
      # Store the total number of chunks
      chunks_key = "#{CHUNK_KEY_PREFIX}:#{story_id}:info"

      # Set each field individually
      redis.hset(chunks_key, "total_chunks", chunk_count)
      redis.hset(chunks_key, "pending_chunks", chunk_count)
      redis.hset(chunks_key, "completed_chunks", 0)
      redis.hset(chunks_key, "created_at", Time.now.to_i)
      redis.expire(chunks_key, DATA_TTL)
    end
  end

  # Process each chunk by scheduling a summarization job
  # @param story_id [Integer] the story ID
  # @param story [Hash] the full story data
  # @param chunks [Array<Array<Hash>>] the comment chunks
  # @param adapter_provider [String, nil] optional AI adapter to use
  def process_chunks(story_id, story, chunks, adapter_provider = nil)
    adapter_log = adapter_provider ? " with #{adapter_provider} adapter" : ""

    chunks.each_with_index do |chunk, index|
      # Format the chunk for summarization
      formatted_chunk = format_chunk_for_summarization(story, chunk, index)

      # Store the chunk in Redis
      chunk_key = "#{CHUNK_KEY_PREFIX}:#{story_id}:#{index}"
      Fast.with do |redis|
        redis.set(chunk_key, formatted_chunk)
        redis.expire(chunk_key, DATA_TTL)
      end

      # Add jitter to prevent API bottlenecks
      jitter = rand(10)

      # Pass along the adapter_provider to each chunk job - ensure correct number of arguments
      HnCommentChunkSummarizerJob.perform_in(jitter.seconds, story_id, index, adapter_provider)

      Rails.logger.debug("HN_JOBS: Scheduled chunk ##{index} summarizer for story ##{story_id}#{adapter_log}")
    end
  end

  # Format a chunk of comments for summarization
  # @param story [Hash] the story data
  # @param chunk [Array<Hash>] comments in this chunk
  # @param chunk_index [Integer] index of this chunk
  # @return [String] formatted text for summarization
  def format_chunk_for_summarization(story, chunk, chunk_index)
    # Use the thread summarizer's format method to create the content
    formatter = Ai::HnThreadSummarizer.new(nil)

    # Add a header with story info
    header = "# Hacker News Discussion: #{story['title']}\n\n"
    header += "URL: #{story['url']}\n" if story["url"]
    header += "Posted by: #{story['by']}\n"
    header += "Total comments in story: #{story['descendants'] || 0}\n"
    header += "Comments in this chunk: #{chunk.size} (Chunk #{chunk_index + 1})\n\n"

    # Format each comment and its replies
    comments_text = chunk.map.with_index do |comment, index|
      formatter.send(:format_comment_with_replies, comment, "#{index + 1}", 0)
    end.join("\n")

    # Combine header and comments
    header + comments_text
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