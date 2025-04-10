# frozen_string_literal: true

namespace :hn do
  desc "Fetch and summarize top HN stories"
  task :summarize_stories, [ :count, :adapter ] => :environment do |_, args|
    count = (args[:count] || 30).to_i
    adapter = args[:adapter]

    adapter_text = adapter ? " using #{adapter} adapter" : ""
    puts "Starting summarization of top #{count} HN stories#{adapter_text}..."

    job_id = HnTopStoriesJob.perform_async(count, true, adapter)
    puts "Enqueued HnTopStoriesJob with ID: #{job_id}"
  end

  desc "Summarize a specific HN story"
  task :summarize_story, [ :story_id, :adapter ] => :environment do |_, args|
    story_id = args[:story_id].to_i
    adapter = args[:adapter]

    adapter_text = adapter ? " using #{adapter} adapter" : ""
    puts "Starting summarization of HN story ##{story_id}#{adapter_text}..."

    job_id = HnStorySummarizerJob.perform_async(story_id, nil, adapter)
    puts "Enqueued HnStorySummarizerJob with ID: #{job_id}"
  end

  desc "Clear all stored summaries"
  task clear_summaries: :environment do
    puts "Clearing all stored summaries..."

    # Delete all hn: prefixed keys in Redis
    Fast.with do |redis|
      keys = redis.keys("hn:*")
      if keys.any?
        redis.del(*keys)
        puts "Deleted #{keys.size} keys from Redis"
      else
        puts "No summaries found in Redis"
      end
    end
  end
end