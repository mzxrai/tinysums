# Represents a generated AI summary of a Hacker News story's comments
# These summaries distill the key points from the comment thread for a given story
class CommentsSummary < ApplicationRecord
  # Association with the parent Story
  # Each comments summary belongs to exactly one story
  belongs_to :story, touch: true

  # Validations to ensure data integrity
  # Every summary must be associated with a story
  validates :story_id, presence: true
end