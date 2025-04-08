# Perform production environment-only setup / configuration
if Rails.env.production?
  # Write the primary DB SSL key to a file
  # ssl_key_file = Rails.root.join("db/tls/primary/db_primary_ssl_key.pem")
  # File.write(ssl_key_file, Base64.strict_decode64(ENV.fetch("DB_PRIMARY_SSL_KEY")))
  # FileUtils.chmod(0600, ssl_key_file)
end