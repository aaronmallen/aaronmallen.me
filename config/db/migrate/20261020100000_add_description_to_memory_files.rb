# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:memory_files) do
      add_column :description, :non_blank_text
      add_column :description_agent, :contributor_slug
      add_column :description_model, :contributor_slug
      add_constraint :memory_files_description_author_check, Sequel.lit(
        "num_nonnulls(description_agent, description_model) IN (0, 2)",
      )
    end
  end

  down do
    alter_table(:memory_files) do
      drop_constraint :memory_files_description_author_check
      drop_column :description_model
      drop_column :description_agent
      drop_column :description
    end
  end
end
