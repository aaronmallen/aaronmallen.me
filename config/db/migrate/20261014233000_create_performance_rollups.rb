# frozen_string_literal: true

ROM::SQL.migration do
  up do
    queried = "count > 0 AND 0 <= p50 AND p50 <= p95 AND query_count >= 0 AND query_time >= 0"

    create_enum :performance_page_metric, %w[ttfb dom_content_loaded load lcp]

    create_table :performance_rollups do
      column :day, :date, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      primary_key [:day]
    end

    create_table :performance_rollup_requests do
      primary_key :id
      foreign_key :day, :performance_rollups, key: :day, type: :date, null: false, on_delete: :cascade
      column :route, :http_path
      column :verb, :text, null: false
      column :count, :integer, null: false
      column :p50, :double, null: false
      column :p95, :double, null: false
      column :query_count, :bigint, null: false
      column :query_time, :double, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :performance_rollup_requests_figures_check, Sequel.lit(queried)

      index %i[day verb route], unique: true, nulls_distinct: false
    end

    create_table :performance_rollup_jobs do
      primary_key :id
      foreign_key :day, :performance_rollups, key: :day, type: :date, null: false, on_delete: :cascade
      column :job, :text, null: false
      column :count, :integer, null: false
      column :p50, :double, null: false
      column :p95, :double, null: false
      column :query_count, :bigint, null: false
      column :query_time, :double, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :performance_rollup_jobs_figures_check, Sequel.lit(queried)

      index %i[day job], unique: true
    end

    create_table :performance_rollup_pages do
      primary_key :id
      foreign_key :day, :performance_rollups, key: :day, type: :date, null: false, on_delete: :cascade
      column :route, :http_path, null: false
      column :metric, :performance_page_metric, null: false
      column :count, :integer, null: false
      column :p50, :double, null: false
      column :p95, :double, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :performance_rollup_pages_figures_check, Sequel.lit("count > 0 AND 0 <= p50 AND p50 <= p95")

      index %i[day route metric], unique: true
    end
  end

  down do
    drop_table :performance_rollup_pages, :performance_rollup_jobs, :performance_rollup_requests, :performance_rollups
    drop_enum :performance_page_metric
  end
end
