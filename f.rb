require 'httparty'

HTTParty::Basement.default_options.update(verify: false)

response = HTTParty.get('https://www.nytimes.com/2025/04/17/technology/google-ad-tech-antitrust-ruling.html', {
  http_proxyaddr: "proxy-server.scraperapi.com",
  http_proxyport: "8001",
  http_proxyuser: "scraperapi.render=true.screenshot=true,premium=true",
  http_proxypass: "e5270b8130459c7c10ab7ca29ebeb867"
})

results = response.body
puts results
