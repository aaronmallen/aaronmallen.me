# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :webmention_receipts do
      primary_key :id
      foreign_key :post_id, :posts, null: false, on_delete: :cascade
      column :source_url, :non_blank_text, null: false
      column :visitor_hash, :visitor_hash, null: false
      column :received_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :webmention_receipts_source_url_check, Sequel.lit("octet_length(source_url) <= 2048")

      index :received_at
      index %i[post_id source_url], unique: true
      index %i[visitor_hash received_at]
    end
  end

  down do
    drop_table :webmention_receipts
  end
end
