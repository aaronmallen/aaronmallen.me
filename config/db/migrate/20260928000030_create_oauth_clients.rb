# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :oauth_clients do
      primary_key :id
      column :client_id, :non_blank_text, null: false
      column :client_name, :text
      column :client_uri, :text
      column :logo_uri, :text
      column :redirect_uris, "text[]", null: false
      column :grant_types, "text[]", null: false
      column :response_types, "text[]", null: false
      column :token_endpoint_auth_method, :text, null: false, default: "none"
      column :visitor_hash, :visitor_hash, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :revoked_at, :timestamptz
      column :last_used_at, :timestamptz

      constraint :oauth_clients_redirect_uris_check, Sequel.lit("cardinality(redirect_uris) > 0")

      index :client_id, unique: true
      index %i[visitor_hash created_at]
    end
  end
end
