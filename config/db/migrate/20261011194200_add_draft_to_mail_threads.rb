# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table :mail_threads do
      add_column :draft, TrueClass, null: false, default: false
    end
  end
end
