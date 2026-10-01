# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run "CREATE DOMAIN scroll_depth AS smallint CHECK (VALUE IN (0, 25, 50, 75, 100))"

    alter_table(:analytics_events) do
      add_column :scroll_depth, :scroll_depth
      set_column_default :scroll_depth, 0
    end

    create_table :analytics_rollup_scroll_depths do
      primary_key :id
      foreign_key :day, :analytics_rollups, type: :date, null: false, on_delete: :cascade
      column :path, :http_path, null: false
      column :scroll_depth, :scroll_depth, null: false
      column :views, :integer, null: false, default: 0
      column :visitors, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(
        :analytics_rollup_scroll_depths_counts_check,
        Sequel.lit("views >= 0 AND visitors >= 0 AND visitors <= views"),
      )

      index %i[day path scroll_depth], unique: true
    end
  end

  down do
    drop_table :analytics_rollup_scroll_depths
    alter_table(:analytics_events) { drop_column :scroll_depth }
    run "DROP DOMAIN scroll_depth"
  end
end
