# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :short_link_checks do
      primary_key :id
      foreign_key :short_link_id, :short_links, null: false, unique: true, on_delete: :cascade
      column :url, :text, null: false
      column :failures, :integer, null: false, default: 0
      column :reason, :text
      column :checked_at, :timestamptz, null: false
      column :first_failed_at, :timestamptz
    end
  end
end
