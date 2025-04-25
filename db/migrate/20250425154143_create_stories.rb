class CreateStories < ActiveRecord::Migration[8.0]
  def change
    create_table :stories, id: :uuid do |t|
      t.integer :hn_id, null: false
      t.string :title
      t.string :url
      t.string :by
      t.integer :score
      t.integer :time
      t.integer :descendants, default: 0
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :stories, :hn_id, unique: true
    add_index :stories, :active
  end
end