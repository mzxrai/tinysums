class AddRankToStories < ActiveRecord::Migration[8.0]
  def change
    add_column :stories, :rank, :integer
  end
end
