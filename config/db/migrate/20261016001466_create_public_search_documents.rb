# frozen_string_literal: true

ROM::SQL.migration do
  zone = Blog::TimeZone::NAME
  day = ->(column) { "(#{column} AT TIME ZONE '#{zone}')::date" }
  joined = ->(*columns) { columns.map { "coalesce(#{it}::text, '')" }.join(" || E'\\n' || ") }
  tag_vector = "setweight(to_tsvector('english'::regconfig, tags.name::text), 'B')"

  post = Kernel.lambda do |vector|
    <<~SQL
      SELECT
        'post'::text AS kind,
        posts.id AS source_id,
        posts.title AS title,
        #{joined.call('posts.title', 'posts.summary', 'posts.body')} AS body,
        #{day.call('posts.published_at')} AS day,
        NULL::text AS status,
        posts.slug AS slug,
        NULL::text AS project,
        NULL::integer AS number,
        #{vector} AS search_vector
      FROM posts
    SQL
  end

  project = Kernel.lambda do |vector|
    <<~SQL
      SELECT
        'project'::text,
        projects.id,
        projects.name::text,
        #{joined.call('projects.name', 'projects.tagline', 'projects.repo')},
        #{day.call('projects.created_at')},
        CASE WHEN projects.archived_on IS NULL THEN 'active' ELSE 'archived' END,
        NULL::text,
        projects.name::text,
        NULL::integer,
        #{vector}
      FROM projects
    SQL
  end

  up do
    run <<~SQL
      CREATE VIEW public_search_documents AS
      #{post.call('posts.search_vector')}
      WHERE posts.status = 'published'
      UNION ALL
      #{post.call(tag_vector)}
      JOIN post_tags ON post_tags.post_id = posts.id
      JOIN tags ON tags.id = post_tags.tag_id AND tags.scope = 'public'
      WHERE posts.status = 'published'
      UNION ALL
      #{project.call('projects.search_vector')}
      WHERE projects.visibility = 'public'
      UNION ALL
      #{project.call(tag_vector)}
      JOIN project_tags ON project_tags.project_id = projects.id
      JOIN tags ON tags.id = project_tags.tag_id AND tags.scope = 'public'
      WHERE projects.visibility = 'public'
      UNION ALL
      SELECT
        'task'::text,
        tasks.id,
        tasks.title::text,
        #{joined.call('tasks.title', 'tasks.note')},
        #{day.call('coalesce(tasks.completed_at, tasks.created_at)')},
        tasks.status::text,
        NULL::text,
        projects.name::text,
        tasks.number,
        tasks.search_vector
      FROM tasks
      JOIN projects ON projects.id = tasks.project_id
      WHERE projects.visibility = 'public' AND projects.board_published
    SQL
  end

  down do
    run "DROP VIEW public_search_documents"
  end
end
