# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:calendar_events) { add_column :recurring_id, :text }
  end
end
