class EnablePgcryptoExtension < ActiveRecord::Migration[8.0]
  def up
    execute 'CREATE EXTENSION IF NOT EXISTS "pgcrypto"'
  end

  def down
    execute 'DROP EXTENSION IF EXISTS "pgcrypto"'
  end
end