# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:performance_jobs) do
      add_column :error_class, :non_blank_text
      add_column :error_message, :text
    end
  end
end
