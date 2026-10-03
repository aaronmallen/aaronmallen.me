# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :saved_view_screen, %w[activity journal posts tasks]

    create_table :saved_views do
      primary_key :id
      column :name, :non_blank_text, null: false
      column :screen, :saved_view_screen, null: false
      column :filters, :jsonb, null: false, default: Sequel.lit("'{}'::jsonb")
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :saved_views_name_length_check, Sequel.lit("char_length(name) <= 100")
      constraint :saved_views_filters_check, Sequel.lit("jsonb_typeof(filters) = 'object'")

      index %i[screen name]
    end
  end

  down do
    drop_table :saved_views
    drop_enum :saved_view_screen
  end
end
