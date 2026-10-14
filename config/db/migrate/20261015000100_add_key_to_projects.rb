# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run "CREATE DOMAIN project_key AS text CHECK (VALUE ~ '^[A-Z][A-Z0-9]{1,5}$')"

    alter_table(:projects) { add_column :key, :project_key }

    run "CREATE UNIQUE INDEX projects_key_index ON projects (lower(key))"

    run <<~SQL
      CREATE FUNCTION projects_default_key() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
      DECLARE
        base text := coalesce(nullif(left(regexp_replace(upper(NEW.name), '[^A-Z]', '', 'g'), 3), ''), 'PRJ');
        marks text[] := regexp_split_to_array('23456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', '');
      BEGIN
        PERFORM pg_advisory_xact_lock(hashtext('projects_default_key'));

        SELECT candidate INTO NEW.key
          FROM (
            SELECT base AS candidate, 0 AS place
            UNION ALL
            SELECT base || one.mark, one.place FROM unnest(marks) WITH ORDINALITY AS one(mark, place)
            UNION ALL
            SELECT base || one.mark || two.mark, 100 * one.place + two.place
              FROM unnest(marks) WITH ORDINALITY AS one(mark, place),
                unnest(marks) WITH ORDINALITY AS two(mark, place)
          ) candidates
          WHERE length(candidate) >= 2
            AND NOT EXISTS (
              SELECT 1 FROM projects
                WHERE lower(projects.key) = lower(candidate) AND projects.id IS DISTINCT FROM NEW.id
            )
          ORDER BY length(candidate), place
          LIMIT 1;

        RETURN NEW;
      END
      $$;

      CREATE TRIGGER projects_default_key BEFORE INSERT OR UPDATE ON projects
        FOR EACH ROW WHEN (NEW.key IS NULL) EXECUTE FUNCTION projects_default_key();

      DO $$
      DECLARE
        project record;
      BEGIN
        FOR project IN SELECT id FROM projects ORDER BY id LOOP
          UPDATE projects SET key = NULL WHERE id = project.id;
        END LOOP;
      END
      $$;
    SQL

    alter_table(:projects) { set_column_not_null :key }
  end

  down do
    run "DROP TRIGGER projects_default_key ON projects"
    run "DROP FUNCTION projects_default_key()"
    alter_table(:projects) { drop_column :key }
    run "DROP DOMAIN project_key"
  end
end
