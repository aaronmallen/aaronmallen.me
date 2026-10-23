# frozen_string_literal: true

ROM::SQL.migration do
  joins = {
    decision_tags: "private",
    journal_entry_tags: "private",
    mail_thread_tags: "private",
    note_tags: "private",
    post_tags: "public",
    task_rule_tags: "private",
    task_tags: "private",
  }.freeze

  up do
    alter_table :tags do
      add_foreign_key :project_id, :projects, on_delete: :cascade
      add_constraint(:tags_project_id_check, Sequel.expr(scope: "project") =~ Sequel.~(project_id: nil))
      drop_constraint :tags_scope_name_key
      add_index %i[project_id scope name], unique: true, nulls_distinct: false
    end

    joins.each do |table, scope|
      alter_table table do
        drop_constraint :"#{table}_tag_scope_check"
        add_constraint(:"#{table}_tag_scope_check", tag_scope: [scope, "project"])
      end
    end
  end

  down do
    from(:tags).where(scope: "project").delete

    joins.each do |table, scope|
      alter_table table do
        drop_constraint :"#{table}_tag_scope_check"
        add_constraint(:"#{table}_tag_scope_check", tag_scope: scope)
      end
    end

    alter_table :tags do
      drop_index %i[project_id scope name]
      add_unique_constraint %i[scope name], name: :tags_scope_name_key
      drop_constraint :tags_project_id_check
      drop_column :project_id
    end
  end
end
