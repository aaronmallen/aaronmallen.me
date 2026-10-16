# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:tags) { add_column :description, :text }
  end
end
