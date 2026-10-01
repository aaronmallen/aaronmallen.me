# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:task_sources) { add_column :checked_at, :timestamptz }
  end

  down do
    alter_table(:task_sources) { drop_column :checked_at }
  end
end
