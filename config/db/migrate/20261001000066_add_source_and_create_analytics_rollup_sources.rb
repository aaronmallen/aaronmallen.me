# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run "CREATE DOMAIN ref_source AS text CHECK (VALUE ~ '^[a-z0-9]+([._-][a-z0-9]+)*$' AND length(VALUE) <= 32)"

    alter_table(:analytics_events) { add_column :source, :ref_source }

    create_table :analytics_rollup_sources do
      primary_key :id
      foreign_key :day, :analytics_rollups, type: :date, null: false, on_delete: :cascade
      column :path, :http_path
      column :source, :ref_source, null: false
      column :views, :integer, null: false, default: 0
      column :visitors, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(
        :analytics_rollup_sources_counts_check,
        Sequel.lit("views >= 0 AND visitors >= 0 AND visitors <= views"),
      )

      index %i[day path source], unique: true, nulls_distinct: false
    end
  end

  down do
    drop_table :analytics_rollup_sources
    alter_table(:analytics_events) { drop_column :source }
    run "DROP DOMAIN ref_source"
  end
end
