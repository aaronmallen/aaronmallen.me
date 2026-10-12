# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:service_connections) { add_column :work, :boolean, null: false, default: false }
  end
end
