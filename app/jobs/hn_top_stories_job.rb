# frozen_string_literal: true

# Job to fetch and process the top N HN stories
class HnTopStoriesJob
  include Sidekiq::Worker

  # Set retry options for reliability
  sidekiq_options retry: 3

  # The key prefix for storing top stories in Redis
  TOP_STORIES_KEY = "hn:top_stories".freeze

  # Time to live for the top stories list in Redis
  STORIES_TTL = 3600 # 1 hour

  # Fetch and process the top stories from HN
  # @param story_count [Integer] number of top stories to fetch (default: 30)
  # @param refresh [Boolean] whether to force refresh from HN API (default: false)
  # @param adapter_provider [String, nil] optional AI adapter to use for all summarization (default: nil)
  def perform(story_count = 30, refresh = false, adapter_provider = nil)
    adapter_log = adapter_provider ? " using #{adapter_provider} adapter" : ""
    Rails.logger.info("HN_JOBS: Fetching top #{story_count} HN stories#{adapter_log}")

    story_ids = fetch_top_stories(story_count, refresh)
    return if story_ids.blank?

    # Store story IDs in Redis
    store_story_ids(story_ids)

    # Enqueue individual story jobs with jitter to prevent API bottlenecks
    schedule_story_jobs(story_ids, adapter_provider)

    Rails.logger.info("HN_JOBS: Successfully scheduled #{story_ids.size} story summarizer jobs#{adapter_log}")
  end

  private

  # Fetch top stories, either from Redis (if recent) or from HN API
  # @param count [Integer] number of stories to fetch
  # @param refresh [Boolean] whether to bypass cache and fetch from API
  # @return [Array<Integer>] array of story IDs
  def fetch_top_stories(count, refresh)
    return fetch_stories_from_api(count) if refresh

    # Try to get from Redis first
    Fast.with do |redis|
      cached_stories = redis.get("#{TOP_STORIES_KEY}:list")
      if cached_stories.present?
        Rails.logger.info("HN_JOBS: Using cached top stories list")
        return JSON.parse(cached_stories).first(count)
      end
    end

    # Not in Redis, fetch from API
    fetch_stories_from_api(count)
  end

  # Fetch top stories directly from HN API
  # @param count [Integer] number of stories to fetch
  # @return [Array<Integer>] array of story IDs
  def fetch_stories_from_api(count)
    Rails.logger.info("HN_JOBS: Fetching top stories from HN API")
    client = HnApiClient.new

    begin
      # The API actually returns full story objects, not just IDs
      stories = client.top_stories(count)
      Rails.logger.info("HN_JOBS: Successfully fetched #{stories.size} top stories from HN API")

      # Extract just the IDs from the story objects
      story_ids = stories.map { |story| story.is_a?(Hash) ? story["id"] : story }

      story_ids
    rescue StandardError => e
      Rails.logger.error("HN_JOBS: Failed to fetch top stories: #{e.message}")
      Sentry.capture_exception(e) if defined?(Sentry)
      []
    end
  end

  # Store story IDs in Redis for later retrieval
  # @param story_ids [Array<Integer>] array of story IDs to store
  def store_story_ids(story_ids)
    Fast.with do |redis|
      # Convert all IDs to integers, handling both Hash and scalar values
      ids_to_store = story_ids.map do |id|
        # If it's a Hash, extract the ID, otherwise use the value directly
        id_value = id.is_a?(Hash) ? id["id"] : id
        id_value.to_i
      end

      # Store as JSON
      redis.set("#{TOP_STORIES_KEY}:list", ids_to_store.to_json, ex: STORIES_TTL)

      # Also store timestamp of when we fetched these stories
      redis.set("#{TOP_STORIES_KEY}:last_updated", Time.now.to_i, ex: STORIES_TTL)

      # Store each story in the sorted set by its position
      ids_to_store.each_with_index do |id, index|
        # Ensure both score and member are scalar values
        redis.zadd("#{TOP_STORIES_KEY}:sorted", index.to_i, id.to_s)
      end
      redis.expire("#{TOP_STORIES_KEY}:sorted", STORIES_TTL)
    end
  end

  # Schedule individual story summarizer jobs with jitter
  # @param story_ids [Array<Integer>] array of story IDs to process
  # @param adapter_provider [String, nil] optional AI adapter to use
  def schedule_story_jobs(story_ids, adapter_provider = nil)
    adapter_log = adapter_provider ? " with #{adapter_provider} adapter" : ""

    story_ids.each_with_index do |id, index|
      # Add jitter (0-30 seconds) to prevent all jobs starting simultaneously
      jitter = rand(30)

      # Enqueue the job with the delay, passing along the adapter_provider
      HnStorySummarizerJob.perform_in(jitter.seconds, id, index, adapter_provider)

      Rails.logger.debug("HN_JOBS: Scheduled summarizer for story ##{id}#{adapter_log} with #{jitter}s jitter")
    end
  end
end