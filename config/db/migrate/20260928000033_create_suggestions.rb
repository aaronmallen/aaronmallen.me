# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :suggestions do
      primary_key :id
      foreign_key :post_id, :posts, on_delete: :cascade
      foreign_key :social_post_id, :social_posts, on_delete: :cascade
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :suggestions_target_check, Sequel.lit("(post_id IS NULL) <> (social_post_id IS NULL)")

      index :post_id
      index :social_post_id
    end
  end
end
