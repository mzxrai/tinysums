json.array! @stories do |story|
  # Basic story information
  json.id story["id"]
  json.title story["title"]
  json.by story["by"]
  json.score story["score"]
  json.time story["time"]
  json.url story["url"]
  json.descendants story["descendants"] || 0
  json.type story["type"]

  # Add mock summaries to the first 5 stories for demonstration
  # In a real implementation, these would come from AI processing
  if @stories.index(story) < 5
    json.contentSummary "This article discusses #{story["title"].downcase} with a focus on technical implementation details and practical applications. The author provides a comprehensive overview of current methodologies and highlights potential areas for future development. Key points include performance considerations, compatibility with existing systems, and best practices for implementation."
    json.commentSummary "The discussion primarily focuses on alternative approaches and real-world experiences. Several commenters shared their own implementations, with most agreeing on core principles but diverging on specific technical choices. Key debates centered around scalability concerns, with several expert contributors offering insights from production deployments. Overall, the community response was constructive with multiple useful code examples shared."
  else
    json.contentSummary nil
    json.commentSummary nil
  end
end