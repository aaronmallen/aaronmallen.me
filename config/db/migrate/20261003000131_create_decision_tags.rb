# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :decision_tags do
      foreign_key :decision_id, :decisions, null: false, on_delete: :cascade
      column :tag_id, Integer, null: false
      column :tag_scope, :tag_scope, null: false, default: "private"

      primary_key %i[decision_id tag_id]

      foreign_key %i[tag_id tag_scope], :tags, key: %i[id scope], on_delete: :restrict, name: :decision_tags_tag_id_fkey
      constraint(:decision_tags_tag_scope_check) { { tag_scope: "private" } }

      index :tag_id
    end
  end

  down do
    drop_table :decision_tags
  end
end
