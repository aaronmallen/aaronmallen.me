# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:task_sources) { add_column :history_cursor, :timestamptz }
  end

  down do
    alter_table(:task_sources) { drop_column :history_cursor }
  end
end
