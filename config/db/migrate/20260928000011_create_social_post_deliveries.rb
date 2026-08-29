# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :social_post_deliveries do
      primary_key :id
      foreign_key :social_post_id, :social_posts, null: false, on_delete: :cascade
      column :network, :network, null: false
      column :remote_ids, "text[]", null: false, default: Sequel.lit("'{}'")
      column :remote_url, :non_blank_text
      column :error, :text
      column :failed, :boolean, null: false, default: false
      column :like_count, :integer, null: false, default: 0
      column :repost_count, :integer, null: false, default: 0
      column :reply_count, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(
        :social_post_deliveries_counts_check,
        Sequel.lit("like_count >= 0 AND repost_count >= 0 AND reply_count >= 0"),
      )

      index %i[social_post_id network], unique: true
    end
  end
end
