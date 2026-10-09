# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :sync_name, "pull_requests"
  end

  down do
    run <<~SQL
      DELETE FROM sync_states WHERE sync::text = 'pull_requests';
      ALTER TYPE sync_name RENAME TO sync_name_with_pull_requests;
      CREATE TYPE sync_name AS ENUM (
        'analytics_rollup', 'commits', 'country_database', 'projects', 'issues', 'linear_issues', 'backups'
      );
      ALTER TABLE sync_states ALTER COLUMN sync TYPE sync_name USING sync::text::sync_name;
      DROP TYPE sync_name_with_pull_requests;
    SQL
  end
end
