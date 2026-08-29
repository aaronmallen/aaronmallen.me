# frozen_string_literal: true

ROM::SQL.migration do
  up do
    zone = Blog::TimeZone::NAME

    run <<~SQL
      CREATE INDEX posts_published_on_index
        ON posts (((published_at AT TIME ZONE '#{zone}')::date));
      CREATE INDEX social_posts_posted_on_index
        ON social_posts (((posted_at AT TIME ZONE '#{zone}')::date));
      CREATE INDEX webmentions_received_on_index
        ON webmentions (((received_at AT TIME ZONE '#{zone}')::date));
      CREATE INDEX tasks_completed_on_index
        ON tasks (((completed_at AT TIME ZONE '#{zone}')::date));
      CREATE INDEX projects_created_on_index
        ON projects (((created_at AT TIME ZONE '#{zone}')::date));
      CREATE INDEX suggestions_created_on_index
        ON suggestions (((created_at AT TIME ZONE '#{zone}')::date));
    SQL

    create_view :activities, <<~SQL
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
        NULL::text AS task_type
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
        NULL
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
        NULL
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
        NULL
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
        NULL
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
        task_types.name
      FROM tasks
      LEFT JOIN task_types ON task_types.id = tasks.task_type_id
      WHERE tasks.completed_at IS NOT NULL
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
        NULL
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
        NULL
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
        NULL
      FROM suggestions
      LEFT JOIN posts ON posts.id = suggestions.post_id
      LEFT JOIN LATERAL (
        SELECT social_post_parts.body
        FROM social_post_parts
        WHERE social_post_parts.social_post_id = suggestions.social_post_id
        ORDER BY social_post_parts.position
        LIMIT 1
      ) AS first_part ON true
    SQL
  end

  down do
    drop_view :activities

    run <<~SQL
      DROP INDEX suggestions_created_on_index;
      DROP INDEX projects_created_on_index;
      DROP INDEX tasks_completed_on_index;
      DROP INDEX webmentions_received_on_index;
      DROP INDEX social_posts_posted_on_index;
      DROP INDEX posts_published_on_index;
    SQL
  end
end
