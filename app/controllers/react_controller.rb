# Controller for serving the React Single Page Application
class ReactController < ApplicationController
  # The number of top stories to fetch
  STORY_LIMIT = 30

  # Renders the main React SPA container
  # This action serves the same index template for any route that should be
  # handled by React Router client-side
  def index
  end
end