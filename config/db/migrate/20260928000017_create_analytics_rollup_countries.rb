# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :analytics_rollup_countries do
      primary_key :id
      foreign_key :day, :analytics_rollups, type: :date, null: false, on_delete: :cascade
      column :country_code, :country_code
      column :views, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :analytics_rollup_countries_views_check, Sequel.lit("views >= 0")

      index %i[day country_code], unique: true, nulls_distinct: false
    end
  end
end
