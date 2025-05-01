# Job to fetch top HN stories and generate AI summaries for them
# This database-backed job creates and updates Story records and generates summaries
# The job runs in three main steps:
# 1. Fetch and update stories from the HN API
# 2. Generate missing summaries for active stories
# 3. Log completion statistics
class TopStoriesSummaryJob
  # Include Sidekiq functionality for background job processing
  include Sidekiq::Job

  # Batch size for summary generation to avoid overloading systems
  # Processing summaries in small batches helps prevent API rate limits
  # and reduces memory usage
  BATCH_SIZE = 5

  # Jitter range in seconds between processing items
  # Adding random delay between requests helps prevent API throttling
  # and distributes load more evenly
  JITTER_RANGE = 1..3

  # Set Sidekiq job options for better reliability
  sidekiq_options queue: :default, retry: 3

  # Main job processing method
  # Entry point that orchestrates the entire process
  # @return [void]
  def perform
    logger.info("Starting job execution")

    # Step 1: Fetch and update stories from the HN API
    # This ensures we have the latest stories and rankings
    update_stories_database

    # Step 2: Generate any missing summaries using AI
    # This only processes stories that don't already have summaries
    generate_missing_summaries

    # Step 3: Log completion statistics for monitoring
    log_job_completion
  end

  private

  # Get a logger tagged with the job name
  # @return [Logger] A logger instance tagged with the job name
  def logger
    @logger ||= Rails.logger.tagged("TopStoriesSummaryJob")
  end

  # Fetch top stories from HN API and update the database
  # This master method coordinates the entire story update process
  # @return [void]
  def update_stories_database
    # Log that we're starting to fetch stories
    logger.info("Fetching top stories from HN API")

    # Fetch top stories from the HN API
    top_stories = fetch_top_stories

    # Process each story and get list of current top IDs
    current_top_ids = process_top_stories(top_stories)

    # Handle stories that are no longer in the top list
    mark_inactive_stories(current_top_ids)

    # Log the count of active stories for monitoring
    logger.info("Updated #{Story.active.count} active stories in the database")
  end

  # Fetch the top stories from the HN API
  # Uses our client that handles caching and API interaction
  # @return [Array<Hash>] Array of story data hashes
  def fetch_top_stories
    # Create a new API client for fetching data
    client = HnApiClient.new

    # Get the top 30 stories from the API and return the array
    client.top_stories(30)
  end

  # Process each story from the top stories list
  # Updates each story in the database and returns list of their IDs
  # @param top_stories [Array<Hash>] The array of story data from the API
  # @return [Array<Integer>] IDs of current top stories
  def process_top_stories(top_stories)
    # Initialize array to collect IDs of current top stories
    current_top_ids = []

    # Process each story with its position in the array (for ranking)
    top_stories.each_with_index do |hn_story, index|
      # Skip stories without an ID (shouldn't happen, but just in case)
      next unless hn_story["id"].present?

      # Track this ID as being in the current top list
      current_top_ids << hn_story["id"]

      # Update the story with the rank set to its position (index + 1)
      update_story_data(hn_story, index + 1)
    end

    # Return the collected list of top story IDs
    current_top_ids
  end

  # Update a single story in the database with the latest data
  # Uses a consistent approach for both new and existing records
  # @param hn_story [Hash] Story data from the HN API
  # @param rank [Integer] The story's position in the HN ranking
  # @return [void]
  def update_story_data(hn_story, rank)
    # Find or initialize the story record (creates a new one if needed)
    story = Story.find_or_initialize_by(hn_id: hn_story["id"])

    # Always update all attributes from the API data
    # Including rank and marking as active
    story.update(
      title: hn_story["title"],
      url: hn_story["url"],
      by: hn_story["by"],
      score: hn_story["score"],
      time: hn_story["time"],
      descendants: hn_story["descendants"] || 0,
      rank: rank,
      active: true
    )
  end

  # Mark stories as inactive if they're no longer in the top list
  # Improves efficiency by using a single database query
  # @param current_top_ids [Array<Integer>] IDs of stories currently in the top list
  # @return [void]
  def mark_inactive_stories(current_top_ids)
    # Only run the update if we have some current top IDs
    # Otherwise, we might accidentally mark all stories as inactive
    if current_top_ids.present?
      # Use a single efficient query to mark all non-top stories as inactive
      Story.where.not(hn_id: current_top_ids).update_all(active: false)
    end
  end

  # Generate summaries for stories that need them
  # For story content: Only generates for stories missing summaries
  # For comments: Regenerates for ALL active stories since comments change over time
  # @return [void]
  def generate_missing_summaries
    # For story content summaries, only process stories that don't have them yet
    # This is because article content rarely changes after publication
    content_summaries_needed = Story.active.needs_story_summary.to_a

    # For comment summaries, process ALL active stories each time the job runs
    # This is because discussions evolve and change over time
    comments_summaries_needed = Story.active.to_a

    # Log counts for monitoring and debugging
    log_summary_counts(content_summaries_needed, comments_summaries_needed)

    # Process story content summaries in batches
    # Batching with jitter prevents overwhelming the AI service
    process_in_batches(content_summaries_needed) do |story|
      generate_story_summary(story)
    end

    # Process comments summaries in batches
    # Comments often require more processing power from the AI
    process_in_batches(comments_summaries_needed) do |story|
      generate_comments_summary(story)
    end
  end

  # Process items in batches with parallel execution
  # This method implements a simple thread pool pattern for concurrent processing:
  # 1. Divides items into small batches of BATCH_SIZE
  # 2. Processes each batch using a thread pool for concurrent API calls
  # 3. Limits the maximum number of concurrent threads to prevent overloading
  # 4. Adds random delay between batches to prevent API rate limiting
  # @param items [Array] the items to process
  # @yield [item] Block to execute for each item in its own thread
  # @return [void]
  def process_in_batches(items)
    # Maximum number of concurrent threads to use
    # This controls how many API calls we make in parallel
    # Adjust based on API rate limits and server capacity
    max_threads = 5

    # Divide the items into smaller batches of BATCH_SIZE
    # Each batch will be processed with concurrent threads
    items.each_slice(BATCH_SIZE).each do |batch|
      # Create an array to track threads for this batch
      # This forms our thread pool for the current batch
      threads = []

      # Process each item in the current batch concurrently
      batch.each do |item|
        # Thread pool management: limit the number of concurrent threads
        # If we reach max_threads, wait for the oldest thread to complete
        # before starting a new one (FIFO processing)
        if threads.size >= max_threads
          # Wait for the oldest thread to finish
          threads.first.join
          # Remove the completed thread from our tracking array
          threads.shift
        end

        # Create a new thread for this item and add it to our pool
        # Each thread makes its own API call independently
        threads << Thread.new do
          # Process the item by yielding to the provided block
          # The block contains the actual summary generation logic
          yield(item)
        end
      end

      # Wait for all remaining threads in this batch to complete
      # This ensures the entire batch is processed before moving to the next
      threads.each(&:join)

      # Add jitter delay between batches to prevent overwhelming APIs
      # This spaces out "waves" of concurrent requests
      # Skip the delay after the final batch to avoid unnecessary waiting
      unless batch == items.each_slice(BATCH_SIZE).to_a.last
        # Random delay within JITTER_RANGE to prevent predictable patterns
        sleep(rand(JITTER_RANGE))
      end
    end
  end

  # Log the counts of stories needing summaries
  # Centralizes logging to make format changes easier
  # @param content_stories [Array] stories needing content summaries
  # @param comment_stories [Array] stories needing comment summaries
  # @return [void]
  def log_summary_counts(content_stories, comment_stories)
    # Log count of stories needing content summaries
    logger.info(
      "Found #{content_stories.size} stories needing content summaries"
    )
    # Log count of stories needing comment summaries
    logger.info(
      "Found #{comment_stories.size} stories for comment summary regeneration"
    )
  end

  # Generate a summary for a story's content
  # This method:
  # 1. Creates or finds the summary record
  # 2. Generates the summary content
  # 3. Saves the result and handles errors
  # @param story [Story] the story to summarize
  # @return [void]
  def generate_story_summary(story)
    # Create a story-specific logger derived from the job logger
    story_logger = logger.tagged("Story ##{story.hn_id}")

    # Log that we're starting to generate a summary for monitoring
    story_logger.info("Generating content summary")

    # Find or build the summary record (does not save yet)
    summary = story.story_summary || story.build_story_summary

    # Set status to pending if needed (new record or not already pending)
    # Use bang method (save!) which raises error on failure, caught by outer rescue
    summary.status_pending! if summary.new_record? || !summary.status_pending?

    begin
      # Generate the summary content using the story logger
      content = generate_content_summary(story, story_logger)

      # Save the summary to the database and log the result (also sets status)
      save_summary(summary, content, "content", story.hn_id)
    rescue => e
      # Log any errors that occur during generation
      log_generation_error("content", story.hn_id, e)

      # Explicitly set status to failed on error
      # Use safe navigation in case summary object is unexpectedly nil
      summary&.update(status: :failed)
    end
  end

  # Generate the actual content summary using the AI
  # Separated from the main method to keep methods small and focused
  # @param story [Story] the story to summarize
  # @param story_logger [Logger] logger tagged with story information
  # @return [String] the generated summary
  def generate_content_summary(story, story_logger)
    # Log the content generation attempt
    story_logger.info("Starting content extraction and summarization")

    # Create a summarizer with appropriate adapters and pass the story logger
    summarizer = Ai::HnStorySummarizer.new(
      Ai::AdapterFactory.default_extraction_adapter(logger: story_logger),
      Ai::AdapterFactory.default_summary_adapter(logger: story_logger),
      Ai::AdapterFactory.default_classification_adapter(logger: story_logger),
      story.hn_id,
      {}, # Default options
      story_logger # Pass the story-specific logger
    )

    # Generate and return the summary
    # The summarizer handles all the content fetching and AI interaction
    summarizer.generate_story_summary
  end

  # Generate a summary for a story's comments
  # This method:
  # 1. Creates or finds the summary record
  # 2. Generates the summary content
  # 3. Saves the result and handles errors
  # @param story [Story] the story to summarize comments for
  # @return [void]
  def generate_comments_summary(story)
    # Create a story-specific logger derived from the job logger
    story_logger = logger.tagged("Story ##{story.hn_id}")

    # Log that we're starting to generate a comments summary
    story_logger.info("Generating comments summary")

    # Find or build the summary record (does not save yet)
    summary = story.comments_summary || story.build_comments_summary

    # Set status to pending if needed (new record or not already pending)
    # Use bang method (save!) which raises error on failure, caught by outer rescue
    summary.status_pending! if summary.new_record? || !summary.status_pending?

    begin
      # Generate the comment thread summary using the AI adapter and story logger
      content = generate_thread_summary(story, story_logger)

      # Save the summary to the database and log the result (also sets status)
      save_summary(summary, content, "comments", story.hn_id)
    rescue => e
      # Log any errors that occur during generation
      log_generation_error("comments", story.hn_id, e)

      # Explicitly set status to failed on error
      # Use safe navigation in case summary object is unexpectedly nil
      summary&.update(status: :failed)
    end
  end

  # Generate the actual thread summary using the AI
  # Separated from the main method to keep methods small and focused
  # @param story [Story] the story to summarize
  # @param story_logger [Logger] logger tagged with story information
  # @return [String] the generated summary
  def generate_thread_summary(story, story_logger)
    # Log the thread summary generation attempt
    story_logger.info("Starting thread summary generation")

    # Create a thread summarizer with the adapter and story logger
    # This specializes in summarizing comment threads
    summarizer = Ai::HnThreadSummarizer.new(
      Ai::AdapterFactory.default_summary_adapter(logger: story_logger),
      story.hn_id,
      {}, # Default options
      story_logger # Pass the story-specific logger
    )

    # Generate and return the summary of all comments
    # The summarizer handles fetching comments and AI interaction
    summarizer.generate_thread_summary
  end

  # Save a generated summary to the database
  # Centralizes saving logic to handle empty content consistently
  # @param summary [ActiveRecord] the summary record to update
  # @param content [String] the content to save
  # @param type [String] the type of summary (for logging)
  # @param story_id [Integer] the story ID (for logging)
  # @return [void]
  def save_summary(summary, content, type, story_id)
    # Only save if we received actual content
    # Empty content indicates an AI generation failure
    if content.present?
      # Update the summary record with the new content and set status to completed
      # Use update! to raise errors on validation failure
      summary.update!(content: content, status: :completed)

      # Log success for monitoring
      logger.info("Saved #{type} summary for story ##{story_id}, status set to completed")
    else
      # If content is empty, set status to failed and content to nil
      # Use update! to raise errors on validation failure
      summary.update!(content: nil, status: :failed)

      # Log warning if we received empty content
      # This indicates a potential issue with the AI or the content
      logger.warn("Generated empty #{type} summary for story ##{story_id}, status set to failed")
    end
  rescue => e
    # Log error if saving the final status fails
    logger.error("Failed to save final #{type} summary status for ##{story_id}: #{e.message}")

    # Re-raise the error to potentially trigger job retry mechanisms if needed
    raise e
  end

  # Log an error that occurred during summary generation
  # Centralizes error logging to maintain consistent format
  # @param type [String] the type of summary
  # @param story_id [Integer] the story ID
  # @param error [Exception] the error that occurred
  # @return [void]
  def log_generation_error(type, story_id, error)
    # Log the error with context information
    # This helps with diagnosing issues in the AI or extraction process
    logger.error(
      "Error generating #{type} summary for story ##{story_id}: #{error.message}"
    )
  end

  # Log completion status with summary statistics
  # Provides overall job statistics for monitoring
  # @return [void]
  def log_job_completion
    # Count stories with summaries for statistics
    # This helps track progress and success rate over time
    active_stories = Story.active.count

    # Count stories with non-empty content summaries
    stories_with_content = Story.active
      .joins(:story_summary)
      .where.not(story_summaries: { content: [ nil, "" ] })
      .count

    # Count stories with non-empty comment summaries
    stories_with_comments = Story.active
      .joins(:comments_summary)
      .where.not(comments_summaries: { content: [ nil, "" ] })
      .count

    # Log completion status with counts for monitoring
    logger.info("TopStoriesSummaryJob completed")
    logger.info("#{active_stories} active stories: #{stories_with_content} with content summaries, #{stories_with_comments} with comment summaries")
  end
end