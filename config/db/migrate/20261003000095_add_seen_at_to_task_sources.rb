# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:task_sources) { add_column :seen_at, :timestamptz }
    from(:task_sources).update(seen_at: Sequel::CURRENT_TIMESTAMP)
  end

  down do
    alter_table(:task_sources) { drop_column :seen_at }
  end
end
