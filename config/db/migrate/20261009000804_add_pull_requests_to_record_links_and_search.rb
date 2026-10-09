# frozen_string_literal: true

ROM::SQL.migration do
  tables = {
    task: :tasks,
    post: :posts,
    social_post: :social_posts,
    journal_entry: :journal_entries,
    commit: :commits,
    project: :projects,
    work_entry: :work_entries,
    decision: :decisions,
  }

  linked_function, unlinked_function = [tables.merge(pull_request: :pull_requests), tables].map do |kinds|
    finds = kinds.map do |kind, table|
      "WHEN '#{kind}' THEN PERFORM 1 FROM #{table} WHERE id = record_id FOR KEY SHARE;"
    end

    <<~SQL
      CREATE OR REPLACE FUNCTION record_links_record_exists(kind record_kind, record_id integer) RETURNS boolean AS $$
      BEGIN
        CASE kind
          #{finds.join("\n    ")}
        END CASE;

        RETURN FOUND;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  branch = <<~SQL
    UNION ALL
    SELECT
      'pull_request'::text,
      pull_requests.id,
      pull_requests.title,
      pull_requests.title || E'\\n' || pull_requests.body,
      (coalesce(pull_requests.merged_at, pull_requests.closed_at, pull_requests.ready_at, pull_requests.created_at)
        AT TIME ZONE '#{Blog::TimeZone::NAME}')::date,
      NULL::text,
      NULL::text,
      pull_requests.repo,
      NULL::text,
      pull_requests.url,
      pull_requests.search_vector
    FROM pull_requests
  SQL

  up do
    add_enum_value :record_kind, "pull_request"

    run linked_function

    run <<~SQL
      CREATE TRIGGER pull_requests_drop_record_links
        AFTER DELETE ON pull_requests
        FOR EACH ROW EXECUTE FUNCTION record_links_drop_record('pull_request');

      ALTER TABLE pull_requests ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english'::regconfig, title), 'A') ||
        setweight(to_tsvector('english'::regconfig, body), 'B')
      ) STORED;
      CREATE INDEX pull_requests_search_vector_index ON pull_requests USING gin (search_vector);

      DO $$
      DECLARE
        documents text := rtrim(pg_get_viewdef('search_documents'), E'; \\n');
      BEGIN
        DROP VIEW search_documents;
        EXECUTE 'CREATE VIEW search_documents AS ' || documents || ' ' || $branch$#{branch}$branch$;
      END
      $$;
    SQL
  end

  down do
    run <<~SQL
      DO $$
      DECLARE
        documents text := pg_get_viewdef('search_documents');
        branch text := '\\s+UNION ALL\\s+SELECT\\s+''pull_request''.*$';
      BEGIN
        IF documents !~ branch THEN
          RAISE EXCEPTION 'pull_request branch not found in the search_documents view';
        END IF;
        DROP VIEW search_documents;
        EXECUTE 'CREATE VIEW search_documents AS ' || regexp_replace(documents, branch, '');
      END
      $$;

      ALTER TABLE pull_requests DROP COLUMN search_vector;

      DROP TRIGGER pull_requests_drop_record_links ON pull_requests;
      DELETE FROM record_links WHERE left_kind::text = 'pull_request' OR right_kind::text = 'pull_request';

      DROP TRIGGER record_links_find_records ON record_links;
      ALTER TABLE record_links DROP CONSTRAINT record_links_task_pair_check;
      ALTER TYPE record_kind RENAME TO record_kind_with_pull_request;
      CREATE TYPE record_kind AS ENUM (#{tables.keys.map { "'#{it}'" }.join(', ')});
      ALTER TABLE record_links
        ALTER COLUMN left_kind TYPE record_kind USING left_kind::text::record_kind,
        ALTER COLUMN right_kind TYPE record_kind USING right_kind::text::record_kind;
      ALTER TABLE record_links
        ADD CONSTRAINT record_links_task_pair_check CHECK (NOT (left_kind = 'task' AND right_kind = 'task'));
      DROP FUNCTION record_links_record_exists(record_kind_with_pull_request, integer);
      DROP TYPE record_kind_with_pull_request;
    SQL

    run unlinked_function

    run <<~SQL
      CREATE TRIGGER record_links_find_records
        BEFORE INSERT OR UPDATE OF left_kind, left_id, right_kind, right_id ON record_links
        FOR EACH ROW EXECUTE FUNCTION record_links_find_records();
    SQL
  end
end
