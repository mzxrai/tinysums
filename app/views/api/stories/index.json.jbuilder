# Render an array of story objects as JSON
# This Jbuilder template takes a collection of Story objects and formats them for the frontend
json.array! @stories do |story|
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
    # Content summary status (returns null if no record exists)
    json.content story.story_summary ? "completed" : nil

    # Comments summary status (returns null if no record exists)
    json.comments story.comments_summary ? "completed" : nil

    # Timestamp of the most recent summary generation
    json.updatedAt (story.story_summary || story.comments_summary)&.updated_at&.to_i
  end
end