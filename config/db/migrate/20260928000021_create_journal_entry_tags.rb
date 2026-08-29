# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :journal_entry_tags do
      foreign_key :journal_entry_id, :journal_entries, null: false, on_delete: :cascade
      foreign_key :tag_id, :tags, null: false, on_delete: :restrict

      primary_key %i[journal_entry_id tag_id]

      index :tag_id
    end
  end
end
