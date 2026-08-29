# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :suggestion_edit_status, %w[pending accepted rejected stale]

    create_table :suggestion_edits do
      primary_key :id
      foreign_key :suggestion_id, :suggestions, null: false, on_delete: :cascade
      column :position, :integer, null: false
      column :part, :integer
      column :original, :non_blank_text, null: false
      column :replacement, :text, null: false
      column :reason, :non_blank_text, null: false
      column :status, :suggestion_edit_status, null: false, default: "pending"
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :suggestion_edits_part_check, Sequel.lit("part IS NULL OR part > 0")
      constraint :suggestion_edits_position_check, Sequel.lit('"position" > 0')

      index %i[suggestion_id position], unique: true
      index %i[suggestion_id status]
    end
  end

  down do
    drop_table :suggestion_edits

    drop_enum :suggestion_edit_status
  end
end
