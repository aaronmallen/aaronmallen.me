# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :post_tags do
      foreign_key :post_id, :posts, null: false, on_delete: :cascade
      foreign_key :tag_id, :tags, null: false, on_delete: :restrict

      primary_key %i[post_id tag_id]

      index :tag_id
    end
  end
end
