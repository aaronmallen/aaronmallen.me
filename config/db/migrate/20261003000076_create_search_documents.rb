# frozen_string_literal: true

ROM::SQL.migration do
  weighted = Kernel.lambda do |weight, *columns|
    text = columns.map { "coalesce(#{it}::text, '')" }.join(" || ' ' || ")

    "setweight(to_tsvector('english'::regconfig, #{text}), '#{weight}')"
  end

  vectors = {
    tasks: [weighted.call("A", "title"), weighted.call("B", "note")],
    posts: [weighted.call("A", "title"), weighted.call("B", "summary", "body")],
    social_post_parts: [weighted.call("B", "body")],
    journal_entries: [weighted.call("B", "body")],
    commits: [
      weighted.call("A", "split_part(message, E'\\n', 1)"),
      weighted.call("B", "repo", "regexp_replace(message, '^[^\\n]*\\n?', '')"),
    ],
    projects: [weighted.call("A", "name"), weighted.call("B", "tagline", "repo")],
    work_entries: [weighted.call("A", "org"), weighted.call("B", "role", "blurb")],
    people: [weighted.call("A", "name"), weighted.call("B", "key", "mastodon_handle", "bluesky_handle")],
    messages: [weighted.call("A", "subject"), weighted.call("B", "body", "reply_to")],
    webmentions: [weighted.call("A", "author_name"), weighted.call("B", "excerpt", "source_url")],
  }

  zone = Blog::TimeZone::NAME
  day = ->(column) { "(#{column} AT TIME ZONE '#{zone}')::date" }
  joined = ->(*columns) { columns.map { "coalesce(#{it}::text, '')" }.join(" || E'\\n' || ") }

  documents = <<~SQL
    SELECT
      'task'::text AS kind,
      tasks.id AS source_id,
      tasks.title::text AS title,
      #{joined.call('tasks.title', 'tasks.note')} AS body,
      #{day.call('coalesce(tasks.completed_at, tasks.created_at)')} AS day,
      tasks.status::text AS status,
      NULL::text AS slug,
      NULL::text AS repo,
      NULL::text AS sha,
      NULL::text AS url,
      tasks.search_vector AS search_vector
    FROM tasks
    UNION ALL
    SELECT
      'post',
      posts.id,
      posts.title,
      #{joined.call('posts.title', 'posts.summary', 'posts.body')},
      #{day.call('coalesce(posts.published_at, posts.created_at)')},
      posts.status::text,
      posts.slug,
      NULL,
      NULL,
      NULL,
      posts.search_vector
    FROM posts
    UNION ALL
    SELECT
      'social',
      social_posts.id,
      social_post_parts.body::text,
      social_post_parts.body::text,
      #{day.call('coalesce(social_posts.posted_at, social_posts.created_at)')},
      social_posts.status::text,
      NULL,
      NULL,
      NULL,
      NULL,
      social_post_parts.search_vector
    FROM social_post_parts
    JOIN social_posts ON social_posts.id = social_post_parts.social_post_id
    UNION ALL
    SELECT
      'journal',
      journal_entries.id,
      split_part(journal_entries.body::text, E'\\n', 1),
      journal_entries.body::text,
      journal_entries.entry_date,
      NULL,
      NULL,
      NULL,
      NULL,
      NULL,
      journal_entries.search_vector
    FROM journal_entries
    UNION ALL
    SELECT
      'commit',
      commits.id,
      split_part(commits.message, E'\\n', 1),
      commits.message,
      commits.commit_date,
      NULL,
      NULL,
      commits.repo,
      commits.sha,
      NULL,
      commits.search_vector
    FROM commits
    UNION ALL
    SELECT
      'project',
      projects.id,
      projects.name::text,
      #{joined.call('projects.name', 'projects.tagline', 'projects.repo')},
      #{day.call('projects.created_at')},
      projects.status::text,
      NULL,
      projects.repo::text,
      NULL,
      projects.url,
      projects.search_vector
    FROM projects
    UNION ALL
    SELECT
      'work',
      work_entries.id,
      work_entries.org::text,
      #{joined.call('work_entries.org', 'work_entries.role', 'work_entries.blurb')},
      #{day.call('work_entries.created_at')},
      NULL,
      NULL,
      NULL,
      NULL,
      NULL,
      work_entries.search_vector
    FROM work_entries
    UNION ALL
    SELECT
      'person',
      people.id,
      people.name::text,
      #{joined.call('people.name', 'people.key', 'people.mastodon_handle', 'people.bluesky_handle')},
      #{day.call('people.created_at')},
      NULL,
      NULL,
      NULL,
      NULL,
      NULL,
      people.search_vector
    FROM people
    UNION ALL
    SELECT
      'message',
      messages.id,
      messages.subject::text,
      #{joined.call('messages.subject', 'messages.body', 'messages.reply_to')},
      #{day.call('messages.received_at')},
      messages.status::text,
      NULL,
      NULL,
      NULL,
      NULL,
      messages.search_vector
    FROM messages
    UNION ALL
    SELECT
      'webmention',
      webmentions.id,
      coalesce(webmentions.author_name, webmentions.author_domain, webmentions.source_url::text),
      #{joined.call('webmentions.author_name', 'webmentions.excerpt', 'webmentions.source_url')},
      #{day.call('webmentions.received_at')},
      webmentions.status::text,
      NULL,
      NULL,
      NULL,
      webmentions.source_url::text,
      webmentions.search_vector
    FROM webmentions
  SQL

  up do
    vectors.each do |table, parts|
      alter_table(table) do
        add_column :search_vector, :tsvector, generated_always_as: Sequel.lit(parts.join(" || "))
        add_index :search_vector, type: :gin
      end
    end

    create_view :search_documents, documents
  end

  down do
    drop_view :search_documents

    vectors.each_key { |table| alter_table(table) { drop_column :search_vector } }
  end
end
