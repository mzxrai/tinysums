# Controller for serving the React Single Page Application
class ReactController < ApplicationController
  # The number of top stories to fetch
  STORY_LIMIT = 30

  # Renders the main React SPA container
  # This action serves the same index template for any route that should be
  # handled by React Router client-side
  def index
    # Initialize the API client
    @client = HnApiClient.new

    # Fetch the top stories
    @stories = Rails.cache.fetch("top_stories", expires_in: 1.hour) do
      @client.top_stories(STORY_LIMIT).compact.select { |story| story["title"].present? }
    end
  end
end