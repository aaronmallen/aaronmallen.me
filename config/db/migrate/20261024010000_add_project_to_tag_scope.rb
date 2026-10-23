# frozen_string_literal: true

ROM::SQL.migration do
  no_transaction

  joins = {
    decision_tags: "private",
    journal_entry_tags: "private",
    mail_thread_tags: "private",
    note_tags: "private",
    post_tags: "public",
    project_tags: "public",
    task_rule_tags: "private",
    task_tags: "private",
  }.freeze

  up do
    add_enum_value :tag_scope, "project", if_not_exists: true
  end

  down do
    loosened = joins.map do |table, scope|
      <<~SQL
        ALTER TABLE #{table}
          DROP CONSTRAINT #{table}_tag_id_fkey,
          DROP CONSTRAINT #{table}_tag_scope_check,
          ALTER COLUMN tag_scope DROP DEFAULT;
        ALTER TABLE #{table} ALTER COLUMN tag_scope TYPE tag_scope USING tag_scope::text::tag_scope;
        ALTER TABLE #{table}
          ALTER COLUMN tag_scope SET DEFAULT '#{scope}',
          ADD CONSTRAINT #{table}_tag_scope_check CHECK (tag_scope = '#{scope}');
      SQL
    end
    held = joins.keys.map do |table|
      <<~SQL
        ALTER TABLE #{table} ADD CONSTRAINT #{table}_tag_id_fkey
          FOREIGN KEY (tag_id, tag_scope) REFERENCES tags (id, scope) ON DELETE CASCADE;
      SQL
    end

    run <<~SQL
      DO $$
      DECLARE
        documents text := pg_get_viewdef('public_search_documents');
      BEGIN
        DELETE FROM tags WHERE scope::text = 'project';
        DROP VIEW public_search_documents;
        ALTER TYPE tag_scope RENAME TO tag_scope_with_project;
        CREATE TYPE tag_scope AS ENUM ('public', 'private');
        #{loosened.join}
        ALTER TABLE tags ALTER COLUMN scope TYPE tag_scope USING scope::text::tag_scope;
        #{held.join}
        DROP TYPE tag_scope_with_project;
        EXECUTE 'CREATE VIEW public_search_documents AS ' || documents;
      END
      $$;
    SQL
  end
end
