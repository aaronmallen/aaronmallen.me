# frozen_string_literal: true

ROM::SQL.migration do
  stored = "(projects.status)::text AS status"
  derived = "CASE WHEN (projects.archived_on IS NULL) THEN 'active'::text ELSE 'archived'::text END AS status"

  quote = ->(text) { "'#{text.gsub("'", "''")}'" }
  pattern = ->(text) { quote[Regexp.escape(text).gsub("\\ ", "\\s+")] }

  rebuild_views = Kernel.lambda do |from, to, change|
    <<~SQL
      DO $$
      DECLARE
        activities text := pg_get_viewdef('activities');
        search_documents text := pg_get_viewdef('search_documents');
      BEGIN
        IF activities !~ #{pattern[from]} OR search_documents !~ #{pattern[from]} THEN
          RAISE EXCEPTION 'project status not found in the activities or search_documents view';
        END IF;
        activities := regexp_replace(activities, #{pattern[from]}, #{quote[to]});
        search_documents := regexp_replace(search_documents, #{pattern[from]}, #{quote[to]});
        DROP VIEW activities;
        DROP VIEW search_documents;
        #{change}
        EXECUTE 'CREATE VIEW activities AS ' || activities;
        EXECUTE 'CREATE VIEW search_documents AS ' || search_documents;
      END
      $$;
    SQL
  end

  up do
    run rebuild_views.call(stored, derived, <<~SQL)
      CREATE TYPE project_visibility AS ENUM ('public', 'private');
      UPDATE projects
        SET archived_on = greatest(started_on, (updated_at AT TIME ZONE '#{Blog::TimeZone::NAME}')::date)
        WHERE status = 'archived' AND archived_on IS NULL;
      ALTER TABLE projects ADD COLUMN visibility project_visibility;
      UPDATE projects SET visibility = 'public';
      ALTER TABLE projects ALTER COLUMN visibility SET NOT NULL;
      ALTER TABLE projects DROP CONSTRAINT projects_archived_on_check;
      ALTER TABLE projects DROP COLUMN status, DROP COLUMN featured, DROP COLUMN "position";
      DROP TYPE project_status;
    SQL
  end

  down do
    run rebuild_views.call(derived, stored, <<~SQL)
      CREATE TYPE project_status AS ENUM ('active', 'wip', 'paused', 'archived');
      ALTER TABLE projects
        ADD COLUMN status project_status NOT NULL DEFAULT 'active',
        ADD COLUMN featured boolean NOT NULL DEFAULT false,
        ADD COLUMN "position" integer;
      UPDATE projects SET status = 'archived' WHERE archived_on IS NOT NULL;
      UPDATE projects SET "position" = ordered.position
        FROM (SELECT id, row_number() OVER (ORDER BY id) AS position FROM projects) AS ordered
        WHERE projects.id = ordered.id;
      ALTER TABLE projects
        ALTER COLUMN "position" SET NOT NULL,
        ADD CONSTRAINT projects_archived_on_check CHECK (archived_on IS NULL OR status = 'archived'),
        ADD CONSTRAINT projects_position_check CHECK ("position" > 0);
      CREATE UNIQUE INDEX projects_position_index ON projects ("position");
      CREATE INDEX projects_status_index ON projects (status);
      ALTER TABLE projects DROP COLUMN visibility;
      DROP TYPE project_visibility;
    SQL
  end
end
