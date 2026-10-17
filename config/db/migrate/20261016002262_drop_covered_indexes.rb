# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:commits) { drop_index :commit_date }
    alter_table(:journal_entries) { drop_index :entry_date }
    alter_table(:mail_threads) { drop_index :mail_account_id }
  end

  down do
    alter_table(:commits) { add_index :commit_date }
    alter_table(:journal_entries) { add_index :entry_date }
    alter_table(:mail_threads) { add_index :mail_account_id }
  end
end
