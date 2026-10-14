# frozen_string_literal: true

ROM::SQL.migration do
  matched = <<~SQL
    WITH origins AS (
      SELECT DISTINCT task_id, provider, lower(
        CASE provider
          WHEN 'github' THEN substring(url FROM '^https://github\\.com/([^/]+/[^/]+)/issues/[0-9]+$')
          WHEN 'linear' THEN array_to_string(
            regexp_match(url, '^https://linear\\.app/([^/]+)/issue/([^/]+)-[0-9]+(?:/|$)'), '/'
          )
        END
      ) AS repo
      FROM task_sources
    ),
    matched AS (
      SELECT origins.task_id, origins.provider, origins.repo, task_rules.id AS task_rule_id
      FROM origins
      JOIN task_rules ON task_rules.provider = origins.provider AND CASE split_part(task_rules.pattern, '/', 2)
        WHEN '*' THEN starts_with(origins.repo, split_part(task_rules.pattern, '/', 1) || '/')
        ELSE origins.repo = task_rules.pattern
      END
    )
  SQL

  up do
    run <<~SQL
      #{matched}
      UPDATE tasks SET project_id = chosen.project_id
      FROM (
        SELECT DISTINCT ON (task_id) task_id, project_id
        FROM (
          SELECT origins.task_id, projects.id AS project_id, 0 AS rank, projects.id AS tiebreak
          FROM origins
          JOIN projects ON origins.provider = 'github' AND projects.repo = origins.repo
          UNION ALL
          SELECT matched.task_id, task_rule_projects.project_id, 1, matched.task_rule_id
          FROM matched
          JOIN task_rule_projects USING (task_rule_id)
        ) candidates
        ORDER BY task_id, rank, tiebreak
      ) chosen
      WHERE tasks.id = chosen.task_id AND tasks.project_id IS NULL
    SQL

    run <<~SQL
      #{matched}
      INSERT INTO task_tags (task_id, tag_id, tag_scope)
      SELECT DISTINCT matched.task_id, task_rule_tags.tag_id, task_rule_tags.tag_scope
      FROM matched
      JOIN task_rule_tags USING (task_rule_id)
      ON CONFLICT DO NOTHING
    SQL
  end
end
