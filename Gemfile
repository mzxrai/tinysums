source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"
# Use Redis for fast in-memory storage
gem "redis", "~> 5.4"
# Connection pooler
gem "connection_pool", "~> 2.5" 
# Sidekiq for background jobs
gem "sidekiq", "~> 8.0"
# Sidekiq cron jobs
gem "sidekiq-cron", "~> 2.2"
# Faster JSON parser/serializer
gem "oj", "~> 3.16"
# Common interface to mutiple JSON libraries
gem "multi_json", "~> 1.15"
# Authorization
gem "pundit", "~> 2.5"
# HTTP request handling
gem "faraday", "~> 2.12"
# ActiveStorage validations
gem "active_storage_validations", "~> 2.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder", "~> 2.13"
# Email validator
gem "email_validator", "~> 2.2"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Gems for development and test environments
group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

# Gems for development environment
group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  # Tailwind support
  gem "tailwindcss-ruby", "~> 4.1"
  gem "tailwindcss-rails", "~> 4.2"
end

# Gems for the test environment only
group :test do
    # Testing framework for Rails
  gem "rspec-rails", "~> 7.1"
  
  # Factory Bot for test data
  gem "factory_bot_rails", "~> 6.4"
  
  # Faker for generating realistic test data
  gem "faker", "~> 3.5"

  # Testing helpers
  gem "shoulda-matchers", "~> 6.0"
end