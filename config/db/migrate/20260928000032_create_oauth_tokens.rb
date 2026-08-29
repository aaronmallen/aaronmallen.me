# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :oauth_token_type, %w[access refresh]

    create_table :oauth_tokens do
      primary_key :id
      foreign_key :oauth_client_id, :oauth_clients, null: false, on_delete: :cascade
      column :type, :oauth_token_type, null: false
      column :token_digest, :text, null: false
      column :resource, :text
      column :scopes, "text[]", null: false, default: Sequel.lit("'{read}'::text[]")
      column :expires_at, :timestamptz, null: false
      column :revoked_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :expires_at
      index :oauth_client_id
      index :token_digest, unique: true
    end
  end

  down do
    drop_table :oauth_tokens

    drop_enum :oauth_token_type
  end
end
