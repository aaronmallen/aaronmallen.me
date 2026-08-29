# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :task_types do
      primary_key :id
      column :name, :non_blank_text, null: false
      column :color, :tag_color, null: false
      column :icon, :text
      column :position, :integer, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :task_types_position_check, Sequel.lit('"position" > 0')

      index Sequel.function(:lower, :name), unique: true, name: :task_types_name_key
    end
  end

  down do
    drop_table :task_types
  end
end
