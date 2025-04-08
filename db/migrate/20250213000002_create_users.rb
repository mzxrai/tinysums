class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :uuid do |t|
      # Basic user information
      t.string :email, null: false
      t.string :name
      t.string :avatar_url

      # Timestamps
      t.timestamps

      # Indexes for performance and uniqueness
      t.index :email, unique: true
    end
  end
end