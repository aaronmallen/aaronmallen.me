# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table :commits do
      add_index :created_at
    end
  end
end
