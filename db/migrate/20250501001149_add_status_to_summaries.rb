class AddStatusToSummaries < ActiveRecord::Migration[8.0]
  def change
    # Add status column to story_summaries table
    # - Type: string
    # - Default value: 'pending'
    # - Indexed: true
    add_column :story_summaries, :status, :string, default: 'pending'
    add_index :story_summaries, :status

    # Add status column to comments_summaries table
    # - Type: string
    # - Default value: 'pending'
    # - Indexed: true
    add_column :comments_summaries, :status, :string, default: 'pending'
    add_index :comments_summaries, :status
  end
end
