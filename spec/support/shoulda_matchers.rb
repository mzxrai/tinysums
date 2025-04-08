# frozen_string_literal: true

# Configure shoulda-matchers to work with RSpec and Rails
# This allows us to use matcher methods like validate_presence_of, allow_value, etc.
# in our model specs

RSpec.configure do |config|
  Shoulda::Matchers.configure do |shoulda_config|
    shoulda_config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
end