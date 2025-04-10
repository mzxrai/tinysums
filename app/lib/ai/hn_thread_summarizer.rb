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
    comment_format: "Comment by %{username} (karma: %{karma})\n%{text}\n\n",

    # Enable caching of summaries
    cache_summaries: true
  }.freeze

  # Initialize the thread summarizer
  # @param adapter [Ai::BaseAiAdapter] the AI adapter to use for summarization
  # @param hn_client [HnApiClient] client for interacting with HN API
  # @param options [Hash] options to override defaults
  def initialize(adapter, hn_client = nil, options = {})
    # Save the AI adapter for making summarization requests
    @adapter = adapter
    # Create or use provided HN API client
    @hn_client = hn_client || HnApiClient.new
    # Merge default options with provided options
    @options = DEFAULT_OPTIONS.merge(options)
    # Initialize cache for summaries
    @summary_cache = {}
  end

  # Generate a comprehensive summary of a HN story's comments
  # @param story_id [Integer] the HN story ID to summarize
  # @param options [Hash] additional options to override instance defaults
  # @return [String] the generated summary or nil if story not found
  def generate_thread_summary(story_id, options = {})
    # Merge instance options with method-specific options
    opts = @options.merge(options)

    # Fetch the story with all its comments
    story = fetch_story_with_comments(story_id)
    return nil unless story

    # Add author karma to comments for scoring
    enrich_comments_with_karma(story)

    # Score and select top-level comments for summarization
    selected_comments = select_comments_for_summarization(story, opts)

    # Format selected comments for the AI
    formatted_content = format_comments_for_summarization(story, selected_comments)

    # Truncate content if it exceeds max input size
    if exceeds_max_input_size?(formatted_content)
      # Apply truncation to ensure we stay within model's input limits
      formatted_content = truncate_content(formatted_content)
    end

    # Generate the summary from the (potentially truncated) content
    generate_summary(story, formatted_content, opts)
  end

  private

  # Generate a hash for content to use as cache key
  # @param content [String] the content to hash
  # @return [String] the SHA-256 hash string of the content
  def generate_content_hash(content)
    # Create a SHA-256 hash of the content for caching purposes
    Digest::SHA256.hexdigest(content)
  end

  # Check if a summary exists in cache for given content
  # @param content_hash [String] the hash of the content
  # @return [String, nil] the cached summary or nil if not found
  def get_cached_summary(content_hash)
    # Look up the summary in our cache using the hash
    @summary_cache[content_hash]
  end

  # Store a summary in the cache
  # @param content_hash [String] the hash of the content
  # @param summary [String] the summary to cache
  def cache_summary(content_hash, summary)
    # Store the summary in our cache using the hash as key
    @summary_cache[content_hash] = summary
  end

  # Fetch a story with its complete comment tree
  # @param story_id [Integer] the HN story ID to fetch
  # @return [Hash, nil] the story with its comment tree or nil if not found
  def fetch_story_with_comments(story_id)
    # Log the start of fetching
    Rails.logger.info("HN API CALL: Fetching story ##{story_id} with comments")

    # Use our HN client to get the story with all comments
    story = @hn_client.get_story_with_comments(story_id)

    # Log completion of the API call
    comment_count = story ? story["descendants"] || 0 : 0
    Rails.logger.info("HN API CALL COMPLETE: Fetched story ##{story_id} with #{comment_count} comments")

    # Return the story with its comment tree
    story
  end

  # Add karma information to comments to aid in selection/scoring
  # @param story [Hash] the story with its comment tree
  def enrich_comments_with_karma(story)
    # Process each top-level comment
    story["comments"].each do |comment|
      # Add author karma to this comment
      add_karma_to_comment(comment)

      # Process replies recursively to add karma to all comments
      process_replies_with_karma(comment)
    end
  end

  # Add karma information to a single comment
  # @param comment [Hash] the comment to enrich
  def add_karma_to_comment(comment)
    # Skip if no author (deleted comment)
    return if comment["by"].nil?

    # Log the start of fetching user info
    Rails.logger.info("HN API CALL: Fetching user #{comment["by"]} for karma lookup")

    # Get user info using our client
    user = @hn_client.get_user(comment["by"])

    # Log completion of the API call
    user_karma = user ? user["karma"] || 0 : 0
    Rails.logger.info("HN API CALL COMPLETE: Fetched user #{comment["by"]} with karma #{user_karma}")

    # Add karma to comment (default to 0 if user not found)
    comment["author_karma"] = user_karma
  end

  # Process replies recursively to add karma
  # @param comment [Hash] the parent comment with replies
  def process_replies_with_karma(comment)
    # Process each reply
    comment["replies"].each do |reply|
      # Add karma to this reply
      add_karma_to_comment(reply)

      # Process nested replies recursively
      process_replies_with_karma(reply)
    end
  end

  # Select top-level comments for summarization based on scoring
  # @param story [Hash] the story with its comment tree
  # @param options [Hash] selection options
  # @return [Array<Hash>] selected comments for summarization
  def select_comments_for_summarization(story, options)
    # Count total comments in the story
    total_comments = story["descendants"] || 0

    # Determine percentage of comments to include based on thread size
    percentage = determine_selection_percentage(total_comments, options)

    # Calculate how many top-level comments to select
    top_level_count = story["comments"].size

    # Take the ceiling of the percentage calculation to ensure we include at least one comment
    # But don't exceed the actual number of top-level comments
    selection_count = [ (top_level_count * percentage / 100.0).ceil, top_level_count ].min

    # Score each top-level comment
    scored_comments = score_comments(story["comments"], options)

    # Sort by score (descending) and take the top selection_count comments
    selected_comments = scored_comments.sort_by { |c| -c[:score] }.first(selection_count)

    # Return just the comment data, not the scoring info
    selected_comments.map { |c| c[:comment] }
  end

  # Determine what percentage of comments to include based on thread size
  # @param total_comments [Integer] total number of comments in thread
  # @param options [Hash] selection options
  # @return [Float] percentage of comments to include
  def determine_selection_percentage(total_comments, options)
    # For small threads, include all comments (or the specified percentage)
    if total_comments < options[:small_thread_threshold]
      options[:small_thread_percentage]

    # For medium threads, include the medium thread percentage
    elsif total_comments < options[:medium_thread_threshold]
      options[:medium_thread_percentage]

    # For large threads, include the large thread percentage
    elsif total_comments < options[:large_thread_threshold]
      options[:large_thread_percentage]

    # For very large threads, include the very large thread percentage
    elsif total_comments < options[:very_large_threshold]
      options[:very_large_thread_percentage]

    # For massive threads, calculate percentage to include at least the minimum number
    # But cap at very_large_thread_percentage to avoid including too many
    else
      [
        (options[:massive_thread_minimum].to_f / total_comments * 100),
        options[:very_large_thread_percentage]
      ].min
    end
  end

  # Score comments based on descendants, karma, and content
  # @param comments [Array<Hash>] comments to score
  # @param options [Hash] scoring options and weights
  # @return [Array<Hash>] comments with scores
  def score_comments(comments, options)
    # Create array to hold comments with their scores
    scored_comments = []

    # Score each comment
    comments.each do |comment|
      # Skip deleted comments as they have no meaningful content
      next if comment["deleted"]

      # Calculate component scores
      descendant_score = calculate_descendant_score(comment)
      karma_score = calculate_karma_score(comment)
      content_score = calculate_content_score(comment)

      # Calculate weighted total score using the specified weights from options
      total_score = (
        descendant_score * options[:descendant_weight] +
        karma_score * options[:karma_weight] +
        content_score * options[:content_weight]
      )

      # Add to scored comments array with both the comment and its score
      scored_comments << {
        comment: comment,
        score: total_score
      }
    end

    # Return the array of comments with their scores
    scored_comments
  end

  # Calculate score based on number of descendants (replies)
  # @param comment [Hash] comment to score
  # @return [Float] normalized score between 0-1
  def calculate_descendant_score(comment)
    # Count descendants by counting all replies
    descendant_count = count_descendants(comment)

    # Normalize with logarithmic scale to avoid overly weighting huge threads
    # A comment with 0 replies gets 0, one with many gets close to 1
    # log(1 + count) / log(1000) will give scores between 0-1 with diminishing returns
    Math.log(1 + descendant_count) / Math.log(1000)
  end

  # Count total descendants (replies) of a comment
  # @param comment [Hash] the comment to count descendants for
  # @return [Integer] total number of descendants
  def count_descendants(comment)
    # Start with 0 for this comment
    count = 0

    # Add counts for all immediate replies
    if comment["replies"] && !comment["replies"].empty?
      # Iterate through each immediate reply
      comment["replies"].each do |reply|
        # Count the reply itself
        count += 1

        # Count its descendants recursively
        count += count_descendants(reply)
      end
    end

    # Return the total count of descendants
    count
  end

  # Calculate score based on author's karma
  # @param comment [Hash] comment to score
  # @return [Float] normalized score between 0-1
  def calculate_karma_score(comment)
    # Get karma (default to 0)
    karma = comment["author_karma"] || 0

    # Handle the case of negative karma values
    # (some users on HN can have negative karma)
    karma = [ karma, 0 ].max

    # Normalize with logarithmic scale
    # log(1 + karma) / log(100000) will give scores between 0-1
    # This gives diminishing returns for extremely high karma
    Math.log(1 + karma) / Math.log(100000)
  end

  # Calculate score based on content characteristics
  # @param comment [Hash] comment to score
  # @return [Float] score between 0-1
  def calculate_content_score(comment)
    # Get the comment text
    text = comment["text"] || ""

    # Initial score starts at 0
    score = 0.0

    # Longer comments often have more substance (up to +0.3 max)
    score += [ text.length / 2000.0, 0.3 ].min

    # Comments with links often provide valuable resources (+0.3)
    score += 0.3 if text.include?("<a href=")

    # Comments with code blocks often provide examples (+0.4)
    score += 0.4 if text.include?("<code>") || text.include?("<pre>")

    # Ensure score is between 0-1
    [ score, 1.0 ].min
  end

  # Format selected comments for AI summarization
  # @param story [Hash] the story being summarized
  # @param selected_comments [Array<Hash>] selected comments
  # @return [String] formatted text for the AI
  def format_comments_for_summarization(story, selected_comments)
    # Build the header with story info
    header = "# Hacker News Discussion: #{story['title']}\n\n"

    # Add URL if available
    header += "URL: #{story['url']}\n" if story["url"]

    # Add poster information
    header += "Posted by: #{story['by']}\n"

    # Add comment statistics
    header += "Total comments: #{story['descendants'] || 0}\n"
    header += "Comments processed: #{selected_comments.size}\n\n"

    # Format each comment and its replies, with incrementing indices
    comments_text = selected_comments.map.with_index do |comment, index|
      format_comment_with_replies(comment, "#{index + 1}", 0)
    end.join("\n")

    # Combine header and comments
    header + comments_text
  end

  # Format a comment and its replies recursively
  # @param comment [Hash] the comment to format
  # @param index [String] the hierarchical index (e.g., "1", "1.2", etc.)
  # @param depth [Integer] the nesting depth of the comment
  # @return [String] formatted comment text
  def format_comment_with_replies(comment, index, depth)
    # Skip deleted comments
    return "" if comment["deleted"]

    # Maximum depth is 5 levels (0-4, where 0 is top-level)
    max_depth = 4

    # Generate heading level based on depth (## for depth 0, ### for depth 1, etc.)
    # Use 2 + depth (minimum heading level is 2) but cap at 6 (markdown only supports h1-h6)
    heading_level = "#" * [ 2 + depth, 6 ].min

    # Format the comment itself using the template from options
    formatted_text = @options[:comment_format] % {
      username: comment["by"] || "[deleted]",
      karma: comment["author_karma"] || 0,
      text: comment["text"] || ""
    }

    # Create a clear heading that includes the hierarchical index
    # Format: "## [1] Comment by username (depth 0)"
    comment_text = "#{heading_level} [#{index}] (depth #{depth})\n#{formatted_text}"

    # Format replies if any and if we haven't reached max depth
    if comment["replies"] && !comment["replies"].empty? && depth < max_depth
      # Sort replies by score (same algorithm as top-level)
      scored_replies = score_comments(comment["replies"], @options)
      sorted_replies = scored_replies.sort_by { |r| -r[:score] }

      # Format each reply with its own index
      replies_text = sorted_replies.map.with_index do |scored_reply, i|
        reply = scored_reply[:comment]
        format_comment_with_replies(reply, "#{index}.#{i + 1}", depth + 1)
      end.join("\n")

      # Combine comment and its replies
      comment_text + "\n" + replies_text
    else
      # Just return the comment text if no replies or max depth reached
      if comment["replies"] && !comment["replies"].empty? && depth >= max_depth
        # Add a note that deeper replies exist but were truncated
        depth_limit_note = "\n[DEPTH LIMIT REACHED: #{comment["replies"].size} additional replies not shown]"
        comment_text + depth_limit_note
      else
        # No replies or empty replies
        comment_text
      end
    end
  end

  # Check if content exceeds max input size
  # @param content [String] the content to check
  # @return [Boolean] true if content exceeds max size
  def exceeds_max_input_size?(content)
    # Compare content length to the adapter's max input size
    # Returns true if content is too large for the model
    content.length > @adapter.max_input_chars
  end

  # Truncate content to fit within max input size
  # @param content [String] the content to truncate
  # @return [String] the truncated content
  def truncate_content(content)
    # Define safety margin to stay well under the limit
    safety_margin = 100

    # Calculate maximum size we can use
    max_size = @adapter.max_input_chars - safety_margin

    # Simply take the first portion of the content that will fit
    truncated = content[0...max_size]

    # Add truncation message at the end
    truncated + "\n\n[CONTENT TRUNCATED DUE TO SIZE LIMITATIONS]"
  end

  # Generate summary for a thread
  # @param story [Hash] the story being summarized
  # @param content [String] the formatted content
  # @param options [Hash] summarization options
  # @return [String] the generated summary
  def generate_summary(story, content, options)
    # Generate a hash for the content for cache lookup
    content_hash = generate_content_hash(content)

    # Check if caching is enabled and if there's a cached summary
    if options[:cache_summaries] && (cached_summary = get_cached_summary(content_hash))
      # Log that we're using a cached summary
      Rails.logger.info("Using CACHED SUMMARY for story ##{story['id']}")

      # Return the cached summary
      return cached_summary
    end

    # Create prompt for the AI
    prompt = create_summary_prompt(story, content)

    # Generate summary using the AI adapter
    Rails.logger.info("Generating summary for story ##{story['id']}")

    # Call the adapter to generate the summary
    summary = @adapter.generate_summary(prompt, options)

    # Log the generated summary
    Rails.logger.info("GENERATED SUMMARY for story ##{story['id']}:\n#{summary}")

    # Store in cache if caching is enabled
    cache_summary(content_hash, summary) if options[:cache_summaries]

    # Return the generated summary
    summary
  end

  # Create prompt for summarization
  # @param story [Hash] the story being summarized
  # @param content [String] the formatted content
  # @return [String] the complete prompt
  def create_summary_prompt(story, content)
    # Define the instruction section
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

      - Include as many specific URLs that were referenced as possible. Reproduce the URLs **verbatim**; do not truncate
        them in any way (if you do; they won't work!).
      - Cite particularly interesting comments by specific usernames where possible. When referencing usernames, format
        them using backticks, like this: `username`. If you choose to reference specific comments, which is recommended,
        do not reference them by their index (e.g., "1.2.1"), but rather simply use the author's username (e.g, "`mbm`
        suggested that...").
      - Do not use foul language or be overtly opinionated when generating your summary.
      - Write in a conversational tone.
      - Your primary goals are to be insightful and highly readable. Maximize engagement with the reader and provide
        fast value.

      ### What to avoid doing

      - Avoid pandering or folksy language.
      - Avoid stuffiness or formality.
      - Do not make things up.

      ### Summary format

      Return your summary in *well-formatted, valid Markdown*. Do not include a descriptive intro such as
      "Here is a summary of the discussion..."; instead, simply return the summary itself. Immediately produce value
      for the reader.

      ### Summary audience & style

      The summary is for a technical, developer-focused audience, so write in a blunt, straightforward style that will
      appeal to that audience. Think less "stodgy newscaster" and more "engaging Twitter post by brilliant dev".
    INSTRUCTIONS

    # Construct the full prompt with instructions and content
    a = <<~PROMPT
      # Task

      You are an expert Hacker News commentator.

      In a software developer-targeted conversational tone, create a concise yet surprisingly detailed and technically
      nuanced summary of this Hacker News discussion (comment) thread. If the topic is a controversial one, you may
      choose to make your summary somewhat edgy; but, remain factual and unbiased.

      #{instructions}

      ----------------------------------------------------------------------------------------------------------------

      BEGIN DISCUSSION TEXT TO SUMMARIZE:

      #{content}

      END DISCUSSION TEXT

      ----------------------------------------------------------------------------------------------------------------

      #{instructions}

      **Remember: Return only the summary; do not include any preface or post-text.**
    PROMPT

    # Log the prompt (for debugging)
    puts a

    # Return the complete prompt
    a
  end
end