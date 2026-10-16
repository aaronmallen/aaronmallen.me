# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:calendars) { add_column :synced_from, :date }
  end
end
