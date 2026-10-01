# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :post_edits do
      primary_key :id
      foreign_key :post_id, :posts, null: false, on_delete: :cascade
      column :note, :non_blank_text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :post_edits_note_length_check, Sequel.lit("char_length(note) <= 500")

      index %i[post_id created_at]
    end
  end

  down do
    drop_table :post_edits
  end
end
