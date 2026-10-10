# frozen_string_literal: true

ROM::SQL.migration do
  mastodon_handle = "^@[^@\\s]+@[^@\\s]+$"
  photo_key = "^[0-9a-f]{32}\\.(gif|jpg|png|webp)$"

  handles = %w[key mastodon_handle bluesky_handle].map { "coalesce(#{it}::text, '')" }.join(" || ' ' || ")
  weighted = ->(weight, text) { "setweight(to_tsvector('english'::regconfig, #{text}), '#{weight}')" }
  vector = "#{weighted.call('A', "coalesce(name::text, '')")} || #{weighted.call('B', handles)}"

  rebuild_people = Kernel.lambda do |change|
    <<~SQL
      DO $$
      DECLARE
        documents text := pg_get_viewdef('search_documents');
      BEGIN
        DROP VIEW search_documents;
        ALTER TABLE people DROP COLUMN search_vector;
        #{change}
        ALTER TABLE people ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (#{vector}) STORED;
        CREATE INDEX people_search_vector_index ON people USING gin (search_vector);
        EXECUTE 'CREATE VIEW search_documents AS ' || documents;
      END
      $$;
    SQL
  end

  up do
    run "CREATE DOMAIN mastodon_handle AS text CHECK (VALUE ~ '#{mastodon_handle}')"
    run "CREATE DOMAIN photo_key AS text CHECK (VALUE ~ '#{photo_key}')"

    run <<~SQL
      ALTER TABLE feed_subscribers
        DROP CONSTRAINT feed_subscribers_aggregator_check,
        ALTER COLUMN aggregator TYPE ref_source;
      ALTER TABLE photos
        DROP CONSTRAINT photos_key_check,
        ALTER COLUMN key TYPE photo_key;
    SQL

    run rebuild_people.call(<<~SQL)
      ALTER TABLE people
        DROP CONSTRAINT people_key_check,
        DROP CONSTRAINT people_mastodon_handle_check,
        ALTER COLUMN key TYPE tag_name,
        ALTER COLUMN mastodon_handle TYPE mastodon_handle;
    SQL
  end

  down do
    run rebuild_people.call(<<~SQL)
      ALTER TABLE people
        ALTER COLUMN key TYPE text,
        ALTER COLUMN mastodon_handle TYPE text,
        ADD CONSTRAINT people_key_check CHECK (key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
        ADD CONSTRAINT people_mastodon_handle_check CHECK (mastodon_handle ~ '#{mastodon_handle}');
    SQL

    run <<~SQL
      ALTER TABLE photos
        ALTER COLUMN key TYPE text,
        ADD CONSTRAINT photos_key_check CHECK (key ~ '#{photo_key}');
      ALTER TABLE feed_subscribers
        ALTER COLUMN aggregator TYPE text,
        ADD CONSTRAINT feed_subscribers_aggregator_check
          CHECK (aggregator ~ '^[a-z0-9]+([._-][a-z0-9]+)*$' AND length(aggregator) <= 32);
    SQL

    run "DROP DOMAIN photo_key"
    run "DROP DOMAIN mastodon_handle"
  end
end
