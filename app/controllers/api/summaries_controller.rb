# frozen_string_literal: true

module Api
  # Controller for the summaries API
  class SummariesController < ApplicationController
    # Redis key prefixes
    STORY_KEY_PREFIX = "hn:story".freeze
    SUMMARY_KEY_PREFIX = "hn:summary".freeze
    TOP_STORIES_KEY = "hn:top_stories".freeze

    # GET /api/summaries
    # Returns summaries for top stories
    def index
      # Get the top story IDs from Redis
      story_ids = fetch_top_story_ids

      # Fetch summary data for each story
      @summaries = fetch_summaries_for_stories(story_ids)

      render json: { summaries: @summaries }
    end

    # GET /api/summaries/:id
    # Returns the summary for a specific story
    def show
      story_id = params[:id]

      # Fetch the summary for this story
      @summary = fetch_summary(story_id)

      if @summary
        render json: @summary
      else
        render json: { error: "Summary not found" }, status: :not_found
      end
    end

    private

    # Fetch the list of top story IDs from Redis
    # @return [Array<Integer>] array of story IDs
    def fetch_top_story_ids
      story_ids = []

      Fast.with do |redis|
        # Try the sorted set first
        story_ids = redis.zrange("#{TOP_STORIES_KEY}:sorted", 0, -1)

        # If empty, try the list
        if story_ids.empty?
          cached_stories = redis.get("#{TOP_STORIES_KEY}:list")
          story_ids = JSON.parse(cached_stories) if cached_stories.present?
        end
      end

      # Convert to integers if they are strings
      story_ids.map(&:to_i)
    end

    # Fetch summaries for multiple stories
    # @param story_ids [Array<Integer>] array of story IDs
    # @return [Array<Hash>] array of story summary data
    def fetch_summaries_for_stories(story_ids)
      story_ids.map { |id| fetch_summary(id) }.compact
    end

    # Fetch the summary for a single story
    # @param story_id [Integer] the story ID
    # @return [Hash, nil] the summary data or nil if not found
    def fetch_summary(story_id)
      summary_data = {}

      # Get basic story metadata
      Fast.with do |redis|
        story_key = "#{STORY_KEY_PREFIX}:#{story_id}"
        story_data = redis.hgetall(story_key)

        return nil if story_data.empty?

        # Add basic story data
        summary_data = {
          id: story_id,
          title: story_data["title"],
          url: story_data["url"],
          by: story_data["by"],
          score: story_data["score"].to_i,
          time: story_data["time"].to_i,
          descendants: story_data["descendants"].to_i
        }

        # Get processing status
        status_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:status"
        status_data = redis.hgetall(status_key)

        if status_data.present?
          summary_data[:status] = {
            content: status_data["content_summary"],
            comments: status_data["comments_summary"],
            updated_at: status_data["updated_at"].to_i
          }
        end

        # Get content summary if it exists
        content_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:content"
        content_summary = redis.get(content_key)

        if content_summary.present?
          summary_data[:content_summary] = content_summary

          # Also get metadata
          content_meta_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:content:meta"
          content_meta = redis.hgetall(content_meta_key)

          if content_meta.present?
            summary_data[:content_summary_meta] = {
              generated_at: content_meta["generated_at"].to_i,
              word_count: content_meta["word_count"].to_i,
              character_count: content_meta["character_count"].to_i
            }
          end
        end

        # Get comments summary if it exists
        comments_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:comments"
        comments_summary = redis.get(comments_key)

        if comments_summary.present?
          summary_data[:comments_summary] = comments_summary

          # Also get metadata
          comments_meta_key = "#{SUMMARY_KEY_PREFIX}:#{story_id}:comments:meta"
          comments_meta = redis.hgetall(comments_meta_key)

          if comments_meta.present?
            summary_data[:comments_summary_meta] = {
              generated_at: comments_meta["generated_at"].to_i,
              word_count: comments_meta["word_count"].to_i,
              character_count: comments_meta["character_count"].to_i
            }
          end
        end
      end

      summary_data
    end
  end
end