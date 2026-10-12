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
    pull_request: :pull_requests,
  }

  linked_function, unlinked_function = [tables.merge(mail_thread: :mail_threads), tables].map do |kinds|
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

  up do
    add_enum_value :record_kind, "mail_thread"

    run linked_function

    run <<~SQL
      CREATE TRIGGER mail_threads_drop_record_links
        AFTER DELETE ON mail_threads
        FOR EACH ROW EXECUTE FUNCTION record_links_drop_record('mail_thread');
    SQL
  end

  down do
    run <<~SQL
      DROP TRIGGER mail_threads_drop_record_links ON mail_threads;
      DELETE FROM record_links WHERE left_kind::text = 'mail_thread' OR right_kind::text = 'mail_thread';

      DROP TRIGGER record_links_find_records ON record_links;
      ALTER TABLE record_links DROP CONSTRAINT record_links_task_pair_check;
      ALTER TYPE record_kind RENAME TO record_kind_with_mail_thread;
      CREATE TYPE record_kind AS ENUM (#{tables.keys.map { "'#{it}'" }.join(', ')});
      ALTER TABLE record_links
        ALTER COLUMN left_kind TYPE record_kind USING left_kind::text::record_kind,
        ALTER COLUMN right_kind TYPE record_kind USING right_kind::text::record_kind;
      ALTER TABLE record_links
        ADD CONSTRAINT record_links_task_pair_check CHECK (NOT (left_kind = 'task' AND right_kind = 'task'));
      DROP FUNCTION record_links_record_exists(record_kind_with_mail_thread, integer);
      DROP TYPE record_kind_with_mail_thread;
    SQL

    run unlinked_function

    run <<~SQL
      CREATE TRIGGER record_links_find_records
        BEFORE INSERT OR UPDATE OF left_kind, left_id, right_kind, right_id ON record_links
        FOR EACH ROW EXECUTE FUNCTION record_links_find_records();
    SQL
  end
end
