# A client for interacting with the HackerNews API
# @see https://github.com/HackerNews/API
class HnApiClient
  # Base URL for the HackerNews API
  BASE_URL = "https://hacker-news.firebaseio.com/v0".freeze

  # Cache expiration times for different types of HN data
  # User information changes less frequently, so we cache it longer
  USER_CACHE_EXPIRATION = 10.days
  # Items (stories, comments) may be edited, but older comments rarely change
  ITEM_CACHE_EXPIRATION = 5.minutes

  # Define attribute readers
  attr_reader :connection

  # Creates a new HackerNews API client
  # @param connection [Faraday::Connection] optional custom Faraday connection
  def initialize(connection = nil)
    # Use the provided connection or create a default one
    @connection = connection || default_connection
  end

  # Fetches the top stories from HackerNews
  # @param limit [Integer] maximum number of stories to fetch (default: 30)
  # @return [Array<Hash>] array of story items with details
  def top_stories(limit = 30)
    # Fetch IDs of top stories
    story_ids = get_top_story_ids.first(limit)

    # Fetch details for each story
    story_ids.map { |id| get_item(id) }
  end

  # Fetches the IDs of the current top stories
  # @return [Array<Integer>] array of story IDs
  def get_top_story_ids
    # Make API request to get top story IDs
    response = connection.get("topstories.json")
    # Return empty array if the request failed
    return [] unless response.success?
    # Return the array of story IDs
    response.body
  end

  # Fetches the details of a specific item (story, comment, etc.)
  # @param id [Integer] the ID of the item to fetch
  # @return [Hash, nil] the item details or nil if not found
  def get_item(id)
    # Use Rails cache to store item data for ITEM_CACHE_EXPIRATION time
    # The cache key is prefixed with "hn_item_" to avoid collisions
    Rails.cache.fetch("hn_item_#{id}", expires_in: ITEM_CACHE_EXPIRATION) do
      # Only make the API request if item is not in cache
      response = connection.get("item/#{id}.json")
      # Return nil if the request failed
      return nil unless response.success?
      # Store the response body in cache and return it
      response.body
    end
  end

  # Fetches a user's information from HackerNews
  # @param username [String] the username to fetch
  # @return [Hash, nil] the user details or nil if not found
  def get_user(username)
    # Return nil for nil or empty usernames
    return nil if username.nil? || username.empty?

    # Use Rails cache to store user data for USER_CACHE_EXPIRATION time
    # The cache key is prefixed with "hn_user_" to avoid collisions
    Rails.cache.fetch("hn_user_#{username}", expires_in: USER_CACHE_EXPIRATION) do
      # Only make the API request if user is not in cache
      response = connection.get("user/#{username}.json")
      # Return nil if the request failed
      return nil unless response.success?
      # Store the response body in cache and return it
      response.body
    end
  end

  # Fetches all comments for a story including their nested structure
  # @param story_id [Integer] the ID of the story to fetch comments for
  # @param max_comments [Integer, nil] optional limit on total comments to fetch (nil = no limit)
  # @return [Hash] the story with a complete comment tree
  def get_story_with_comments(story_id, max_comments = nil)
    # Get the story details using our cached get_item method
    story = get_item(story_id)
    # Return nil if story not found
    return nil unless story

    # Initialize comments array and counter
    comment_count = 0
    story["comments"] = []

    # Process comments if the story has any
    if story["kids"] && !story["kids"].empty?
      # Process each top-level comment
      story["kids"].each do |comment_id|
        # Stop if we've reached the maximum comments limit
        break if max_comments && comment_count >= max_comments

        # Fetch the full comment tree for this comment_id
        comment = fetch_comment_tree(comment_id, max_comments, comment_count)

        # Only add comments that are not deleted
        if comment
          # Add comment to story's comments array
          story["comments"] << comment
          # Update the total comment count
          comment_count += count_comments(comment)
        end

        # Check again if we've hit the limit after processing this comment
        break if max_comments && comment_count >= max_comments
      end
    end

    # Add metadata about how many comments we actually processed
    story["processed_comment_count"] = comment_count

    # Return the story with its comment tree
    story
  end

  private

  # Recursively fetches a comment and all its replies
  # @param comment_id [Integer] the ID of the comment to fetch
  # @param max_comments [Integer, nil] maximum total comments to fetch
  # @param current_count [Integer] current comment count (for tracking against max)
  # @return [Hash, nil] the comment with its replies or nil if deleted/not found
  def fetch_comment_tree(comment_id, max_comments, current_count)
    # Get the comment data using our cached get_item method
    comment = get_item(comment_id)
    # Skip deleted or missing comments
    return nil if comment.nil? || comment["deleted"]

    # Add replies array to store nested comments
    comment["replies"] = []

    # Process replies if the comment has any
    if comment["kids"] && !comment["kids"].empty?
      comment["kids"].each do |reply_id|
        # Stop processing if we've hit the maximum comment limit
        break if max_comments && current_count >= max_comments

        # Recursively fetch the reply and its children
        reply = fetch_comment_tree(reply_id, max_comments, current_count)
        if reply
          # Add reply to the comment's replies array
          comment["replies"] << reply
          # Update the running count of processed comments
          current_count += count_comments(reply)
        end

        # Check again after processing this branch
        break if max_comments && current_count >= max_comments
      end
    end

    # Return the comment with its reply tree
    comment
  end

  # Counts the total number of comments in a comment tree
  # @param comment [Hash] the comment tree to count
  # @return [Integer] the total number of comments
  def count_comments(comment)
    # Return 0 for nil comments
    return 0 if comment.nil?

    # Start with 1 for this comment itself
    count = 1

    # Add counts for all replies recursively
    if comment["replies"] && !comment["replies"].empty?
      comment["replies"].each do |reply|
        # Add the count of this reply and all its descendants
        count += count_comments(reply)
      end
    end

    # Return the total count
    count
  end

  # Creates a default Faraday connection
  # @return [Faraday::Connection]
  def default_connection
    # Configure a new Faraday connection with JSON request/response handling
    Faraday.new(url: BASE_URL) do |conn|
      # Set up JSON request formatting
      conn.request :json
      # Set up JSON response parsing
      conn.response :json
      # Use the default Faraday adapter
      conn.adapter Faraday.default_adapter
    end
  end
end