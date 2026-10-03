# frozen_string_literal: true

ROM::SQL.migration do
  up do
    zone = Blog::TimeZone::NAME

    create_view :attention, <<~SQL
      SELECT
        'carried'::text AS kind,
        tasks.id AS record_id,
        tasks.title::text AS title,
        (tasks.updated_at AT TIME ZONE '#{zone}')::date AS touched_on,
        tasks.carried_count AS carried_count
      FROM tasks
      WHERE tasks.status NOT IN ('done', 'canceled') AND tasks.carried_count > 0
      UNION ALL
      SELECT
        'draft',
        posts.id,
        posts.title::text,
        (posts.updated_at AT TIME ZONE '#{zone}')::date,
        NULL
      FROM posts
      WHERE posts.status = 'draft'
      UNION ALL
      SELECT
        'someday',
        tasks.id,
        tasks.title::text,
        (tasks.updated_at AT TIME ZONE '#{zone}')::date,
        NULL
      FROM tasks
      WHERE tasks.status NOT IN ('done', 'canceled') AND tasks.list = 'someday'
      UNION ALL
      SELECT
        'journal',
        NULL,
        NULL,
        max(journal_entries.entry_date),
        NULL
      FROM journal_entries
      HAVING count(*) > 0
    SQL
  end

  down do
    drop_view :attention
  end
end
