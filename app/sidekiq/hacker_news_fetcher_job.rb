# A Sidekiq job that fetches the top Hacker News articles
class HackerNewsFetcherJob
  include Sidekiq::Job

  # The number of top stories to fetch
  STORY_LIMIT = 30

  # Performs the job of fetching top HN stories
  # @param args [Array] job arguments (unused)
  def perform(*args)
    Rails.logger.info("Fetching top #{STORY_LIMIT} Hacker News stories")

    # Initialize the API client
    client = HnApiClient.new

    # Fetch the top stories
    stories = client.top_stories(STORY_LIMIT)

    # Print the story titles and URLs
    stories.each do |story|
      # Skip if story is nil or doesn't have necessary attributes
      next if story.nil? || !story["title"]

      # Format and print the story information
      title = story["title"]
      url = story["url"] || "https://news.ycombinator.com/item?id=#{story["id"]}"

      Rails.logger.info("#{title} - #{url}")
    end

    Rails.logger.info("Completed fetching Hacker News stories")
  end
end