# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :task_comments do
      primary_key :id
      foreign_key :task_id, :tasks, null: false, on_delete: :cascade
      column :body, :non_blank_text, null: false
      column :provider, :task_source_provider
      column :remote_id, :text
      column :url, :text
      column :author, :text
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :task_comments_remote_check, Sequel.lit("num_nonnulls(provider, remote_id, url) IN (0, 3)")

      index :task_id
      index %i[provider remote_id], unique: true
    end
  end

  down do
    drop_table :task_comments
  end
end
