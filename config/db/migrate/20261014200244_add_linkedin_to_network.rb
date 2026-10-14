# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :network, "linkedin"
  end

  down do
    run <<~SQL
      DO $$
      DECLARE
        activities text := pg_get_viewdef('activities');
      BEGIN
        DELETE FROM social_post_deliveries WHERE network::text = 'linkedin';
        DELETE FROM social_posts WHERE targets::text[] = ARRAY['linkedin'];
        UPDATE social_posts SET targets = array_remove(targets, 'linkedin') WHERE 'linkedin' = ANY(targets::text[]);
        UPDATE posts SET syndication_targets = array_remove(syndication_targets, 'linkedin')
          WHERE 'linkedin' = ANY(syndication_targets::text[]);
        DELETE FROM service_connections WHERE provider = 'linkedin';
        DROP VIEW activities;
        ALTER TABLE posts ALTER COLUMN syndication_targets DROP DEFAULT;
        ALTER TYPE network RENAME TO network_with_linkedin;
        CREATE TYPE network AS ENUM ('bluesky', 'mastodon');
        ALTER TABLE posts ALTER COLUMN syndication_targets TYPE network[] USING syndication_targets::text[]::network[];
        ALTER TABLE posts ALTER COLUMN syndication_targets SET DEFAULT '{}';
        ALTER TABLE social_posts ALTER COLUMN targets TYPE network[] USING targets::text[]::network[];
        ALTER TABLE social_post_deliveries ALTER COLUMN network TYPE network USING network::text::network;
        DROP TYPE network_with_linkedin;
        EXECUTE 'CREATE VIEW activities AS ' || activities;
      END
      $$;
    SQL
  end
end
