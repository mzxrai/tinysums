# Represents a generated AI summary of a Hacker News story's comments
# These summaries distill the key points from the comment thread for a given story
class CommentsSummary < ApplicationRecord
  # Association with the parent Story
  # Each comments summary belongs to exactly one story
  belongs_to :story, touch: true

  # Define the possible states for the summary generation process
  # - pending: Initial state, generation not yet attempted or in progress
  # - completed: Generation succeeded, content is present
  # - failed: Generation attempted but failed
  enum status: {
    pending: "pending",     # The summary generation is pending
    completed: "completed", # The summary generation completed successfully
    failed: "failed"        # The summary generation failed
  }, prefix: true           # Add prefix to methods, e.g., status_pending?

  # Validations to ensure data integrity
  # Every summary must be associated with a story
  validates :story_id, presence: true

  # Every summary must have a valid status
  validates :status, presence: true, inclusion: { in: statuses.keys }
end