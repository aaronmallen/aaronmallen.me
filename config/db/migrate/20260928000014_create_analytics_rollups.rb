# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :analytics_rollups do
      column :day, :date, null: false
      column :views, :integer, null: false, default: 0
      column :visitors, :integer, null: false, default: 0
      column :read_seconds, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      primary_key [:day]

      constraint(
        :analytics_rollups_counts_check,
        Sequel.lit("views >= 0 AND visitors >= 0 AND read_seconds >= 0 AND visitors <= views"),
      )
    end
  end
end
