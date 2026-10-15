# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :analytics_rollup_hours do
      primary_key :id
      foreign_key :day, :analytics_rollups, type: :date, null: false, on_delete: :cascade
      column :hour, :smallint, null: false
      column :visitors, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :analytics_rollup_hours_hour_check, Sequel.lit("hour BETWEEN 0 AND 23")
      constraint :analytics_rollup_hours_visitors_check, Sequel.lit("visitors >= 0")

      index %i[day hour], unique: true
    end

    run <<~SQL
      CREATE TRIGGER analytics_rollup_hours_notify_admin_change AFTER INSERT OR UPDATE OR DELETE
        ON analytics_rollup_hours FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :analytics_rollup_hours
  end
end
