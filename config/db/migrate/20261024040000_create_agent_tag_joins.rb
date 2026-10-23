# frozen_string_literal: true

ROM::SQL.migration do
  joins = { agent_session_tags: :agent_sessions, memory_file_tags: :memory_files, artifact_tags: :artifacts }.freeze

  up do
    joins.each do |table, owners|
      owner_key = :"#{owners.to_s.delete_suffix('s')}_id"

      create_table table do
        foreign_key owner_key, owners, null: false, on_delete: :cascade
        column :tag_id, Integer, null: false
        column :tag_scope, :tag_scope, null: false, default: "private"

        primary_key [owner_key, :tag_id]

        foreign_key %i[tag_id tag_scope], :tags, key: %i[id scope], on_delete: :cascade, name: :"#{table}_tag_id_fkey"
        constraint(:"#{table}_tag_scope_check") { { tag_scope: %w[private project] } }

        index :tag_id
      end

      run <<~SQL
        CREATE TRIGGER #{table}_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
      SQL
    end

    run <<~SQL
      INSERT INTO tags (name, color, scope)
      SELECT DISTINCT held.name, 'mk-violet'::tag_color, 'private'::tag_scope
      FROM artifacts CROSS JOIN unnest(artifacts.tags) AS held(name)
      WHERE NOT EXISTS (SELECT 1 FROM tags WHERE tags.scope = 'private' AND tags.name = held.name);

      INSERT INTO artifact_tags (artifact_id, tag_id, tag_scope)
      SELECT DISTINCT artifacts.id, tags.id, tags.scope
      FROM artifacts CROSS JOIN unnest(artifacts.tags) AS held(name)
      JOIN tags ON tags.scope = 'private' AND tags.name = held.name;
    SQL

    alter_table :artifacts do
      drop_index :tags
      drop_constraint :artifacts_tags_check
      drop_column :tags
    end
  end

  down do
    alter_table :artifacts do
      add_column :tags, "text[]", null: false, default: Sequel.lit("'{}'")
      add_constraint :artifacts_tags_check, Sequel.lit(<<~SQL)
        cardinality(tags) = 0 OR array_to_string(tags, ' ', '-') ~ '^[a-z0-9]+(-[a-z0-9]+)*( [a-z0-9]+(-[a-z0-9]+)*)*$'
      SQL
      add_index :tags, type: :gin
    end

    run <<~SQL
      UPDATE artifacts
      SET tags = held.names
      FROM (
        SELECT artifact_id, array_agg(tags.name ORDER BY tags.name) AS names
        FROM artifact_tags JOIN tags ON tags.id = artifact_tags.tag_id
        GROUP BY artifact_id
      ) AS held
      WHERE held.artifact_id = artifacts.id;
    SQL

    joins.each_key { drop_table it }
  end
end
