# Represents a Hacker News story from the HN API
# This model stores the core story data and tracks whether it's currently active in the top stories list
class Story < ApplicationRecord
  # Associations with summary models
  # When a story is deleted, its summaries are also deleted
  has_one :story_summary, dependent: :destroy

  # The comments summary uses a different class name than the default
  has_one :comments_summary, class_name: "CommentsSummary", dependent: :destroy

  # Validations to ensure data integrity
  # Each story must have a unique HN ID to prevent duplicates
  validates :hn_id, presence: true, uniqueness: true

  # Scopes for common query patterns
  # Find only stories currently marked as active in the top stories list
  scope :active, -> { where(active: true) }

  # Order stories by score (highest first) for ranking
  scope :ordered_by_score, -> { order(score: :desc) }

  # Order stories by their position on HN's front page
  # This ensures stories appear in the same order as on HN
  # Lower rank means higher position (1 is the top story)
  scope :ordered_by_rank, -> { order(rank: :asc) }

  # Find stories that need their article content summarized
  # A story needs summarization if it has no associated summary record
  # OR if the existing summary generation failed
  scope :needs_story_summary, lambda {
    # Join with story_summaries table, using LEFT OUTER JOIN to include stories without summaries
    left_outer_joins(:story_summary)
      # Select stories where either:
      # 1. The story_summary record doesn't exist (id is NULL)
      # 2. The story_summary status is marked as 'failed'
      .where(story_summaries: { id: nil })
      .or(where(story_summaries: { status: StorySummary.statuses[:failed] }))
  }

  # Find stories that need their comments summarized
  # A story needs comment summarization if it has no associated comments summary record
  scope :needs_comments_summary, -> { where.missing(:comments_summary) }

  # Extract the hostname from a URL, removing the 'www.' prefix
  # @return [String, nil] The hostname without 'www.', or nil if URL is invalid/missing
  def url_hostname
    # Return nil immediately if the URL is blank to avoid parsing
    return nil if url.blank?

    # Parse the URL and extract just the hostname, removing 'www.' if present
    URI.parse(url).host.sub(/^www\./, "")
  rescue URI::InvalidURIError
    # Return nil if the URL couldn't be parsed (invalid format)
    nil
  end

  # Update this story's attributes from fresh HN API data
  # @param hn_data [Hash] Data hash from the HN API containing story information
  # @param rank [Integer, nil] Optional rank to assign (position on HN front page)
  # @return [Boolean] true if update was successful, false if the IDs don't match
  def update_from_hn_data(hn_data, rank = nil)
    # Safety check: Only update if this is actually the same story
    return false unless hn_data["id"] == hn_id

    # Build attributes hash with all the story data
    attributes = {
      title: hn_data["title"],
      url: hn_data["url"],
      by: hn_data["by"],
      score: hn_data["score"],
      time: hn_data["time"],
      descendants: hn_data["descendants"] || 0
    }

    # Add rank to attributes if provided
    # This allows updating the front page position
    attributes[:rank] = rank if rank.present?

    # Update all story attributes from the HN data
    update(attributes)
  end

  # Mark this story as active in the current top stories list
  # @return [Boolean] true if the update was successful
  def mark_as_active!
    # Set the active flag to true and save
    update(active: true)
  end

  # Mark this story as inactive (no longer in the top stories list)
  # @return [Boolean] true if the update was successful
  def mark_as_inactive!
    # Set the active flag to false and save
    update(active: false)
  end
end