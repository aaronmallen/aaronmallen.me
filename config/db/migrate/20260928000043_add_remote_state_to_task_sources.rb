# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :task_source_state, %w[open completed not_planned unassigned moved deleted]

    alter_table :task_sources do
      add_column :remote_state, :task_source_state, null: false, default: "open"
    end
  end

  down do
    alter_table :task_sources do
      drop_column :remote_state
    end

    drop_enum :task_source_state
  end
end
