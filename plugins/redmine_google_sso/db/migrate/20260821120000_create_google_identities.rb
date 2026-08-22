class CreateGoogleIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :google_identities do |t|
      t.integer  :user_id, null: false
      t.string   :subject, null: false
      t.string   :email
      t.datetime :created_on
      t.datetime :last_login_on
    end
    add_index :google_identities, :subject, unique: true
    add_index :google_identities, :user_id
  end
end
