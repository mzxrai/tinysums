# Defines the base adapter interface for AI providers
# All AI provider adapters must inherit from this class
class Ai::BaseAiAdapter
  # Generate a summary of the provided content
  # @param content [String] the content to summarize
  # @param options [Hash] additional options for the summary generation
  # @return [String] the generated summary
  def generate_summary(content, options = {})
    raise NotImplementedError, "#{self.class.name} must implement #generate_summary"
  end

  # Generate a summary of the provided comments
  # @param comments [Array<Hash>] array of comment hashes to summarize
  # @param options [Hash] additional options for the summary generation
  # @return [String] the generated summary of comments
  def generate_comment_summary(comments, options = {})
    raise NotImplementedError, "#{self.class.name} must implement #generate_comment_summary"
  end
end