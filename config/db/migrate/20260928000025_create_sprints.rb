# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :sprints do
      primary_key :id
      column :sprint_date, :date, null: false
      column :carried_in, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :sprints_carried_in_check, Sequel.lit("carried_in >= 0")

      index :sprint_date, unique: true
    end
  end
end
