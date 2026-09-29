# frozen_string_literal: true

ROM::SQL.migration do
  joins = {
    post_tags: "public",
    project_tags: "public",
    journal_entry_tags: "private",
    task_tags: "private",
  }.freeze

  up do
    alter_table(:tags) { add_unique_constraint %i[id scope], name: :tags_id_scope_key }

    joins.each do |table, scope|
      run <<~SQL
        ALTER TABLE #{table}
          ADD COLUMN tag_scope tag_scope NOT NULL DEFAULT '#{scope}'
            CONSTRAINT #{table}_tag_scope_check CHECK (tag_scope = '#{scope}'),
          DROP CONSTRAINT #{table}_tag_id_fkey,
          ADD CONSTRAINT #{table}_tag_id_fkey
            FOREIGN KEY (tag_id, tag_scope) REFERENCES tags (id, scope) ON DELETE RESTRICT;
      SQL
    end
  end

  down do
    joins.each_key do |table|
      run <<~SQL
        ALTER TABLE #{table}
          DROP CONSTRAINT #{table}_tag_id_fkey,
          DROP COLUMN tag_scope,
          ADD CONSTRAINT #{table}_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE RESTRICT;
      SQL
    end

    alter_table(:tags) { drop_constraint :tags_id_scope_key }
  end
end
