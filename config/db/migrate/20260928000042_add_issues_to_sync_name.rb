# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :sync_name, "issues"
  end

  down do
    run <<~SQL
      DELETE FROM sync_states WHERE sync = 'issues';
      ALTER TYPE sync_name RENAME TO sync_name_with_issues;
      CREATE TYPE sync_name AS ENUM ('analytics_rollup', 'commits', 'country_database', 'projects');
      ALTER TABLE sync_states ALTER COLUMN sync TYPE sync_name USING sync::text::sync_name;
      DROP TYPE sync_name_with_issues;
    SQL
  end
end
