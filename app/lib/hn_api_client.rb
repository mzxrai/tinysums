# A client for interacting with the HackerNews API
# @see https://github.com/HackerNews/API
class HnApiClient
  # Base URL for the HackerNews API
  BASE_URL = "https://hacker-news.firebaseio.com/v0".freeze

  # Creates a new HackerNews API client
  # @param connection [Faraday::Connection] optional custom Faraday connection
  def initialize(connection = nil)
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
    response = @connection.get("topstories.json")
    return [] unless response.success?
    response.body
  end

  # Fetches the details of a specific item
  # @param id [Integer] the ID of the item to fetch
  # @return [Hash, nil] the item details or nil if not found
  def get_item(id)
    response = @connection.get("item/#{id}.json")
    return nil unless response.success?
    response.body
  end

  private

  # Creates a default Faraday connection
  # @return [Faraday::Connection]
  def default_connection
    Faraday.new(url: BASE_URL) do |conn|
      conn.request :json
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end
end