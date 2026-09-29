# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :task_source_provider, "linear"
  end

  down do
    run <<~SQL
      DELETE FROM task_sources WHERE provider = 'linear';
      ALTER TYPE task_source_provider RENAME TO task_source_provider_with_linear;
      CREATE TYPE task_source_provider AS ENUM ('github');
      ALTER TABLE task_sources ALTER COLUMN provider TYPE task_source_provider USING provider::text::task_source_provider;
      DROP TYPE task_source_provider_with_linear;
    SQL
  end
end
