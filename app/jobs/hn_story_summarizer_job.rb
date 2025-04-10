# frozen_string_literal: true

# Job to handle summarization of a single HN story
class HnStorySummarizerJob
  include Sidekiq::Worker

  # Set retry options for reliability
  sidekiq_options retry: 5

  # Redis key prefixes
  STORY_KEY_PREFIX = "hn:story".freeze
  SUMMARY_KEY_PREFIX = "hn:summary".freeze

  # Time to live for story data
  STORY_TTL = 7.days.to_i

  # Process a single HN story
  # @param story_id [Integer] the HN story ID to process
  # @param position [Integer] the story's position in the top stories list
  # @param adapter_provider [String, nil] optional AI adapter to use for summarization
  def perform(story_id, position = nil, adapter_provider = nil)
    adapter_log = adapter_provider ? " using #{adapter_provider} adapter" : ""
    Rails.logger.info("HN_JOBS: Processing story ##{story_id}#{adapter_log}")

    # Fetch the story metadata (without comments)
    story = fetch_story(story_id)
    return if story.nil?

    # Store the story data in Redis
    store_story_data(story, position)

    # Enqueue content summarization job
    enqueue_content_summarizer(story_id, adapter_provider)

    # Enqueue comments summarization job
    enqueue_comments_summarizer(story_id, adapter_provider)

    Rails.logger.info("HN_JOBS: Successfully scheduled summarization jobs for story ##{story_id}#{adapter_log}")
  end

  private

  # Fetch story metadata from HN API
  # @param story_id [Integer] the HN story ID to fetch
  # @return [Hash, nil] the story data or nil if not found/error
  def fetch_story(story_id)
    Rails.logger.info("HN_JOBS: Fetching story ##{story_id}")
    client = HnApiClient.new

    begin
      story = client.get_item(story_id)
      Rails.logger.info("HN_JOBS: Successfully fetched story ##{story_id}: #{story['title']}")
      story
    rescue StandardError => e
      Rails.logger.error("HN_JOBS: Failed to fetch story ##{story_id}: #{e.message}")
      Sentry.capture_exception(e) if defined?(Sentry)
      nil
    end
  end

  # Store story data in Redis
  # @param story [Hash] the story data to store
  # @param position [Integer, nil] the story's position in the top stories list
  def store_story_data(story, position)
    story_id = story["id"]

    Fast.with do |redis|
      # Store story data - convert hash to key-value pairs for hset
      story_key = "#{STORY_KEY_PREFIX}:#{story_id}"
      story_data = story.transform_keys(&:to_s)

      # Use individual hset calls for each field
      story_data.each do |field, value|
        redis.hset(story_key, field, value.to_s)
      end
      redis.expire(story_key, STORY_TTL)

      # Store story processing status
      status_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:status"

      # Set each field individually
      redis.hset(status_key, "content_summary", "pending")
      redis.hset(status_key, "comments_summary", "pending")
      redis.hset(status_key, "updated_at", Time.now.to_i)
      redis.expire(status_key, STORY_TTL)

      # If position is provided, add to the top stories sorted set
      if position.present?
        redis.zadd("hn:top_stories:sorted", position, story_id)
      end
    end
  end

  # Enqueue job to summarize the content of the story
  # @param story_id [Integer] the story ID to summarize content for
  # @param adapter_provider [String, nil] optional AI adapter to use
  def enqueue_content_summarizer(story_id, adapter_provider = nil)
    # Add a small jitter (0-5 seconds)
    jitter = rand(5)
    HnStoryContentSummarizerJob.perform_in(jitter.seconds, story_id, adapter_provider)

    adapter_log = adapter_provider ? " with #{adapter_provider} adapter" : ""
    Rails.logger.debug("HN_JOBS: Scheduled content summarizer for story ##{story_id}#{adapter_log}")
  end

  # Enqueue job to summarize the comments of the story
  # @param story_id [Integer] the story ID to summarize comments for
  # @param adapter_provider [String, nil] optional AI adapter to use
  def enqueue_comments_summarizer(story_id, adapter_provider = nil)
    # Add a small jitter (0-5 seconds)
    jitter = rand(5)
    HnStoryCommentsSummarizerJob.perform_in(jitter.seconds, story_id, adapter_provider)

    adapter_log = adapter_provider ? " with #{adapter_provider} adapter" : ""
    Rails.logger.debug("HN_JOBS: Scheduled comments summarizer for story ##{story_id}#{adapter_log}")
  end
end