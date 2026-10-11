# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :sync_name, "health"
  end

  down do
    run <<~SQL
      DELETE FROM sync_states WHERE sync::text = 'health';
      ALTER TYPE sync_name RENAME TO sync_name_with_health;
      CREATE TYPE sync_name AS ENUM (
        'analytics_rollup', 'commits', 'country_database', 'projects', 'issues', 'linear_issues', 'backups',
        'pull_requests'
      );
      ALTER TABLE sync_states ALTER COLUMN sync TYPE sync_name USING sync::text::sync_name;
      DROP TYPE sync_name_with_health;
    SQL
  end
end
