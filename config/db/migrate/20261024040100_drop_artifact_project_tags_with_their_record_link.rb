# frozen_string_literal: true

ROM::SQL.migration do
  joins = {
    post: %i[post_tags post_id],
    journal_entry: %i[journal_entry_tags journal_entry_id],
    decision: %i[decision_tags decision_id],
    mail_thread: %i[mail_thread_tags mail_thread_id],
    note: %i[note_tags note_id],
  }.freeze

  drop_project_tags = Kernel.lambda do |kinds|
    drops = kinds.map do |kind, (table, owner)|
      "WHEN '#{kind}' THEN DELETE FROM #{table} WHERE #{owner} = record_id " \
        "AND tag_id IN (SELECT id FROM tags WHERE project_id = project);"
    end

    <<~SQL
      CREATE OR REPLACE FUNCTION record_links_drop_project_tags() RETURNS trigger AS $$
      DECLARE
        kind record_kind := OLD.left_kind;
        record_id integer := OLD.left_id;
        project integer := OLD.right_id;
      BEGIN
        IF OLD.left_kind = 'project' THEN
          kind := OLD.right_kind;
          record_id := OLD.right_id;
          project := OLD.left_id;
        ELSIF OLD.right_kind <> 'project' THEN
          RETURN OLD;
        END IF;

        CASE kind
          #{drops.join("\n    ")}
          ELSE NULL;
        END CASE;

        RETURN OLD;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  up do
    run drop_project_tags.call({ **joins, artifact: %i[artifact_tags artifact_id] })
  end

  down do
    run drop_project_tags.call(joins)
  end
end
