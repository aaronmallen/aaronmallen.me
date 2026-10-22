# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:notes) { add_column :written_by_agent, :boolean, null: false, default: false }
  end
end
