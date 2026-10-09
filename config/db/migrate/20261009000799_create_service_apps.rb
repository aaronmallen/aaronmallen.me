# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :service_apps do
      primary_key :id
      column :provider, :non_blank_text, null: false
      column :host, :non_blank_text, null: false
      column :redirect_uri, :non_blank_text, null: false
      column :scopes, "text[]", null: false, default: Sequel.lit("'{}'::text[]")
      column :credentials, :text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index %i[provider host], unique: true
    end
  end

  down do
    drop_table :service_apps
  end
end
