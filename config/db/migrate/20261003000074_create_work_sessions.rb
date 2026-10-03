# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:tasks) do
      add_column :worked_seconds, Integer, null: false, default: 0
      add_constraint :tasks_worked_seconds_check, Sequel.lit("worked_seconds >= 0")
    end

    create_table :work_sessions do
      primary_key :id
      foreign_key :task_id, :tasks, null: false, on_delete: :cascade
      column :started_at, :timestamptz, null: false
      column :ended_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :work_sessions_order_check, Sequel.lit("ended_at >= started_at")

      index %i[task_id started_at]
      index :task_id, unique: true, where: Sequel.lit("ended_at IS NULL"), name: :work_sessions_one_open_index
    end
  end

  down do
    drop_table :work_sessions
    alter_table(:tasks) { drop_column :worked_seconds }
  end
end
