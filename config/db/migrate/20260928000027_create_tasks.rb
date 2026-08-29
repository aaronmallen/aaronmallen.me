# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :task_list, %w[next someday]
    create_enum :task_status, %w[open in_progress done]

    create_table :tasks do
      primary_key :id
      column :title, :non_blank_text, null: false
      column :note, :text, null: false, default: ""
      column :list, :task_list
      foreign_key :sprint_id, :sprints, on_delete: :restrict
      foreign_key :task_type_id, :task_types, on_delete: :restrict
      column :status, :task_status, null: false, default: "open"
      column :position, :integer, null: false
      column :carried_count, :integer, null: false, default: 0
      column :completed_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :tasks_carried_count_check, Sequel.lit("carried_count >= 0")
      constraint :tasks_completed_at_check, Sequel.lit("(status = 'done') = (completed_at IS NOT NULL)")
      constraint :tasks_list_or_sprint_check, Sequel.lit("num_nonnulls(list, sprint_id) = 1")
      constraint :tasks_position_check, Sequel.lit('"position" > 0')

      index :completed_at
      index :status
      index :task_type_id
      index %i[list position]
      index %i[sprint_id position]
    end
  end

  down do
    drop_table :tasks

    drop_enum :task_status
    drop_enum :task_list
  end
end
