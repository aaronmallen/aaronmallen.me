# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :code_challenge_method, %w[S256]

    create_table :oauth_codes do
      primary_key :id
      foreign_key :oauth_client_id, :oauth_clients, null: false, on_delete: :cascade
      column :code_digest, :text, null: false
      column :redirect_uri, :text, null: false
      column :code_challenge, :text, null: false
      column :code_challenge_method, :code_challenge_method, null: false, default: "S256"
      column :resource, :text
      column :scopes, "text[]", null: false, default: Sequel.lit("'{read}'::text[]")
      column :expires_at, :timestamptz, null: false
      column :used_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :code_digest, unique: true
      index :expires_at
      index :oauth_client_id
    end
  end

  down do
    drop_table :oauth_codes

    drop_enum :code_challenge_method
  end
end
