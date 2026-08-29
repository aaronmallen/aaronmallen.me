# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :social_post_parts do
      primary_key :id
      foreign_key :social_post_id, :social_posts, null: false, on_delete: :cascade
      column :position, :integer, null: false
      column :body, :non_blank_text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :social_post_parts_position_check, Sequel.lit('"position" > 0')

      index %i[social_post_id position], unique: true
    end
  end
end
