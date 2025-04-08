# frozen_string_literal: true

# This initializer configures ActiveRecord to use UUIDs as the default primary key type for all tables.
# We're using PostgreSQL's pgcrypto extension for UUID generation (already enabled in a migration).
#
# With this configuration, new migrations can simply use `create_table :table_name do |t|`
# without explicitly specifying `id: :uuid` each time. The UUID type will be used automatically.
#
# For associations, you'll need to explicitly set the foreign key type to UUID:
# `t.references :other_table, type: :uuid, foreign_key: true`
#
# This applies to newly created tables only. Existing tables keep their current primary key type.

Rails.application.config.generators do |g|
  # Configure the ORM to use UUID as the default primary key type
  g.orm :active_record, primary_key_type: :uuid
end

# Configure the default primary key type for all tables created by migrations
ActiveRecord::Migration.class_eval do
  def create_table(table_name, **options)
    options[:id] = :uuid unless options.key?(:id)
    super
  end
end