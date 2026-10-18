# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table :share_group_files do
      add_column :preview_key, :text, unique: true
      add_constraint :share_group_files_preview_key_check, Sequel.lit("preview_key ~ '^[0-9a-f]{32}$'")
    end
  end
end
