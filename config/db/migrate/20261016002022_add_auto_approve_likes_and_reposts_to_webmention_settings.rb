# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:webmention_settings) do
      add_column :auto_approve_likes, :boolean, null: false, default: true
      add_column :auto_approve_reposts, :boolean, null: false, default: true
    end
  end
end
