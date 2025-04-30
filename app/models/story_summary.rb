# Represents a generated AI summary of a Hacker News story's content
# These summaries are created from the URL content of the story and stored for display
class StorySummary < ApplicationRecord
  # Association with the parent Story
  # Each summary belongs to exactly one story
  belongs_to :story, touch: true

  # Validations to ensure data integrity
  # Every summary must be associated with a story
  validates :story_id, presence: true
end