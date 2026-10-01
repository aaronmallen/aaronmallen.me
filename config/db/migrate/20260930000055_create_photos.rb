# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :photos do
      primary_key :id
      column :key, :text, null: false
      column :width, :integer, null: false
      column :height, :integer, null: false
      column :byte_size, :integer, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :photos_key_check, Sequel.lit("key ~ '^[0-9a-f]{32}\\.(gif|jpg|png|webp)$'")
      constraint :photos_size_check, Sequel.lit("width > 0 AND height > 0 AND byte_size > 0")

      index :key, unique: true
      index :created_at
    end
  end

  down do
    drop_table :photos
  end
end
