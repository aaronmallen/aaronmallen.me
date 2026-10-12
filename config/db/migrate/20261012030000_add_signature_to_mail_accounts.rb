# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table :mail_accounts do
      add_column :signature, String, text: true
    end
  end
end
