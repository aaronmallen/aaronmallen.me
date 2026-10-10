# frozen_string_literal: true

ROM::SQL.migration do
  zone = Blog::TimeZone::NAME
  links = "/* links */"
  no_links = ", NULL::integer, NULL::text, NULL::text, NULL::integer"
  broken_links = <<~SQL
    SELECT
      'broken_link'::text AS kind,
      post_link_checks.id AS record_id,
      posts.title,
      (post_link_checks.checked_at AT TIME ZONE '#{zone}')::date AS touched_on,
      NULL::integer AS carried_count,
      posts.id AS post_id,
      post_link_checks.url,
      post_link_checks.reason,
      post_link_checks.failures
    FROM post_link_checks
    JOIN posts ON posts.id = post_link_checks.post_id
    WHERE posts.status = 'published'
    UNION ALL
  SQL
  stalled = <<~SQL
    SELECT
      'carried'::text AS kind,
      tasks.id AS record_id,
      tasks.title::text AS title,
      (tasks.updated_at AT TIME ZONE '#{zone}')::date AS touched_on,
      tasks.carried_count#{links}
    FROM tasks
    WHERE tasks.status NOT IN ('done', 'canceled') AND tasks.carried_count > 0
    UNION ALL
    SELECT 'draft'::text, posts.id, posts.title, (posts.updated_at AT TIME ZONE '#{zone}')::date, NULL::integer#{links}
    FROM posts
    WHERE posts.status = 'draft'
    UNION ALL
    SELECT
      'someday'::text, tasks.id, tasks.title::text, (tasks.updated_at AT TIME ZONE '#{zone}')::date, NULL::integer#{links}
    FROM tasks
    WHERE tasks.status NOT IN ('done', 'canceled') AND tasks.list = 'someday'
    UNION ALL
    SELECT 'journal'::text, NULL::integer, NULL::text, max(journal_entries.entry_date), NULL::integer#{links}
    FROM journal_entries
    HAVING count(*) > 0
    UNION ALL
    SELECT
      'new_device'::text,
      known_devices.id,
      format(
        '%s: %s in %s',
        CASE
          WHEN api_tokens.id IS NOT NULL THEN 'API token ' || api_tokens.name
          WHEN oauth_clients.id IS NOT NULL
            THEN 'MCP client ' || coalesce(nullif(btrim(oauth_clients.client_name), ''), oauth_clients.client_id)
          ELSE 'Sign-in'
        END,
        coalesce(nullif(concat_ws(' on ', known_devices.browser, known_devices.os), ''), 'an unknown device'),
        coalesce(nullif(concat_ws(', ', known_devices.city, known_devices.country), ''), 'an unknown place')
      ),
      (known_devices.created_at AT TIME ZONE '#{zone}')::date,
      NULL::integer#{links}
    FROM known_devices
    LEFT JOIN api_tokens ON api_tokens.id = known_devices.api_token_id
    LEFT JOIN oauth_clients ON oauth_clients.id = known_devices.oauth_client_id
    WHERE EXISTS (
      SELECT 1 FROM known_devices earlier
        WHERE earlier.id < known_devices.id
          AND earlier.api_token_id IS NOT DISTINCT FROM known_devices.api_token_id
          AND earlier.oauth_client_id IS NOT DISTINCT FROM known_devices.oauth_client_id
    )
  SQL

  up do
    add_enum_value :attention_kind, "broken_link"

    run <<~SQL
      DROP VIEW attention;
      CREATE VIEW attention AS #{broken_links} #{stalled.gsub(links, no_links)};

      CREATE TRIGGER post_link_checks_drop_attention_snoozes
        AFTER DELETE ON post_link_checks
        FOR EACH ROW EXECUTE FUNCTION attention_snoozes_drop_record('broken_link');
    SQL
  end

  down do
    run <<~SQL
      DROP TRIGGER post_link_checks_drop_attention_snoozes ON post_link_checks;
      DROP VIEW attention;
      CREATE VIEW attention AS #{stalled.gsub(links, '')};

      DELETE FROM attention_snoozes WHERE kind::text = 'broken_link';
      ALTER TYPE attention_kind RENAME TO attention_kind_with_broken_link;
      CREATE TYPE attention_kind AS ENUM ('carried', 'draft', 'someday', 'journal', 'new_device');
      ALTER TABLE attention_snoozes
        DROP CONSTRAINT attention_snoozes_record_check,
        ALTER COLUMN kind TYPE attention_kind USING kind::text::attention_kind,
        ADD CONSTRAINT attention_snoozes_record_check CHECK ((kind = 'journal') = (record_id IS NULL));
      DROP TYPE attention_kind_with_broken_link;
    SQL
  end
end
