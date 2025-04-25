# Service for summarizing Hacker News discussion threads
# Uses a weighted approach to select valuable comments for summarization
class Ai::HnThreadSummarizer
  # Default options for thread summarization
  DEFAULT_OPTIONS = {
    # Percentage of threads to include based on thread size
    small_thread_percentage: 100,     # < 100 comments: include all
    medium_thread_percentage: 80,     # 100-500 comments: include ~50%
    large_thread_percentage: 65,      # 500-2000 comments: include ~35%
    very_large_thread_percentage: 50, # 2000-5000 comments: include ~25%
    massive_thread_minimum: 1000,     # 5000+ comments: include at least 1000

    # Thread size thresholds
    small_thread_threshold: 100,
    medium_thread_threshold: 500,
    large_thread_threshold: 2000,
    very_large_threshold: 5000,

    # Weights for comment scoring
    descendant_weight: 0.5, # Weight for number of replies
    karma_weight: 0.3,      # Weight for author karma
    content_weight: 0.2,    # Weight for content characteristics

    # Comment format template (can be customized)
    comment_format: "Comment by %{username} (karma: %{karma})\n%{text}\n\n"
  }.freeze

  # Define attribute readers for instance variables
  attr_reader :adapter, :hn_client, :options, :story

  # Initialize the thread summarizer
  # @param adapter [Ai::BaseAiAdapter] the AI adapter to use for summarization
  # @param story_id [Integer] the HN story ID to summarize
  # @param options [Hash] options to override defaults
  def initialize(adapter, story_id, options = {})
    # Store the AI adapter for making summarization requests
    @adapter = adapter

    # Create a new HN API client instance
    @hn_client = HnApiClient.new

    # Fetch the complete story with all its comments
    @story = fetch_story_with_comments(story_id)

    # Merge default options with any custom options provided
    @options = DEFAULT_OPTIONS.merge(options)
  end

  # Generate a comprehensive summary of the HN story's comments
  # @return [String] the generated summary or nil if story not found
  def generate_thread_summary
    # Return nil immediately if story wasn't found
    return nil unless story

    # Add author karma information to all comments for better scoring
    enrich_comments_with_karma

    # Score and select the top comments worth including in the summary
    selected_comments = select_comments_for_summarization

    # Format the selected comments into a structure suitable for summarization
    formatted_content = format_comments_for_summarization(selected_comments)

    # Truncate the content if it exceeds the AI model's maximum input size
    formatted_content = truncate_if_needed(formatted_content)

    # Generate and return the final summary from the formatted content
    generate_summary(formatted_content)
  end

  # Check if the comments for a story have changed since the last summary
  # @param latest_summary_time [Time] time when the last summary was generated
  # @return [Boolean] true if comments have changed, false otherwise
  def comments_changed?(latest_summary_time)
    # Always return true if no previous summary time provided
    return true unless latest_summary_time

    # Convert the provided time to unix timestamp for direct comparison
    last_summary_timestamp = latest_summary_time.to_i

    # Find the timestamp of the most recent comment in the story
    latest_comment_time = find_latest_comment_time(story)

    # Return true if there are newer comments or the comment count has changed
    latest_comment_time > last_summary_timestamp ||
      descendants_changed?(last_summary_timestamp)
  end

  # Find the timestamp of the latest comment in a thread
  # @param comment_thread [Hash] the comment thread to search
  # @return [Integer] unix timestamp of the latest comment
  def find_latest_comment_time(comment_thread)
    # Return 0 if the thread is nil
    return 0 unless comment_thread

    # Start with the story's own timestamp as the baseline
    latest_time = comment_thread["time"] || 0

    # Check all comments in the thread to find the most recent timestamp
    if has_comments?(comment_thread)
      # Process all comments to find the latest timestamp
      latest_time = find_latest_time_in_comments(comment_thread["comments"], latest_time)
    end

    # Return the latest timestamp found
    latest_time
  end

  # Helper to check if a thread has comments
  # @param thread [Hash] the thread to check
  # @return [Boolean] true if thread has comments
  def has_comments?(thread)
    # Check both that comments array exists and is not empty
    thread["comments"] && !thread["comments"].empty?
  end

  # Find latest time in a list of comments
  # @param comments [Array] array of comments
  # @param latest_time [Integer] current latest time
  # @return [Integer] updated latest time
  def find_latest_time_in_comments(comments, latest_time)
    # Iterate through each comment to find the latest timestamp
    comments.each do |comment|
      # Get this comment's timestamp (default to 0 if missing)
      comment_time = comment["time"] || 0

      # Update the latest time if this comment is more recent
      latest_time = [ latest_time, comment_time ].max

      # Check for replies to this comment
      if comment["replies"] && !comment["replies"].empty?
        # Process replies recursively to find latest timestamp
        latest_time = find_latest_time_in_replies(comment["replies"], latest_time)
      end
    end

    # Return the latest timestamp found
    latest_time
  end

  # Helper to find latest comment time in replies recursively
  # @param replies [Array] array of reply comments
  # @param latest_time [Integer] current latest time
  # @return [Integer] updated latest time
  def find_latest_time_in_replies(replies, latest_time)
    # Process each reply to find the latest timestamp
    replies.each do |reply|
      # Get this reply's timestamp (default to 0 if missing)
      reply_time = reply["time"] || 0

      # Update the latest time if this reply is more recent
      latest_time = [ latest_time, reply_time ].max

      # Check for nested replies
      if reply["replies"] && !reply["replies"].empty?
        # Process nested replies recursively
        latest_time = find_latest_time_in_replies(reply["replies"], latest_time)
      end
    end

    # Return the latest timestamp found
    latest_time
  end

  # Check if the number of descendants (comments) has changed
  # @param last_summary_timestamp [Integer] time when the last summary was generated
  # @return [Boolean] true if descendant count has changed, false otherwise
  def descendants_changed?(last_summary_timestamp)
    # Retrieve the previously cached comment count for this story
    cached_count = Rails.cache.read("hnsum:comment_count:#{story['id']}")

    # Get the current comment count from the story data
    current_count = story["descendants"] || 0

    # Store the current count in cache for future comparisons
    Rails.cache.write("hnsum:comment_count:#{story['id']}", current_count)

    # Return true if we don't have a cached count or if the count has changed
    cached_count.nil? || cached_count != current_count
  end

  private

  # Truncate content if it exceeds maximum size
  # @param content [String] content to check and possibly truncate
  # @return [String] original or truncated content
  def truncate_if_needed(content)
    # Check if the content exceeds the maximum input size
    if exceeds_max_input_size?(content)
      # Truncate the content to fit within limits
      truncate_content(content)
    else
      # Return the original content unchanged
      content
    end
  end

  # Fetch a story with its complete comment tree
  # @param story_id [Integer] the HN story ID to fetch
  # @return [Hash, nil] the story with its comment tree or nil if not found
  def fetch_story_with_comments(story_id)
    # Log the start of the API call for monitoring
    Rails.logger.info("HN API CALL: Fetching story ##{story_id} with comments")

    # Use the HN client to fetch the story and all comments
    story = hn_client.get_story_with_comments(story_id)

    # Log the completion of the API call with comment count
    log_fetch_completion(story_id, story)

    # Return the story with its full comment tree
    story
  end

  # Log completion of fetch operation
  # @param story_id [Integer] the HN story ID
  # @param story [Hash] the fetched story
  def log_fetch_completion(story_id, story)
    # Calculate the number of comments (0 if story not found)
    comment_count = story ? story["descendants"] || 0 : 0

    # Log the API call completion with the comment count
    Rails.logger.info(
      "HN API CALL COMPLETE: Fetched story ##{story_id} with #{comment_count} comments"
    )
  end

  # Add karma information to comments to aid in selection/scoring
  def enrich_comments_with_karma
    # Return early if no comments to process
    return unless story["comments"]

    # Process each top-level comment in the story
    story["comments"].each do |comment|
      # Add author karma information to this comment
      add_karma_to_comment(comment)

      # Process all replies recursively to add karma
      process_replies_with_karma(comment)
    end
  end

  # Add karma information to a single comment
  # @param comment [Hash] the comment to enrich
  def add_karma_to_comment(comment)
    # Skip if comment has no author (deleted comment)
    return if comment["by"].nil?

    # Log the start of user information fetch
    log_user_fetch_start(comment["by"])

    # Retrieve user information from the HN API
    user = hn_client.get_user(comment["by"])

    # Calculate karma value (default to 0 if user not found)
    user_karma = user ? user["karma"] || 0 : 0

    # Add the karma value to the comment data
    comment["author_karma"] = user_karma

    # Log the completion of the user fetch
    log_user_fetch_complete(comment["by"], user_karma)
  end

  # Log start of user fetch operation
  # @param username [String] the username being fetched
  def log_user_fetch_start(username)
    # Log the API call start with the username
    Rails.logger.info("HN API CALL: Fetching user #{username} for karma lookup")
  end

  # Log completion of user fetch operation
  # @param username [String] the username that was fetched
  # @param karma [Integer] the user's karma
  def log_user_fetch_complete(username, karma)
    # Log the API call completion with username and karma
    Rails.logger.info(
      "HN API CALL COMPLETE: Fetched user #{username} with karma #{karma}"
    )
  end

  # Process replies recursively to add karma
  # @param comment [Hash] the parent comment with replies
  def process_replies_with_karma(comment)
    # Return early if the comment has no replies
    return unless comment["replies"] && !comment["replies"].empty?

    # Process each reply to the comment
    comment["replies"].each do |reply|
      # Add karma to this specific reply
      add_karma_to_comment(reply)

      # Process any nested replies recursively
      process_replies_with_karma(reply)
    end
  end

  # Select top-level comments for summarization based on scoring
  # @return [Array<Hash>] selected comments for summarization
  def select_comments_for_summarization
    # Calculate total comment count for the story
    total_comments = story["descendants"] || 0

    # Determine what percentage of comments to include based on thread size
    percentage = determine_selection_percentage(total_comments)

    # Calculate the actual number of comments to select
    selection_count = calculate_selection_count(percentage)

    # Score and select the top comments
    select_top_comments(selection_count)
  end

  # Calculate how many comments to select
  # @param percentage [Float] percentage of comments to include
  # @return [Integer] number of comments to select
  def calculate_selection_count(percentage)
    # Return 0 if there are no comments to select from
    return 0 unless story["comments"]

    # Count the total number of top-level comments
    top_level_count = story["comments"].size

    # Calculate selection count, taking the smaller of:
    # 1. Ceiling of the percentage of top-level comments
    # 2. The actual number of top-level comments
    [
      (top_level_count * percentage / 100.0).ceil,
      top_level_count
    ].min
  end

  # Score and select top comments
  # @param selection_count [Integer] number of comments to select
  # @return [Array<Hash>] selected top comments
  def select_top_comments(selection_count)
    # Return empty array if no comments to select or selection count is 0
    return [] if selection_count == 0 || !story["comments"]

    # Calculate scores for all top-level comments
    scored_comments = score_comments(story["comments"])

    # Sort by score (descending), select the top N, and extract just the comment data
    selected_comments = scored_comments
      .sort_by { |c| -c[:score] }
      .first(selection_count)
      .map { |c| c[:comment] }

    # Return the selected top comments
    selected_comments
  end

  # Determine what percentage of comments to include based on thread size
  # @param total_comments [Integer] total number of comments in thread
  # @return [Float] percentage of comments to include
  def determine_selection_percentage(total_comments)
    # For small threads (< 100 comments), use small thread percentage
    if total_comments < options[:small_thread_threshold]
      options[:small_thread_percentage]
    # For medium threads (100-500 comments), use medium thread percentage
    elsif total_comments < options[:medium_thread_threshold]
      options[:medium_thread_percentage]
    # For large threads (500-2000 comments), use large thread percentage
    elsif total_comments < options[:large_thread_threshold]
      options[:large_thread_percentage]
    # For very large threads (2000-5000 comments), use very large thread percentage
    elsif total_comments < options[:very_large_threshold]
      options[:very_large_thread_percentage]
    # For massive threads (5000+ comments), calculate special percentage
    else
      calculate_massive_thread_percentage(total_comments)
    end
  end

  # Calculate percentage for massive threads
  # @param total_comments [Integer] total number of comments
  # @return [Float] calculated percentage
  def calculate_massive_thread_percentage(total_comments)
    # For huge threads, take the smaller of:
    # 1. Percentage needed to include at least the minimum number
    # 2. The very large thread percentage as a cap
    [
      (options[:massive_thread_minimum].to_f / total_comments * 100),
      options[:very_large_thread_percentage]
    ].min
  end

  # Score comments based on descendants, karma, and content
  # @param comments [Array<Hash>] comments to score
  # @return [Array<Hash>] comments with scores
  def score_comments(comments)
    # Create an empty array to collect scored comments
    scored_comments = []

    # Process each comment to calculate its score
    comments.each do |comment|
      # Skip deleted comments as they contain no valuable information
      next if comment["deleted"]

      # Calculate the overall score for this comment
      total_score = calculate_total_score(comment)

      # Add the comment and its score to our results array
      scored_comments << { comment: comment, score: total_score }
    end

    # Return the complete array of scored comments
    scored_comments
  end

  # Calculate total score for a comment
  # @param comment [Hash] the comment to score
  # @return [Float] the total weighted score
  def calculate_total_score(comment)
    # Calculate score based on number of replies (thread size)
    descendant_score = calculate_descendant_score(comment)

    # Calculate score based on author's karma (reputation)
    karma_score = calculate_karma_score(comment)

    # Calculate score based on comment content features
    content_score = calculate_content_score(comment)

    # Calculate weighted total score using the configured weights
    (
      descendant_score * options[:descendant_weight] +
      karma_score * options[:karma_weight] +
      content_score * options[:content_weight]
    )
  end

  # Calculate score based on number of descendants (replies)
  # @param comment [Hash] comment to score
  # @return [Float] normalized score between 0-1
  def calculate_descendant_score(comment)
    # Count all replies to this comment recursively
    descendant_count = count_descendants(comment)

    # Normalize with logarithmic scale to get a score between 0-1
    # This gives diminishing returns for extremely large threads
    Math.log(1 + descendant_count) / Math.log(1000)
  end

  # Count total descendants (replies) of a comment
  # @param comment [Hash] the comment to count descendants for
  # @return [Integer] total number of descendants
  def count_descendants(comment)
    # Return 0 if the comment has no replies
    return 0 unless comment["replies"] && !comment["replies"].empty?

    # Initialize counter for descendants
    count = 0

    # Process each reply to count it and its own replies
    comment["replies"].each do |reply|
      # Count this reply (1) plus all of its descendants recursively
      count += 1 + count_descendants(reply)
    end

    # Return the total count of all descendants
    count
  end

  # Calculate score based on author's karma
  # @param comment [Hash] comment to score
  # @return [Float] normalized score between 0-1
  def calculate_karma_score(comment)
    # Get the author's karma value (default to 0 if not set)
    karma = comment["author_karma"] || 0

    # Handle negative karma by clamping to minimum of 0
    karma = [ karma, 0 ].max

    # Normalize with logarithmic scale to get a score between 0-1
    # This gives diminishing returns for extremely high karma
    Math.log(1 + karma) / Math.log(100000)
  end

  # Calculate score based on content characteristics
  # @param comment [Hash] comment to score
  # @return [Float] score between 0-1
  def calculate_content_score(comment)
    # Get the text content of the comment (default to empty string)
    text = comment["text"] || ""

    # Calculate raw score based on various content features
    score = calculate_content_features_score(text)

    # Ensure the final score doesn't exceed 1.0
    [ score, 1.0 ].min
  end

  # Calculate score based on text features
  # @param text [String] the comment text
  # @return [Float] raw score (may exceed 1.0)
  def calculate_content_features_score(text)
    # Start with a base score of 0
    score = 0.0

    # Give points for longer comments (up to 0.3 max)
    # Length-based scoring with diminishing returns
    score += [ text.length / 2000.0, 0.3 ].min

    # Give bonus points for comments containing links
    # Links often provide valuable external resources
    score += 0.3 if text.include?("<a href=")

    # Give bonus points for comments containing code
    # Code examples are often highly valuable in technical discussions
    score += 0.4 if text.include?("<code>") || text.include?("<pre>")

    # Return the calculated score
    score
  end

  # Format selected comments for AI summarization
  # @param selected_comments [Array<Hash>] selected comments
  # @return [String] formatted text for the AI
  def format_comments_for_summarization(selected_comments)
    # Create the header with story information
    header = build_header(selected_comments.size)

    # Format all comments and their replies into text
    comments_text = format_all_comments(selected_comments)

    # Combine header and formatted comments
    header + comments_text
  end

  # Build the header section with story info
  # @param comment_count [Integer] number of comments processed
  # @return [String] formatted header
  def build_header(comment_count)
    # Start with the story title as main heading
    header = "# Hacker News Discussion: #{story['title']}\n\n"

    # Add the story URL if available
    header += "URL: #{story['url']}\n" if story["url"]

    # Add the original poster's username
    header += "Posted by: #{story['by']}\n"

    # Add total comment count for the full story
    header += "Total comments: #{story['descendants'] || 0}\n"

    # Add number of comments being processed in this summary
    header += "Comments processed: #{comment_count}\n\n"

    # Return the complete header text
    header
  end

  # Format all comments with their replies
  # @param comments [Array<Hash>] comments to format
  # @return [String] formatted comments text
  def format_all_comments(comments)
    # Format each comment with its index and join with newlines
    comments.map.with_index do |comment, index|
      # Format this comment and all its replies recursively
      # Index for top-level comments starts at 1
      format_comment_with_replies(comment, "#{index + 1}", 0)
    end.join("\n")
  end

  # Format a comment and its replies recursively
  # @param comment [Hash] the comment to format
  # @param index [String] the hierarchical index (e.g., "1", "1.2", etc.)
  # @param depth [Integer] the nesting depth of the comment
  # @return [String] formatted comment text
  def format_comment_with_replies(comment, index, depth)
    # Skip deleted comments
    return "" if comment["deleted"]

    # Format the comment itself (without replies)
    comment_text = format_single_comment(comment, index, depth)

    # Check if this comment has replies and handle accordingly
    if has_replies?(comment) && depth < 4
      # If has replies and not at max depth, add formatted replies
      comment_text += format_comment_replies(comment, index, depth)
    elsif has_replies?(comment) && depth >= 4
      # If at max depth but has replies, add a note about omitted replies
      comment_text += format_depth_limit_note(comment)
    end

    # Return the complete formatted comment (with replies if applicable)
    comment_text
  end

  # Check if a comment has replies
  # @param comment [Hash] the comment to check
  # @return [Boolean] true if the comment has replies
  def has_replies?(comment)
    # Check both that replies array exists and is not empty
    comment["replies"] && !comment["replies"].empty?
  end

  # Format a single comment without its replies
  # @param comment [Hash] the comment to format
  # @param index [String] the hierarchical index
  # @param depth [Integer] the nesting depth
  # @return [String] formatted comment text
  def format_single_comment(comment, index, depth)
    # Calculate heading level based on depth (2-6)
    # Deeper comments get more # characters, capped at 6 (h6)
    heading_level = "#" * [ 2 + depth, 6 ].min

    # Format the comment text using the template
    formatted_text = options[:comment_format] % {
      username: comment["by"] || "[deleted]",
      karma: comment["author_karma"] || 0,
      text: comment["text"] || ""
    }

    # Create the complete comment text with heading and content
    "#{heading_level} [#{index}] (depth #{depth})\n#{formatted_text}"
  end

  # Format replies for a comment
  # @param comment [Hash] parent comment
  # @param index [String] parent index
  # @param depth [Integer] parent depth
  # @return [String] formatted replies text
  def format_comment_replies(comment, index, depth)
    # Score and sort the replies by relevance
    scored_replies = score_comments(comment["replies"])

    # Sort replies in descending order by score
    sorted_replies = scored_replies.sort_by { |r| -r[:score] }

    # Format each reply with a hierarchical index
    replies_text = sorted_replies.map.with_index do |scored_reply, i|
      # Get the reply data from the scored reply
      reply = scored_reply[:comment]

      # Format this reply and its own replies recursively
      # Hierarchical index: parent index + "." + reply number
      format_comment_with_replies(reply, "#{index}.#{i + 1}", depth + 1)
    end.join("\n")

    # Return the formatted replies with a leading newline
    "\n" + replies_text
  end

  # Format note when depth limit is reached
  # @param comment [Hash] the comment at max depth
  # @return [String] formatted depth limit note
  def format_depth_limit_note(comment)
    # Create a note indicating how many replies were omitted
    "\n[DEPTH LIMIT REACHED: #{comment["replies"].size} additional replies not shown]"
  end

  # Check if content exceeds max input size
  # @param content [String] the content to check
  # @return [Boolean] true if content exceeds max size
  def exceeds_max_input_size?(content)
    # Compare the content length with the adapter's maximum input size
    content.length > adapter.max_input_chars
  end

  # Truncate content to fit within max input size
  # @param content [String] the content to truncate
  # @return [String] the truncated content
  def truncate_content(content)
    # Add a safety margin to ensure we're well under the limit
    safety_margin = 100

    # Calculate the maximum size we can use
    max_size = adapter.max_input_chars - safety_margin

    # Take only the portion of content that will fit
    truncated = content[0...max_size]

    # Add a clear note about truncation at the end
    truncated + "\n\n[CONTENT TRUNCATED DUE TO SIZE LIMITATIONS]"
  end

  # Generate summary for a thread
  # @param content [String] the formatted content
  # @return [String] the generated summary
  def generate_summary(content)
    # Create the system and user prompts for the AI
    system_prompt, user_prompt = create_summary_prompt(content)

    # Log that summary generation is starting
    log_summary_generation_start

    # Generate the summary using the AI adapter
    summary = adapter.complete(system_prompt, user_prompt)

    # Log that summary generation is complete
    log_summary_generation_end(summary)

    # Return the generated summary
    summary
  end

  # Log that summary generation is starting
  def log_summary_generation_start
    # Log message indicating summary generation has begun
    Rails.logger.info("Generating summary for story ##{story['id']}")
  end

  # Log that summary generation is complete
  # @param summary [String] the generated summary
  def log_summary_generation_end(summary)
    # Log message with the completed summary text
    Rails.logger.info("GENERATED SUMMARY for story ##{story['id']}:\n#{summary}")
  end

  # Create prompt for summarization
  # @param content [String] the formatted content
  # @return [Array<String>] An array containing [system_prompt, user_prompt]
  def create_summary_prompt(content)
    # Define the instructions for the task
    instructions = <<~INSTRUCTIONS
      ## Instructions

      Here are some elements to consider including in your summary (if they exist in the content; do not make them up
      if they do not).

      1. Technical Substance:
        - Interesting disagreement/friction points or arguments
        - Key technical explanations or solutions
        - Insightful analogies
        - Technical misconceptions identified

      2. Expert Contributions:
         - Comments from experts with firsthand knowledge or experience

      3. Resources and References:
         - Recommended articles, tools, libraries, papers, or specific resources (**include verbatim URLs if
           referenced**)
         - Relevant context
         - Benchmarks or empirical data

      5. Practical Takeaways:
         - Actionable advice
         - Potential pitfalls or gotchas
         - Trade-offs between approaches
         - Future developments or research areas

      ### Guidelines

      - Write in an informal tone that's appropriate for a blunt, somewhat persnickety software developer audience.
      - Include as many specific URLs that were referenced as possible. Reproduce the URLs **verbatim**; do not truncate
        them in any way (if you do; they won't work!).
      - Cite particularly interesting comments by specific usernames where possible. When referencing usernames, format
        them using backticks, like this: `username`. If you choose to reference specific comments, which is recommended,
        do not reference them by their index (e.g., "1.2.1"), but rather simply use the author's username (e.g, "`mbm`
        thinks that...").
      - If you include URLs in your summary, format them as Markdown links so users can easily click through.

      ### What to avoid doing

      - Avoid pandering or folksy language.
      - Avoid stuffiness or formality.
      - Do not make things up.
      - Do not use foul language.
      - Do not "speak to" developers directly; the summary is *for* them, but not written *to* them.

      ### Summary format

      Return your summary in *valid Markdown*. Do not include a descriptive intro such as "Here is a summary of the
      discussion..."; instead, simply return the summary itself starting with the first Markdown heading, which should
      be a second-level ("##") heading. Don't title your summary a "summary for devs" or speak to developers directly;
      the summary is *for* them, but not written *to* them. Developers will be presented with many of these summaries on
      the same webpage side by side, so speaking to them directly would be redundant and annoying.

      *Remember*: Return only the summary; do not include any preface or post-text.
    INSTRUCTIONS

    # Prepare the full system prompt
    system_prompt = <<~SYSTEM_PROMPT
      # Task

      You are an expert Hacker News (HN) commentator who writes summaries of recent HN comment threads. Your goal is to
      create concise yet surprisingly specific and technically nuanced summaries of provided Hacker News discussion
      threads.

      If the topic is a controversial one, you may choose to make your summary somewhat edgy; but, remain factual and
      unbiased.

      #{instructions}
    SYSTEM_PROMPT

    # Prepare the user message
    user_prompt = <<~USER_PROMPT
      --------------- BEGIN DISCUSSION TEXT TO SUMMARIZE ---------------

      #{content}

      --------------- END DISCUSSION TEXT TO SUMMARIZE ---------------

      #{instructions}
    USER_PROMPT

    # Return both prompts in an array
    [ system_prompt, user_prompt ]
  end
end