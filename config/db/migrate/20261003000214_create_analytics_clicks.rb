# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :analytics_clicks do
      primary_key :id
      foreign_key :event_id, :analytics_events, null: false, on_delete: :cascade
      column :link_host, :hostname, null: false
      column :link_path, :http_path, null: false
      column :occurred_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :event_id
    end

    create_table :analytics_rollup_clicks do
      primary_key :id
      foreign_key :day, :analytics_rollups, type: :date, null: false, on_delete: :cascade
      column :path, :http_path, null: false
      column :link_host, :hostname, null: false
      column :link_path, :http_path, null: false
      column :clicks, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:analytics_rollup_clicks_clicks_check) { clicks >= 0 }

      index %i[day path link_host link_path], unique: true
      index %i[path day]
    end
  end
end
