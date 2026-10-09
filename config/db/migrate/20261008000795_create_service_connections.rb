# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :service_connections do
      primary_key :id
      column :provider, :non_blank_text, null: false
      column :host, :non_blank_text
      column :account_id, :non_blank_text, null: false
      column :label, :non_blank_text, null: false
      column :credentials, :text, null: false
      column :scopes, "text[]", null: false, default: Sequel.lit("'{}'::text[]")
      column :last_used_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index %i[provider host account_id], unique: true, nulls_distinct: false
    end
  end

  down do
    drop_table :service_connections
  end
end
