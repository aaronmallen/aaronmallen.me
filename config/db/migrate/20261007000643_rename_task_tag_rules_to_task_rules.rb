# frozen_string_literal: true

ROM::SQL.migration do
  rename = Kernel.lambda do |from, to|
    not_nulls = %w[id pattern created_at updated_at provider].map { ["#{to}s", "#{from}s_#{it}", "#{to}s_#{it}"] } +
                [["#{to}_tags", "#{from}_tags_#{from}_id", "#{to}_tags_#{to}_id"]] +
                %w[tag_id tag_scope].map { ["#{to}_tags", "#{from}_tags_#{it}", "#{to}_tags_#{it}"] }

    <<~SQL
      ALTER TABLE #{from}s RENAME TO #{to}s;
      ALTER SEQUENCE #{from}s_id_seq RENAME TO #{to}s_id_seq;
      ALTER TABLE #{to}s RENAME CONSTRAINT #{from}s_pkey TO #{to}s_pkey;
      ALTER INDEX #{from}s_provider_pattern_index RENAME TO #{to}s_provider_pattern_index;
      ALTER TRIGGER #{from}s_notify_admin_change ON #{to}s RENAME TO #{to}s_notify_admin_change;

      ALTER TABLE #{from}_tags RENAME TO #{to}_tags;
      ALTER TABLE #{to}_tags RENAME COLUMN #{from}_id TO #{to}_id;
      ALTER TABLE #{to}_tags RENAME CONSTRAINT #{from}_tags_pkey TO #{to}_tags_pkey;
      ALTER TABLE #{to}_tags RENAME CONSTRAINT #{from}_tags_tag_id_fkey TO #{to}_tags_tag_id_fkey;
      ALTER TABLE #{to}_tags RENAME CONSTRAINT #{from}_tags_#{from}_id_fkey TO #{to}_tags_#{to}_id_fkey;
      ALTER TABLE #{to}_tags RENAME CONSTRAINT #{from}_tags_tag_scope_check TO #{to}_tags_tag_scope_check;
      ALTER INDEX #{from}_tags_tag_id_index RENAME TO #{to}_tags_tag_id_index;
      ALTER TRIGGER #{from}_tags_notify_admin_change ON #{to}_tags RENAME TO #{to}_tags_notify_admin_change;

      #{not_nulls.map { |table, old, new| "ALTER TABLE #{table} RENAME CONSTRAINT #{old}_not_null TO #{new}_not_null;" }.join("\n")}
    SQL
  end

  up do
    run <<~SQL
      DROP TRIGGER task_tag_rules_last_tag ON tags;
      DROP FUNCTION task_tag_rules_last_tag();
    SQL

    run rename.call("task_tag_rule", "task_rule")

    create_table :task_rule_projects do
      foreign_key :task_rule_id, :task_rules, null: false, on_delete: :cascade
      foreign_key :project_id, :projects, null: false, on_delete: :cascade

      primary_key %i[task_rule_id project_id]

      index :project_id
    end

    run <<~SQL
      CREATE TRIGGER task_rule_projects_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON task_rule_projects
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();

      CREATE FUNCTION task_rules_last_target() RETURNS trigger AS $$
      DECLARE
        held integer[];
      BEGIN
        IF TG_TABLE_NAME = 'tags' THEN
          held := ARRAY(SELECT task_rule_id FROM task_rule_tags WHERE tag_id = OLD.id);
        ELSE
          held := ARRAY(SELECT task_rule_id FROM task_rule_projects WHERE project_id = OLD.id);
        END IF;

        PERFORM 1 FROM task_rules WHERE id = ANY (held) FOR SHARE;

        IF EXISTS (
          SELECT 1 FROM unnest(held) AS rule(id)
            WHERE NOT EXISTS (
              SELECT 1 FROM task_rule_tags other
                WHERE other.task_rule_id = rule.id AND (TG_TABLE_NAME <> 'tags' OR other.tag_id <> OLD.id)
            )
            AND NOT EXISTS (
              SELECT 1 FROM task_rule_projects other
                WHERE other.task_rule_id = rule.id AND (TG_TABLE_NAME <> 'projects' OR other.project_id <> OLD.id)
            )
        ) THEN
          RAISE EXCEPTION 'removing % % would leave a task rule with no tags or projects', TG_TABLE_NAME, OLD.id
            USING ERRCODE = 'check_violation', CONSTRAINT = 'task_rules_last_target';
        END IF;

        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER task_rules_last_target BEFORE DELETE ON tags
        FOR EACH ROW EXECUTE FUNCTION task_rules_last_target();

      CREATE TRIGGER task_rules_last_target BEFORE DELETE ON projects
        FOR EACH ROW EXECUTE FUNCTION task_rules_last_target();
    SQL
  end

  down do
    run <<~SQL
      DROP TRIGGER task_rules_last_target ON projects;
      DROP TRIGGER task_rules_last_target ON tags;
      DROP FUNCTION task_rules_last_target();
      DELETE FROM task_rules WHERE NOT EXISTS (SELECT 1 FROM task_rule_tags WHERE task_rule_id = task_rules.id);
    SQL

    drop_table :task_rule_projects

    run rename.call("task_rule", "task_tag_rule")

    run <<~SQL
      CREATE FUNCTION task_tag_rules_last_tag() RETURNS trigger AS $$
      BEGIN
        PERFORM 1 FROM task_tag_rules
          WHERE id IN (SELECT task_tag_rule_id FROM task_tag_rule_tags WHERE tag_id = OLD.id)
          FOR SHARE;

        IF EXISTS (
          SELECT 1 FROM task_tag_rule_tags held
            WHERE held.tag_id = OLD.id
              AND NOT EXISTS (
                SELECT 1 FROM task_tag_rule_tags other
                  WHERE other.task_tag_rule_id = held.task_tag_rule_id AND other.tag_id <> OLD.id
              )
        ) THEN
          RAISE EXCEPTION 'removing tag % would leave a task tag rule with no tags', OLD.id
            USING ERRCODE = 'check_violation', CONSTRAINT = 'task_tag_rules_last_tag';
        END IF;

        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER task_tag_rules_last_tag BEFORE DELETE ON tags
        FOR EACH ROW EXECUTE FUNCTION task_tag_rules_last_tag();
    SQL
  end
end
