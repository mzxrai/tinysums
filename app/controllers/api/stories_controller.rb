module Api
  # Controller for the stories API
  class StoriesController < ApplicationController
    # The number of top stories to fetch
    STORY_LIMIT = 30

    # GET /api/stories
    # Returns the top stories from Hacker News as JSON
    def index
      # Cache the stories for 1 hour
      @stories = Rails.cache.fetch("top_stories", expires_in: 1.hour) do
        # Initialize the API client
        client = HnApiClient.new

        # Fetch the top stories and filter out any without a title
        client.top_stories(STORY_LIMIT).compact.select { |story| story["title"].present? }
      end

      # Render the stories using Jbuilder
      # The view will be at app/views/api/stories/index.json.jbuilder
    end
  end
end