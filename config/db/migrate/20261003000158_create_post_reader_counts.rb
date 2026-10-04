# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :post_reader_counts do
      column :path, :http_path, primary_key: true
      column :readers, Integer, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:post_reader_counts_readers_check) { readers >= 0 }
    end
  end
end
