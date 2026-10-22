# frozen_string_literal: true

ROM::SQL.migration do
  branch = <<~SQL
    UNION ALL
    SELECT
      'note'::text,
      notes.id,
      notes.title::text,
      notes.title || E'\\n' || notes.body,
      (notes.updated_at AT TIME ZONE '#{Blog::TimeZone::NAME}')::date,
      NULL::text,
      NULL::text,
      NULL::text,
      NULL::text,
      NULL::text,
      notes.search_vector
    FROM notes
  SQL

  up do
    run <<~SQL
      ALTER TABLE notes ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english'::regconfig, title::text), 'A') ||
        setweight(to_tsvector('english'::regconfig, body), 'B')
      ) STORED;
      CREATE INDEX notes_search_vector_index ON notes USING gin (search_vector);

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
        branch text := '\\s+UNION ALL\\s+SELECT\\s+''note''.*$';
      BEGIN
        IF documents !~ branch THEN
          RAISE EXCEPTION 'note branch not found in the search_documents view';
        END IF;
        DROP VIEW search_documents;
        EXECUTE 'CREATE VIEW search_documents AS ' || regexp_replace(documents, branch, '');
      END
      $$;

      ALTER TABLE notes DROP COLUMN search_vector;
    SQL
  end
end
