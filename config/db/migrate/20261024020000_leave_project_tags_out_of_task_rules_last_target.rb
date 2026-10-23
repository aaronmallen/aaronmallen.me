# frozen_string_literal: true

ROM::SQL.migration do
  target = Kernel.lambda do |kept|
    <<~SQL
      CREATE OR REPLACE FUNCTION task_rules_last_target() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
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
                WHERE other.task_rule_id = rule.id AND (TG_TABLE_NAME <> 'tags' OR other.tag_id <> OLD.id)#{kept}
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
      $$;
    SQL
  end

  up do
    run target.call(" AND (TG_TABLE_NAME <> 'projects' OR other.tag_id NOT IN " \
                    "(SELECT id FROM tags WHERE project_id = OLD.id))")
  end

  down do
    run target.call("")
  end
end
