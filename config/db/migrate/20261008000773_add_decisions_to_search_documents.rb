# frozen_string_literal: true

ROM::SQL.migration do
  branch = <<~SQL
    UNION ALL
    SELECT
      'decision'::text,
      decisions.id,
      decisions.title::text,
      coalesce(decisions.title::text, '') || E'\\n' || coalesce(decisions.problem::text, ''),
      (decisions.created_at AT TIME ZONE '#{Blog::TimeZone::NAME}')::date,
      decisions.status::text,
      NULL::text,
      NULL::text,
      NULL::text,
      NULL::text,
      decisions.search_vector
    FROM decisions
  SQL

  up do
    run <<~SQL
      ALTER TABLE decisions ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english'::regconfig, coalesce(title::text, '')), 'A') ||
        setweight(to_tsvector('english'::regconfig, coalesce(problem::text, '')), 'B')
      ) STORED;
      CREATE INDEX decisions_search_vector_index ON decisions USING gin (search_vector);

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
        branch text := '\\s+UNION ALL\\s+SELECT\\s+''decision''.*$';
      BEGIN
        IF documents !~ branch THEN
          RAISE EXCEPTION 'decision branch not found in the search_documents view';
        END IF;
        DROP VIEW search_documents;
        EXECUTE 'CREATE VIEW search_documents AS ' || regexp_replace(documents, branch, '');
      END
      $$;

      ALTER TABLE decisions DROP COLUMN search_vector;
    SQL
  end
end
