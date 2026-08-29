# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :journal_entries do
      primary_key :id
      column :entry_date, :date, null: false
      column :entry_time, :time, null: false
      column :body, :non_blank_text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :entry_date
    end
  end
end
