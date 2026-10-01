# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :webmention_status, "ignored", before: "spam"
  end

  down do
    run <<~SQL
      DO $$
      DECLARE
        activities text := pg_get_viewdef('activities');
      BEGIN
        UPDATE webmentions SET status = 'spam' WHERE status::text = 'ignored';
        DROP VIEW activities;
        ALTER TABLE webmentions ALTER COLUMN status DROP DEFAULT;
        ALTER TYPE webmention_status RENAME TO webmention_status_with_ignored;
        CREATE TYPE webmention_status AS ENUM ('pending', 'approved', 'spam');
        ALTER TABLE webmentions ALTER COLUMN status TYPE webmention_status USING status::text::webmention_status;
        ALTER TABLE webmentions ALTER COLUMN status SET DEFAULT 'pending';
        DROP TYPE webmention_status_with_ignored;
        EXECUTE 'CREATE VIEW activities AS ' || activities;
      END
      $$;
    SQL
  end
end
