# Render a single story object as JSON
# This Jbuilder template formats a Story object for the frontend
# using the same structure as the index view for consistency

# Basic story information
# The API uses "id" to refer to the HN ID, not our database ID
json.id @story.hn_id

# Core story metadata from HN
json.title @story.title
json.by @story.by
json.score @story.score
json.time @story.time
json.url @story.url
json.descendants @story.descendants || 0
json.type "story" # Always "story" for our model

# Summaries - these may be nil if not generated yet
json.story_summary @story.story_summary&.content
json.comments_summary @story.comments_summary&.content

# Include status information for the frontend
# This lets the UI show appropriate loading/error states
json.status do
  # Content summary status (returns "completed" if summary exists, nil otherwise)
  json.content @story.story_summary ? "completed" : nil

  # Comments summary status (returns "completed" if summary exists, nil otherwise)
  json.comments @story.comments_summary ? "completed" : nil

  # Timestamp of the most recent summary generation
  # Uses the max updated_at time from either summary
  json.updatedAt (
    [ @story.story_summary&.updated_at, @story.comments_summary&.updated_at ]
      .compact
      .max
      &.to_i
  )
end