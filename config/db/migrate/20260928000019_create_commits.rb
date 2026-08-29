# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :commits do
      primary_key :id
      column :sha, :text, null: false, unique: true
      column :repo, :text, null: false
      column :branch, :text, null: false
      column :message, :text, null: false
      column :commit_date, :date, null: false
      column :commit_time, :time, null: false
      column :additions, :integer, null: false, default: 0
      column :deletions, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :commits_additions_check, Sequel.lit("additions >= 0")
      constraint :commits_deletions_check, Sequel.lit("deletions >= 0")

      index :commit_date
    end
  end
end
