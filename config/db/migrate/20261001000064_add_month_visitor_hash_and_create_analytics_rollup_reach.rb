# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:analytics_events) { add_column :month_visitor_hash, :visitor_hash }

    create_table :analytics_rollup_reach do
      primary_key :id
      column :month, :date, null: false
      column :path, :http_path
      column :reach, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :analytics_rollup_reach_month_check, Sequel.lit("extract(day FROM month) = 1")
      constraint :analytics_rollup_reach_reach_check, Sequel.lit("reach >= 0")

      index %i[month path], unique: true, nulls_distinct: false
    end
  end
end
