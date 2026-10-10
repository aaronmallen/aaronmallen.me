# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :post_link_checks do
      primary_key :id
      foreign_key :post_id, :posts, null: false, on_delete: :cascade
      column :url, :text, null: false
      column :failures, :integer, null: false, default: 0
      column :reason, :text
      column :checked_at, :timestamptz, null: false

      index %i[post_id url], unique: true
    end
  end
end
