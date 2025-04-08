class CreateUserAuthentications < ActiveRecord::Migration[8.0]
  def change
    create_table :user_authentications, id: :uuid do |t|
      # References
      t.references :user, null: false, foreign_key: true, index: true, type: :uuid

      # Provider information
      t.string :provider, null: false
      t.string :uid, null: false
      t.jsonb :auth_data, null: false, default: {}

      # Timestamps
      t.timestamps

      # Ensure unique provider/uid combinations
      t.index [ :provider, :uid ], unique: true
    end
  end
end