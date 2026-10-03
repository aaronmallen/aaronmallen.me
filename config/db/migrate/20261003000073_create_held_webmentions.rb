# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :held_webmentions do
      primary_key :id
      foreign_key :post_id, :posts, null: false, on_delete: :cascade
      column :source_url, :non_blank_text, null: false
      column :target_url, :non_blank_text, null: false
      column :held_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :held_webmentions_source_url_check, Sequel.lit("octet_length(source_url) <= 2048")
      constraint :held_webmentions_target_url_check, Sequel.lit("octet_length(target_url) <= 2048")

      index %i[post_id source_url], unique: true
    end
  end

  down do
    drop_table :held_webmentions
  end
end
