# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table :memory_events do
      add_index :created_at
      add_index :reverted_event_id
    end

    alter_table(:artifact_versions) { add_index :created_at }
  end
end
