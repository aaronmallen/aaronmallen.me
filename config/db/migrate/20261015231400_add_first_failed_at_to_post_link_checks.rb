# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:post_link_checks) do
      add_column :first_failed_at, :timestamptz
    end
  end
end
