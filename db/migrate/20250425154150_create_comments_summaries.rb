class CreateCommentsSummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :comments_summaries, id: :uuid do |t|
      t.references :story, null: false, foreign_key: true, type: :uuid
      t.text :content

      t.timestamps
    end
  end
end