# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :people do
      primary_key :id
      column :key, :text, null: false
      column :name, :non_blank_text, null: false
      column :mastodon_handle, :text
      column :bluesky_handle, :text
      column :bluesky_did, :text
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :people_key_check, Sequel.lit("key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'")
      constraint :people_handles_check, Sequel.lit("num_nonnulls(mastodon_handle, bluesky_handle) > 0")
      constraint :people_mastodon_handle_check, Sequel.lit("mastodon_handle ~ '^@[^@\\s]+@[^@\\s]+$'")
      constraint :people_bluesky_did_check, Sequel.lit("(bluesky_handle IS NULL) = (bluesky_did IS NULL)")

      index :key, unique: true
    end
  end

  down do
    drop_table :people
  end
end
