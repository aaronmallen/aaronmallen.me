# frozen_string_literal: true

ROM::SQL.migration do
  # The kinds sort in the order the Linked section groups them, and RecordLinkRepo sorts each pair by it.
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

  finds = tables.map do |kind, table|
    "WHEN '#{kind}' THEN PERFORM 1 FROM #{table} WHERE id = record_id FOR KEY SHARE;"
  end

  up do
    create_enum :record_kind, tables.keys.map(&:to_s)

    create_table :record_links do
      primary_key :id
      column :left_kind, :record_kind, null: false
      column :left_id, Integer, null: false
      column :right_kind, :record_kind, null: false
      column :right_id, Integer, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :record_links_order_check, Sequel.lit("(left_kind, left_id) < (right_kind, right_id)")
      constraint :record_links_task_pair_check, Sequel.lit("NOT (left_kind = 'task' AND right_kind = 'task')")

      index %i[left_kind left_id right_kind right_id], unique: true, name: :record_links_pair_key
      index %i[right_kind right_id]
    end

    run <<~SQL
      CREATE FUNCTION record_links_record_exists(kind record_kind, record_id integer) RETURNS boolean AS $$
      BEGIN
        CASE kind
          #{finds.join("\n    ")}
        END CASE;

        RETURN FOUND;
      END;
      $$ LANGUAGE plpgsql;

      CREATE FUNCTION record_links_find_records() RETURNS trigger AS $$
      BEGIN
        IF NOT record_links_record_exists(NEW.left_kind, NEW.left_id)
          OR NOT record_links_record_exists(NEW.right_kind, NEW.right_id) THEN
          RAISE EXCEPTION 'a record link names a record that does not exist'
            USING ERRCODE = 'foreign_key_violation', CONSTRAINT = 'record_links_record_missing';
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER record_links_find_records
        BEFORE INSERT OR UPDATE OF left_kind, left_id, right_kind, right_id ON record_links
        FOR EACH ROW EXECUTE FUNCTION record_links_find_records();

      CREATE FUNCTION record_links_drop_record() RETURNS trigger AS $$
      BEGIN
        DELETE FROM record_links
        WHERE (left_kind = TG_ARGV[0]::record_kind AND left_id = OLD.id)
          OR (right_kind = TG_ARGV[0]::record_kind AND right_id = OLD.id);

        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    tables.each do |kind, table|
      run <<~SQL
        CREATE TRIGGER #{table}_drop_record_links
          AFTER DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION record_links_drop_record('#{kind}');
      SQL
    end
  end

  down do
    tables.each_value { |table| run "DROP TRIGGER #{table}_drop_record_links ON #{table};" }

    drop_table :record_links

    run <<~SQL
      DROP FUNCTION record_links_drop_record();
      DROP FUNCTION record_links_find_records();
      DROP FUNCTION record_links_record_exists(record_kind, integer);
    SQL

    drop_enum :record_kind
  end
end
