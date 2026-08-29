# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :webmention_type, %w[reply like repost mention]
    create_enum :webmention_status, %w[pending approved spam]

    author_domain = Sequel.function(
      :lower,
      Sequel.function(:substring, :author_url, "^[^:]+://(?:[^@/]*@)?([^/:?#]+)"),
    )

    create_table :webmentions do
      primary_key :id
      foreign_key :post_id, :posts, null: false, on_delete: :cascade
      column :source_url, :non_blank_text, null: false
      column :author_name, :text
      column :author_url, :text
      column :author_domain, :text, generated_always_as: author_domain
      column :type, :webmention_type, null: false
      column :status, :webmention_status, null: false, default: "pending"
      column :excerpt, :text
      column :received_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :webmentions_source_url_check, Sequel.lit("octet_length(source_url) <= 2048")

      index %i[post_id source_url], unique: true
      index :author_url
      index :received_at
      index :status
    end
  end

  down do
    drop_table :webmentions

    drop_enum :webmention_status
    drop_enum :webmention_type
  end
end
