# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :webmention_settings do
      column :id, :integer, primary_key: true, default: 1
      column :receive, :boolean, null: false, default: true
      column :send_on_publish, :boolean, null: false, default: true
      column :auto_approve_known_authors, :boolean, null: false, default: true
      column :enable_on_new_posts, :boolean, null: false, default: true
      column :accept_bridgy, :boolean, null: false, default: true
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :webmention_settings_singleton_check, Sequel.lit("id = 1")
    end
  end
end
