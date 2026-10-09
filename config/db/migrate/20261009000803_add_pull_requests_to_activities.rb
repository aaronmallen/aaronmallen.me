# frozen_string_literal: true

ROM::SQL.migration do
  zone = Blog::TimeZone::NAME
  ended = "coalesce(pull_requests.merged_at, pull_requests.closed_at)"
  branch = Kernel.lambda do |type, at|
    <<~SQL
      SELECT
        #{type},
        pull_requests.id,
        (#{at} AT TIME ZONE '#{zone}')::date,
        (#{at} AT TIME ZONE '#{zone}')::time,
        pull_requests.title,
        pull_requests.url,
        pull_requests.repo,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
      FROM pull_requests
      WHERE pull_requests.ready_at IS NOT NULL
    SQL
  end
  outcome = "CASE WHEN pull_requests.merged_at IS NULL THEN 'pull_request_closed' ELSE 'pull_request_merged' END"
  pull_requests = <<~SQL
    UNION ALL
    #{branch.call("'pull_request_opened'", 'pull_requests.ready_at')}
    UNION ALL
    #{branch.call(outcome, ended)}
      AND #{ended} IS NOT NULL
  SQL

  up do
    run <<~SQL
      DO $$
      BEGIN
        EXECUTE 'CREATE OR REPLACE VIEW activities AS ' || rtrim(pg_get_viewdef('activities'), ';') || $branches$
          #{pull_requests}
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
        pattern text := '\\s*UNION ALL\\s+SELECT\\s+''pull_request_opened''.*$';
      BEGIN
        IF activities !~ pattern THEN
          RAISE EXCEPTION 'pull request branches not found in the activities view';
        END IF;
        EXECUTE 'CREATE OR REPLACE VIEW activities AS ' || regexp_replace(activities, pattern, '');
      END
      $$;
    SQL
  end
end
