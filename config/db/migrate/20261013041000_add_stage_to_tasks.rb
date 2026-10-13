# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :task_stage, %w[backlog ready]

    alter_table :tasks do
      add_column :stage, :task_stage, null: false, default: "backlog"
    end
  end

  down do
    alter_table :tasks do
      drop_column :stage
    end

    drop_enum :task_stage
  end
end
