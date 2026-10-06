# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:posts) do
      add_column :unsent_webmention_targets, "text[]", null: false, default: Sequel.lit("'{}'")
    end
  end
end
