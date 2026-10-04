# frozen_string_literal: true

ROM::SQL.migration do
  up do
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

      CREATE TRIGGER task_tag_rules_last_tag
        BEFORE DELETE ON tags
        FOR EACH ROW
        EXECUTE FUNCTION task_tag_rules_last_tag();
    SQL
  end

  down do
    run <<~SQL
      DROP TRIGGER task_tag_rules_last_tag ON tags;
      DROP FUNCTION task_tag_rules_last_tag();
    SQL
  end
end
