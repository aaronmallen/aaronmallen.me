# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:mail_accounts) do
      add_column :settings_synced_at, "timestamp with time zone"
    end
  end
end
