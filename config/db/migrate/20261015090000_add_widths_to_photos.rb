# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:photos) do
      add_column :widths, "integer[]", null: false, default: Sequel.lit("'{}'::integer[]")
    end
  end
end
