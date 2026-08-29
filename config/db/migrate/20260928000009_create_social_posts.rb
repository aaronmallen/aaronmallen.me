# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :social_post_status, %w[draft scheduled posted]

    create_table :social_posts do
      primary_key :id
      foreign_key :post_id, :posts, on_delete: :set_null
      column :targets, "network[]", null: false
      column :status, :social_post_status, null: false, default: "draft"
      column :posted_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :social_posts_posted_at_check, Sequel.lit("status = 'draft' OR posted_at IS NOT NULL")
      constraint :social_posts_targets_check, Sequel.lit("cardinality(targets) > 0")

      index :post_id
      index :posted_at
      index :status
    end
  end

  down do
    drop_table :social_posts

    drop_enum :social_post_status
  end
end
