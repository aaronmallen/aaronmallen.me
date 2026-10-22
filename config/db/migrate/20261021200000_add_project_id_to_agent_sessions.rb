# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table :agent_sessions do
      add_foreign_key :project_id, :projects, on_delete: :set_null
      add_index :project_id
    end

    from(:agent_sessions).update(
      project_id: from(:projects).where(repo: Sequel[:agent_sessions][:repo]).select(:id),
    )
  end

  down do
    alter_table(:agent_sessions) { drop_foreign_key :project_id }
  end
end
