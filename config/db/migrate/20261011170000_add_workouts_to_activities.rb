# frozen_string_literal: true

ROM::SQL.migration do
  zone = Blog::TimeZone::NAME
  workouts = <<~SQL
    UNION ALL
    SELECT
      'workout',
      workouts.id,
      (workouts.started_at AT TIME ZONE '#{zone}')::date,
      (workouts.started_at AT TIME ZONE '#{zone}')::time,
      initcap(replace(workouts.kind, '_', ' ')),
      NULL,
      NULL,
      NULL,
      NULL,
      NULL,
      NULL,
      NULL,
      workouts.device,
      NULL,
      NULL,
      workouts.minutes * 60,
      NULL
    FROM workouts
  SQL

  up do
    run <<~SQL
      DO $$
      BEGIN
        EXECUTE 'CREATE OR REPLACE VIEW activities AS ' || rtrim(pg_get_viewdef('activities'), ';') || $branches$
          #{workouts}
        $branches$;
      END
      $$;
    SQL
  end

  down do
    run <<~SQL
      DO $$
      DECLARE
        activities text := pg_get_viewdef('activities');
        pattern text := '\\s*UNION ALL\\s+SELECT\\s+''workout''.*$';
      BEGIN
        IF activities !~ pattern THEN
          RAISE EXCEPTION 'workout branch not found in the activities view';
        END IF;
        EXECUTE 'CREATE OR REPLACE VIEW activities AS ' || regexp_replace(activities, pattern, '');
      END
      $$;
    SQL
  end
end
