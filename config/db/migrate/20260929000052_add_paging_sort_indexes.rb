# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:messages) { add_index %i[received_at id] }
    alter_table(:journal_entries) { add_index %i[entry_date entry_time id] }
    alter_table(:commits) { add_index %i[commit_date commit_time id] }

    alter_table(:tasks) do
      add_index [Sequel.function(:coalesce, :completed_at, :created_at), :id], name: :tasks_newest_first_index
    end
  end
end
