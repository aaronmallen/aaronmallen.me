# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :work_entries do
      primary_key :id
      column :org, :non_blank_text, null: false
      column :role, :non_blank_text, null: false
      column :blurb, :text
      column :from_year, :integer, null: false
      column :to_year, :integer
      column :position, :integer, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :work_entries_from_year_check, Sequel.lit("from_year > 0")
      constraint :work_entries_position_check, Sequel.lit('"position" > 0')
      constraint :work_entries_to_year_check, Sequel.lit("to_year IS NULL OR to_year >= from_year")

      index :position
    end
  end
end
