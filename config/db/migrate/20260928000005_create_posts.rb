# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :network, %w[bluesky mastodon].sort
    create_enum :post_status, %w[draft scheduled published]

    create_table :posts do
      primary_key :id
      column :title, :text, null: false
      column :slug, :text, null: false, unique: true
      column :status, :post_status, null: false, default: "draft"
      column :published_at, :timestamptz
      column :body, :text, null: false, default: ""
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :webmentions_enabled, :boolean, null: false
      column :webmention_targets, "text[]", null: false, default: Sequel.lit("'{}'")
      column :syndication_enabled, :boolean, null: false, default: false
      column :syndication_body, :text, null: false, default: ""
      column :syndication_targets, "network[]", null: false, default: Sequel.lit("'{}'")
      column :summary, :text, null: false, default: ""
      column :og_title, :text, null: false, default: ""
      column :og_image_url, :text, null: false, default: ""
      column :canonical_url, :text, null: false, default: ""

      constraint :posts_published_at_check, Sequel.lit("status = 'draft' OR published_at IS NOT NULL")

      index :published_at
      index :status
    end

    run <<~SQL
      CREATE FUNCTION posts_default_webmentions_enabled() RETURNS trigger AS $$
      BEGIN
        NEW.webmentions_enabled := coalesce(
          NEW.webmentions_enabled,
          (SELECT enable_on_new_posts FROM webmention_settings LIMIT 1),
          true
        );

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER posts_default_webmentions_enabled
        BEFORE INSERT ON posts
        FOR EACH ROW EXECUTE FUNCTION posts_default_webmentions_enabled();

      CREATE FUNCTION posts_lock_published_slug() RETURNS trigger AS $$
      BEGIN
        IF OLD.status = 'published' AND NEW.slug IS DISTINCT FROM OLD.slug THEN
          RAISE EXCEPTION 'the slug of a published post cannot change'
            USING ERRCODE = 'check_violation', CONSTRAINT = 'posts_published_slug_locked';
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER posts_lock_published_slug
        BEFORE UPDATE OF slug ON posts
        FOR EACH ROW EXECUTE FUNCTION posts_lock_published_slug();
    SQL
  end

  down do
    drop_table :posts

    run <<~SQL
      DROP FUNCTION posts_lock_published_slug();
      DROP FUNCTION posts_default_webmentions_enabled();
    SQL

    drop_enum :post_status
    drop_enum :network
  end
end
