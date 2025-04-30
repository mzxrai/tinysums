# frozen_string_literal: true

# Cache Setup Initializer
#
# This initializer ensures the Redis cache is properly set up in environments
# where Puma is not running with multiple workers (WEB_CONCURRENCY not set).
#
# In multi-worker Puma configurations, the cache is set up in the on_worker_boot hook
# in config/puma.rb to ensure each worker gets its own connection.
#
# In single-process mode or other environments, we set up the cache here.

# Require the Fast module
require_relative "../../app/lib/fast"

# Set up the cache if we're running in non-Puma cluster mode (in cluster mode, the
# cache is set up in the on_worker_boot hook in config/puma.rb)
unless ENV["WEB_CONCURRENCY"].present? || ENV["BUILD_MODE"].present?
  Fast.setup_cache
end