# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :task_event_kind, %w[moved tagged untagged status_changed]

    create_table :task_events do
      primary_key :id
      foreign_key :task_id, :tasks, null: false, on_delete: :cascade
      column :kind, :task_event_kind, null: false
      column :occurred_at, :timestamptz, null: false
      column :from_list, :task_list
      column :to_list, :task_list
      column :from_sprint_on, :date
      column :to_sprint_on, :date
      column :tag_name, :tag_name
      column :from_status, :task_status
      column :to_status, :task_status
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :task_events_kind_check, Sequel.lit(<<~SQL)
        CASE kind
          WHEN 'moved' THEN
            num_nonnulls(from_list, from_sprint_on) = 1
            AND num_nonnulls(to_list, to_sprint_on) = 1
            AND (from_list, from_sprint_on) IS DISTINCT FROM (to_list, to_sprint_on)
            AND num_nonnulls(tag_name, from_status, to_status) = 0
          WHEN 'status_changed' THEN
            from_status IS NOT NULL
            AND to_status IS NOT NULL
            AND from_status <> to_status
            AND num_nonnulls(from_list, to_list, from_sprint_on, to_sprint_on, tag_name) = 0
          ELSE
            tag_name IS NOT NULL
            AND num_nonnulls(from_list, to_list, from_sprint_on, to_sprint_on, from_status, to_status) = 0
        END
      SQL

      index %i[task_id occurred_at]
    end
  end

  down do
    drop_table :task_events
    drop_enum :task_event_kind
  end
end
