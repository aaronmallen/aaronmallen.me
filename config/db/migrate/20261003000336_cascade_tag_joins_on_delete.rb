# frozen_string_literal: true

ROM::SQL.migration do
  joins = %i[post_tags project_tags journal_entry_tags task_tags decision_tags].freeze

  up do
    joins.each do |table|
      name = :"#{table}_tag_id_fkey"

      alter_table(table) do
        drop_constraint name
        add_foreign_key %i[tag_id tag_scope], :tags, key: %i[id scope], on_delete: :cascade, name:
      end
    end
  end

  down do
    joins.each do |table|
      name = :"#{table}_tag_id_fkey"

      alter_table(table) do
        drop_constraint name
        add_foreign_key %i[tag_id tag_scope], :tags, key: %i[id scope], on_delete: :restrict, name:
      end
    end
  end
end
