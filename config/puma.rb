# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# You can control the number of workers using ENV["WEB_CONCURRENCY"]. You
# should only set this value when you want to run 2 or more workers. The
# default is already 1.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

# Enable code preloading in cluster mode
# This loads the application code before forking worker processes to reduce memory usage
# through copy-on-write. This is automatically enabled when WEB_CONCURRENCY > 1,
# but we explicitly enable it here for clarity and to ensure it is always enabled
# in cluster mode regardless of how the server is started.
preload_app!

# This hook is called after a worker is forked from the master process in cluster mode.
# It is called once per worker process just after it has been forked.
# This ensures that each worker process has its own set of database connections.
on_worker_boot do
  # If Rails is configured to use a schema cache dump, reload it for the worker
  if Rails.application.config.active_record.use_schema_cache_dump
    # Get the path to the schema cache file
    schema_cache_file = Rails.root.join("db", "schema_cache.yml")

    # If the schema cache file exists,
    if File.exist?(schema_cache_file)
      # Load the cache for this worker's connection pool
      schema_reflection = ActiveRecord::ConnectionAdapters::SchemaReflection.new(schema_cache_file.to_s)
      schema_reflection.load!(ActiveRecord::Base.connection_pool)
    end
  end

  # Keep at least one database connection alive by running a simple query every 90-140
  # seconds
  Thread.new do
    loop do
      begin
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          conn.execute("SELECT 1")
        end
      rescue => e
        Rails.logger.warn "DB keepalive error: #{e.message}"
      end

      # Sleep for 90-140 seconds
      sleep rand(90..140)
    end
  end

  # Ping Redis so we have at least one Redis connection initialized for non-cache operations
  Fast.with { |redis| redis.ping }

  # Set up the cache config
  Fast.setup_cache

  # Create a cache connection
  Rails.cache.write("test-cache", true)
  Rails.cache.delete("test-cache")
end