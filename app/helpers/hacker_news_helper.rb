require "uri"

module HackerNewsHelper
  # Extracts the hostname from a URL string, removing www. prefix.
  # Handles common cases and potential errors.
  #
  # @param url_string [String, nil] The URL string to parse.
  # @return [String, nil] The extracted hostname or nil if parsing fails or no host exists.
  def extract_hostname(url_string)
    # Return nil if the input URL is blank
    return nil if url_string.blank?

    begin
      # Parse the URL string
      uri = URI.parse(url_string)
      # Handle cases like internal Hacker News links (e.g., "item?id=...") which might lack a host
      # If host is nil and the path starts with "item?", assume it's a news.ycombinator.com link
      # Otherwise, return the host, removing the "www." prefix if it exists
      hostname = uri.host || (uri.path&.start_with?("item?") ? "news.ycombinator.com" : nil)
      # Return the hostname after removing potential "www." prefix
      hostname&.gsub(/^www\./, "")
    rescue URI::InvalidURIError
      # Return nil if the URL string is invalid and cannot be parsed
      nil
    end
  end
end