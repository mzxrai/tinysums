# Render an array of story objects as JSON
# This Jbuilder template takes a collection of Story objects and formats them for the frontend
json.array! @stories do |story|
  # Use fragment caching for each story based on its updated_at timestamp
  json.cache! story do
    # Basic story information
    # The API uses "id" to refer to the HN ID, not our database ID
    json.id story.hn_id

    # Core story metadata from HN
    json.title story.title
    json.by story.by
    json.score story.score
    json.time story.time
    json.url story.url
    json.descendants story.descendants || 0
    json.type "story" # Always "story" for our model

    # Summaries
    json.story_summary story.story_summary&.content
    json.comments_summary story.comments_summary&.content

    # Include status information for the frontend
    # This lets the UI show appropriate loading/error states
    json.status do
      # Content summary status - directly from the record, or nil if no record exists
      # Use safe navigation (`&.`) to avoid errors if summary record is nil
      json.content story.story_summary&.status

      # Comments summary status - directly from the record, or nil if no record exists
      # Use safe navigation (`&.`) to avoid errors if summary record is nil
      json.comments story.comments_summary&.status

      # Timestamp of the most recent summary update (either type)
      # Use the latest updated_at from whichever summary exists and was updated last
      json.updatedAt [ story.story_summary&.updated_at, story.comments_summary&.updated_at ].compact.max&.to_i
    end
  end
end