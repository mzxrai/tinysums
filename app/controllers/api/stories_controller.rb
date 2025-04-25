module Api
  # Controller for the stories API
  # Provides top Hacker News stories with AI-generated summaries
  class StoriesController < ApplicationController
    # The number of top stories to fetch
    STORY_LIMIT = 30

    # GET /api/stories
    # Returns the top active stories from the database as JSON, including any generated summaries
    # @return [void] - renders JSON via Jbuilder view
    def index
      # Fetch active stories with their summaries in a single chained query
      @stories = Story.active
                      .ordered_by_rank  # Use rank ordering to match HN front page
                      .limit(STORY_LIMIT)
                      .includes(:story_summary, :comments_summary)

      # Render stories using Jbuilder
      # View: app/views/api/stories/index.json.jbuilder
    end
  end
end