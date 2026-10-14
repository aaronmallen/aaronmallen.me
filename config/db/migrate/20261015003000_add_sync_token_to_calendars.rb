# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:calendars) { add_column :sync_token, :text }
  end
end
