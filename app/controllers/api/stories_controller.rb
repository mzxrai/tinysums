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
      # The view will handle fragment caching for individual stories
      @stories = Story.active
                      .ordered_by_rank # Use rank ordering to match HN front page
                      .limit(STORY_LIMIT)
                      .includes(:story_summary, :comments_summary)

      # Render stories using Jbuilder with fragment caching
      # View: app/views/api/stories/index.json.jbuilder
    end

    # GET /api/stories/:id
    # Returns a single story by HN ID with its summaries
    # This endpoint works for both active and inactive stories to support permalinks
    # @return [void] - renders JSON or error message
    def show
      # Find the story by HN ID, not by database ID
      # This allows accessing stories via their HN IDs in the URL
      @story = Story.find_by(hn_id: params[:id])

      # Check if the story was found in the database
      if @story
        # Eager load the associated summaries for performance
        # This prevents N+1 queries when rendering the JSON
        @story = Story.includes(:story_summary, :comments_summary).find(@story.id)

        # Render the story using the show template
        # The template will be created at app/views/api/stories/show.json.jbuilder
      else
        # Return a 404 response with a descriptive error message
        # This helps the frontend handle the error appropriately
        render json: { error: "Story not found" }, status: :not_found
      end
    end
  end
end