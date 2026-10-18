# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table :tasks do
      add_foreign_key :series_id, :task_series, on_delete: :set_null
      add_index :series_id
    end

    run "UPDATE tasks SET series_id = task_series.id FROM task_series WHERE task_series.task_id = tasks.id;"
  end

  down do
    alter_table(:tasks) { drop_foreign_key :series_id }
  end
end
