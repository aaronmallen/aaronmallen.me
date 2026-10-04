# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:webmention_settings) do
      add_column :single_author_hosts, "text[]", null: false, default: Sequel.lit("'{}'::text[]")
    end
  end

  down do
    alter_table(:webmention_settings) { drop_column :single_author_hosts }
  end
end
