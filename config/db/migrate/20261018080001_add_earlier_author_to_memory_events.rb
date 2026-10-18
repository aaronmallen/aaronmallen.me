# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:memory_events) do
      add_column :was_agent, :contributor_slug
      add_column :was_model, :contributor_slug

      add_constraint :memory_events_was_author_check, Sequel.lit(<<~SQL)
        num_nonnulls(was_agent, was_model) IN (0, 2) AND (was_agent IS NULL OR was_text IS NOT NULL)
      SQL
    end
  end

  down do
    alter_table(:memory_events) do
      drop_constraint :memory_events_was_author_check
      drop_column :was_model
      drop_column :was_agent
    end
  end
end
