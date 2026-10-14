# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:pull_requests) { add_column :opened_at, :timestamptz }
    run "UPDATE pull_requests SET opened_at = least(ready_at, created_at)"
    alter_table(:pull_requests) { set_column_not_null :opened_at }
  end

  down do
    alter_table(:pull_requests) { drop_column :opened_at }
  end
end
