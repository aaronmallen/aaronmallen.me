# frozen_string_literal: true

ROM::SQL.migration do
  credits = <<~SQL.strip
    coalesce(
      (
        SELECT jsonb_agg(
          jsonb_strip_nulls(
            jsonb_build_object(
              'kind', task_contributors.kind,
              'agent', task_contributors.agent,
              'model', task_contributors.model
            )
          )
          ORDER BY task_contributors.id
        )
        FROM task_contributors
        WHERE task_contributors.task_id = tasks.id
      ),
      '[{"kind": "owner"}]'::jsonb
    )
  SQL

  review_tasks = Kernel.lambda do |credited|
    zone = Blog::TimeZone::NAME
    credit = ->(column) { credited ? ",\n        #{column}" : "" }

    <<~SQL
      SELECT
        tasks.id AS task_id,
        tasks.title::text AS title,
        tasks.status::text AS status,
        (tasks.completed_at AT TIME ZONE '#{zone}')::date AS closed_on,
        tasks.worked_seconds AS worked_seconds#{credit["#{credits} AS contributors"]}
      FROM tasks
    SQL
  end

  activities = Kernel.lambda do |credited|
    zone = Blog::TimeZone::NAME
    credit = ->(column) { credited ? ",\n        #{column}" : "" }
    sessions = <<~SQL
      UNION ALL
      SELECT
        'session',
        work_sessions.id,
        (work_sessions.started_at AT TIME ZONE '#{zone}')::date,
        (work_sessions.started_at AT TIME ZONE '#{zone}')::time,
        tasks.title,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        work_sessions.task_id,
        NULL,
        floor(extract(epoch FROM work_sessions.ended_at - work_sessions.started_at))::integer#{credit['NULL']}
      FROM work_sessions
      JOIN tasks ON tasks.id = work_sessions.task_id
      WHERE work_sessions.ended_at IS NOT NULL
    SQL

    decisions = <<~SQL
      UNION ALL
      SELECT
        'decision',
        decision_events.id,
        (decision_events.created_at AT TIME ZONE '#{zone}')::date,
        (decision_events.created_at AT TIME ZONE '#{zone}')::time,
        decisions.title::text,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        decision_events.kind::text,
        NULL,
        coalesce(decision_events.reason, decision_events.note, decision_options.title)::text,
        NULL,
        decision_events.decision_id,
        NULL#{credit['NULL']}
      FROM decision_events
      JOIN decisions ON decisions.id = decision_events.decision_id
      LEFT JOIN decision_options ON decision_options.id = decision_events.option_id
      UNION ALL
      SELECT
        'decision_comment',
        decision_comments.id,
        (decision_comments.created_at AT TIME ZONE '#{zone}')::date,
        (decision_comments.created_at AT TIME ZONE '#{zone}')::time,
        decision_comments.body::text,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        decisions.title::text,
        NULL,
        decision_comments.decision_id,
        NULL#{credit['NULL']}
      FROM decision_comments
      JOIN decisions ON decisions.id = decision_comments.decision_id
    SQL

    <<~SQL
      SELECT
        'commit'::text AS type,
        commits.id AS source_id,
        commits.commit_date AS occurred_on,
        commits.commit_time AS occurred_at,
        commits.message AS name,
        NULL::text AS link,
        commits.repo AS repo,
        commits.sha AS sha,
        commits.additions AS additions,
        commits.deletions AS deletions,
        NULL::text AS status,
        NULL::network[] AS targets,
        NULL::text AS excerpt,
        NULL::integer AS task_id,
        NULL::integer AS decision_id,
        NULL::integer AS worked_seconds#{credit['NULL::jsonb AS contributors']}
      FROM commits
      UNION ALL
      SELECT
        'post',
        posts.id,
        (posts.published_at AT TIME ZONE '#{zone}')::date,
        (posts.published_at AT TIME ZONE '#{zone}')::time,
        posts.title,
        '/writing/' || posts.slug,
        NULL,
        NULL,
        NULL,
        NULL,
        posts.status::text,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL#{credit['NULL']}
      FROM posts
      WHERE posts.status = 'published'
      UNION ALL
      SELECT
        'journal',
        journal_entries.id,
        journal_entries.entry_date,
        journal_entries.entry_time,
        journal_entries.body,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL#{credit['NULL']}
      FROM journal_entries
      UNION ALL
      SELECT
        'social',
        social_posts.id,
        (social_posts.posted_at AT TIME ZONE '#{zone}')::date,
        (social_posts.posted_at AT TIME ZONE '#{zone}')::time,
        coalesce(first_part.body, ''),
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        social_posts.status::text,
        social_posts.targets,
        NULL,
        NULL,
        NULL,
        NULL#{credit['NULL']}
      FROM social_posts
      LEFT JOIN LATERAL (
        SELECT social_post_parts.body
        FROM social_post_parts
        WHERE social_post_parts.social_post_id = social_posts.id
        ORDER BY social_post_parts.position
        LIMIT 1
      ) AS first_part ON true
      WHERE social_posts.status = 'posted'
      UNION ALL
      SELECT
        'webmention',
        webmentions.id,
        (webmentions.received_at AT TIME ZONE '#{zone}')::date,
        (webmentions.received_at AT TIME ZONE '#{zone}')::time,
        coalesce(webmentions.author_name, webmentions.author_domain, webmentions.source_url),
        '/writing/' || posts.slug,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        webmentions.excerpt,
        NULL,
        NULL,
        NULL#{credit['NULL']}
      FROM webmentions
      JOIN posts ON posts.id = webmentions.post_id
      WHERE webmentions.status = 'approved'
      UNION ALL
      SELECT
        'task',
        tasks.id,
        (tasks.completed_at AT TIME ZONE '#{zone}')::date,
        (tasks.completed_at AT TIME ZONE '#{zone}')::time,
        tasks.title,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        tasks.id,
        NULL,
        NULL#{credit[credits]}
      FROM tasks
      WHERE tasks.status = 'done'
      UNION ALL
      SELECT
        'project',
        projects.id,
        (projects.created_at AT TIME ZONE '#{zone}')::date,
        (projects.created_at AT TIME ZONE '#{zone}')::time,
        projects.name,
        projects.url,
        projects.repo,
        NULL,
        NULL,
        NULL,
        projects.status::text,
        NULL,
        projects.tagline,
        NULL,
        NULL,
        NULL#{credit['NULL']}
      FROM projects
      UNION ALL
      SELECT
        'sprint',
        sprints.id,
        sprints.sprint_date,
        '00:00'::time,
        sprints.sprint_date::text,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL#{credit['NULL']}
      FROM sprints
      UNION ALL
      SELECT
        'suggestion',
        suggestions.id,
        (suggestions.created_at AT TIME ZONE '#{zone}')::date,
        (suggestions.created_at AT TIME ZONE '#{zone}')::time,
        coalesce(posts.title, first_part.body, ''),
        '/writing/' || posts.slug,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL#{credit['NULL']}
      FROM suggestions
      LEFT JOIN posts ON posts.id = suggestions.post_id
      LEFT JOIN LATERAL (
        SELECT social_post_parts.body
        FROM social_post_parts
        WHERE social_post_parts.social_post_id = suggestions.social_post_id
        ORDER BY social_post_parts.position
        LIMIT 1
      ) AS first_part ON true
      UNION ALL
      SELECT
        'comment',
        task_comments.id,
        (task_comments.created_at AT TIME ZONE '#{zone}')::date,
        (task_comments.created_at AT TIME ZONE '#{zone}')::time,
        task_comments.body::text,
        task_comments.url,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        tasks.title,
        task_comments.task_id,
        NULL,
        NULL#{credit['NULL']}
      FROM task_comments
      JOIN tasks ON tasks.id = task_comments.task_id
      #{decisions}
      #{sessions}
    SQL
  end

  up do
    drop_view :review_tasks
    create_view :review_tasks, review_tasks.call(true)

    drop_view :activities
    create_view :activities, activities.call(true)
  end

  down do
    drop_view :activities
    create_view :activities, activities.call(false)

    drop_view :review_tasks
    create_view :review_tasks, review_tasks.call(false)
  end
end
