# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:webmentions) { add_column :seen_at, :timestamptz }
  end
end
