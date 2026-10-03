# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :post_follow_up, %w[syndicate_post send_webmentions]

    create_table :held_post_follow_ups do
      primary_key :id
      foreign_key :post_id, :posts, null: false, on_delete: :cascade
      column :follow_up, :post_follow_up, null: false
      column :requested_at, :timestamptz, null: false

      index %i[post_id follow_up], unique: true
    end
  end

  down do
    drop_table :held_post_follow_ups
    drop_enum :post_follow_up
  end
end
