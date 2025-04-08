# Controller for displaying Hacker News content
class HackerNewsController < ApplicationController
  # The number of top stories to fetch
  STORY_LIMIT = 30

  # GET /hacker_news
  # Displays the top stories from Hacker News
  def index
    # Initialize the API client
    @client = HnApiClient.new

    # Fetch the top stories
    @stories = Rails.cache.fetch("top_stories", expires_in: 1.hour) do
      @client.top_stories(STORY_LIMIT).compact.select { |story| story["title"].present? }
    end
  end
end