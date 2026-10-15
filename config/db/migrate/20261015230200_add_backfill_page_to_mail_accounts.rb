# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:mail_accounts) do
      add_column :backfill_page, :text
      add_column :backfill_held_at, :timestamptz
    end
  end
end
