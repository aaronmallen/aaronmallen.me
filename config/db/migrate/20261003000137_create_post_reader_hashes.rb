# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :post_reader_hashes do
      column :path, :http_path, null: false
      column :reader_hash, :visitor_hash, null: false

      primary_key %i[path reader_hash]
    end
  end
end
