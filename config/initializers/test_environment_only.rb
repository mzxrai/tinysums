# frozen_string_literal: true

# This initializer contains all test environment configurations in one place
# to minimize the number of initializers and improve application boot time.
# It only runs in the test environment and won't impact development or production.
#
# Consolidating test-specific configurations here reduces initialization overhead
# in non-test environments and keeps test setup organized.

if Rails.env.test?
  # Shoulda-matchers configuration for concise model validation testing
  Rails.application.config.after_initialize do
    Shoulda::Matchers.configure do |config|
      config.integrate do |with|
        with.test_framework :rspec
        with.library :rails
      end
    end
  end
end
