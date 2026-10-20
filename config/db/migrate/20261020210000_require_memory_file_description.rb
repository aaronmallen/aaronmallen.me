# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:memory_files) { set_column_not_null :description }
  end

  down do
    alter_table(:memory_files) { set_column_allow_null :description }
  end
end
