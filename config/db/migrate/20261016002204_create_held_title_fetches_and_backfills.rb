# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :held_title_fetches do
      primary_key :id
      foreign_key :short_link_id, :short_links, null: false, on_delete: :cascade, unique: true
      column :held_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table :held_health_backfills do
      primary_key :id
      column :last_day, :date, null: false, unique: true
      column :held_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
