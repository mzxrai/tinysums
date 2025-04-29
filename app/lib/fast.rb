# frozen_string_literal: true

# Fast Module
# Provides on-demand initialization of Redis connections and cache configuration
module Fast
  # Default Redis URL for non-production environments
  DEFAULT_REDIS_URL = "redis://localhost:6379/1"

  # Namespace for our cache keys
  CACHE_NAMESPACE = "api_cache"

  class << self
    # Returns a Redis connection pool for general Redis operations
    # @return [ConnectionPool] A connection pool containing Redis clients
    def connection_pool
      @connection_pool ||= ConnectionPool.new(size: thread_pool_size) do
        create_redis_client
      end
    end

    # Executes a block with a Redis connection from the pool
    # @param block [Proc] The block to execute with a Redis connection
    # @return [Object] The result of the block execution
    # @example
    #   Fast.with { |redis| redis.get("key") }
    def with(&block)
      connection_pool.with(&block)
    end

    # Configures and initializes the Rails cache with Redis
    # @return [ActiveSupport::Cache::RedisCacheStore] The initialized cache store
    def setup_cache
      # # Configure the cache store based on environment
      # Rails.application.config.cache_store = :redis_cache_store, cache_config

      # # Initialize the cache with our configuration
      # Rails.cache = ActiveSupport::Cache.lookup_store(Rails.application.config.cache_store)
    end

    private

    # Creates the appropriate Redis client based on environment
    # @return [Redis] A Redis client instance
    def create_redis_client
      Redis.new(redis_config)
    end

    # Returns the Redis configuration based on environment
    # @return [Hash] Configuration hash for Redis client
    def redis_config
      @redis_config ||= if Rails.env.production?
        {
          # Use the Redis URL in production
          url: ENV.fetch("REDIS_URL"),
          read_timeout: 0.2,    # Time to wait for a read operation
          write_timeout: 0.2,   # Time to wait for a write operation
          connect_timeout: 0.5, # Time to establish a connection
          reconnect_attempts: 2 # Number of times to attempt to reconnect
        }
      else
        {
          url: ENV.fetch("REDIS_URL", DEFAULT_REDIS_URL)
        }
      end
    end

    # Returns the configuration for the Redis cache store
    # @return [Hash] Configuration hash for Redis cache store
    def cache_config
      if Rails.env.production?
        {
          url: ENV.fetch("REDIS_CACHE_URL"),
          expires_in: 30.days, # Cache items expire after 30 days by default
          namespace: CACHE_NAMESPACE
        }
      else
        {
          url: ENV.fetch("REDIS_URL", DEFAULT_REDIS_URL),
          namespace: CACHE_NAMESPACE
        }
      end
    end

    # Calculates the appropriate thread pool size
    # @return [Integer] The number of connections to maintain in the pool
    def thread_pool_size
      ENV.fetch("RAILS_MAX_THREADS", 5).to_i + 2
    end
  end
end

# Usage Examples:
#
# 1. For general Redis operations:
#    ```ruby
#    Fast.with { |redis| redis.get("user:{123}:profile") }
#    Fast.with { |redis| redis.set("counter", 1) }
#    Fast.with { |redis| redis.incr("visits") }
#    ```