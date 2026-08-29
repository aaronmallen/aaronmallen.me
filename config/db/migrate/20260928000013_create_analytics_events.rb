# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run <<~SQL
      CREATE DOMAIN country_code AS text CHECK (VALUE ~ '^[A-Z]{2}$');
      CREATE DOMAIN hostname AS text CHECK (VALUE ~ '^[^\\s/]+$');
      CREATE DOMAIN http_path AS text CHECK (VALUE ~ '^/');
      CREATE DOMAIN view_token AS text CHECK (VALUE ~ '^[0-9a-f]{32}$');
    SQL

    create_table :analytics_events do
      primary_key :id
      column :path, :http_path, null: false
      column :title, :text
      column :visitor_hash, :visitor_hash, null: false
      column :address_hash, :visitor_hash, null: false
      column :view_token, :view_token
      column :referrer_host, :hostname
      column :country_code, :country_code
      column :read_seconds, :integer, null: false, default: 0
      column :occurred_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :analytics_events_read_seconds_check, Sequel.lit("read_seconds >= 0")

      index :occurred_at
      index %i[address_hash occurred_at]
      index %i[visitor_hash view_token]
    end
  end

  down do
    drop_table :analytics_events

    run <<~SQL
      DROP DOMAIN view_token;
      DROP DOMAIN http_path;
      DROP DOMAIN hostname;
      DROP DOMAIN country_code;
    SQL
  end
end
