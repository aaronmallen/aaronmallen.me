# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :device_class, %w[desktop mobile tablet in-app]

    alter_table(:analytics_events) { add_column :device_class, :device_class }

    create_table :analytics_rollup_devices do
      primary_key :id
      foreign_key :day, :analytics_rollups, type: :date, null: false, on_delete: :cascade
      column :path, :http_path
      column :device_class, :device_class, null: false
      column :views, :integer, null: false, default: 0
      column :visitors, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(
        :analytics_rollup_devices_counts_check,
        Sequel.lit("views >= 0 AND visitors >= 0 AND visitors <= views"),
      )

      index %i[day path device_class], unique: true, nulls_distinct: false
    end
  end

  down do
    drop_table :analytics_rollup_devices
    alter_table(:analytics_events) { drop_column :device_class }
    drop_enum :device_class
  end
end
