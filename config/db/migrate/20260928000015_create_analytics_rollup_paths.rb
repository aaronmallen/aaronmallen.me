# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :analytics_rollup_paths do
      primary_key :id
      foreign_key :day, :analytics_rollups, type: :date, null: false, on_delete: :cascade
      column :path, :http_path, null: false
      column :title, :text
      column :views, :integer, null: false, default: 0
      column :visitors, :integer, null: false, default: 0
      column :read_seconds, :integer, null: false, default: 0
      column :bounces, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :analytics_rollup_paths_bounces_check, Sequel.lit("bounces >= 0 AND bounces <= visitors")
      constraint(
        :analytics_rollup_paths_counts_check,
        Sequel.lit("views >= 0 AND visitors >= 0 AND read_seconds >= 0 AND visitors <= views"),
      )

      index %i[day path], unique: true
    end
  end
end
