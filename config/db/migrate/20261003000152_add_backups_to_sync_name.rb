# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :sync_name, "backups"
  end

  down do
    run <<~SQL
      DELETE FROM sync_states WHERE sync::text = 'backups';
      ALTER TYPE sync_name RENAME TO sync_name_with_backups;
      CREATE TYPE sync_name AS ENUM (
        'analytics_rollup', 'commits', 'country_database', 'projects', 'issues', 'linear_issues'
      );
      ALTER TABLE sync_states ALTER COLUMN sync TYPE sync_name USING sync::text::sync_name;
      DROP TYPE sync_name_with_backups;
    SQL
  end
end
