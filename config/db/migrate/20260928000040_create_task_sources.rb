# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :task_source_provider, %w[github]

    create_table :task_sources do
      primary_key :id
      foreign_key :task_id, :tasks, null: false, on_delete: :cascade
      column :provider, :task_source_provider, null: false
      column :remote_id, :text, null: false
      column :url, :text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :task_id, unique: true
      index %i[provider remote_id], unique: true
    end
  end

  down do
    drop_table :task_sources

    drop_enum :task_source_provider
  end
end
