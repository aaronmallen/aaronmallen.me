# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run <<~SQL
      CREATE DOMAIN repo_pattern AS text CHECK (VALUE ~ '^[a-z0-9][a-z0-9-]*/([a-z0-9._-]+|\\*)$');
    SQL

    create_table :task_tag_rules do
      primary_key :id
      column :pattern, :repo_pattern, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :pattern, unique: true
    end

    create_table :task_tag_rule_tags do
      foreign_key :task_tag_rule_id, :task_tag_rules, null: false, on_delete: :cascade
      column :tag_id, Integer, null: false
      column :tag_scope, :tag_scope, null: false, default: "private"

      primary_key %i[task_tag_rule_id tag_id]

      foreign_key %i[tag_id tag_scope], :tags,
                  key: %i[id scope], on_delete: :cascade, name: :task_tag_rule_tags_tag_id_fkey
      constraint(:task_tag_rule_tags_tag_scope_check) { { tag_scope: "private" } }

      index :tag_id
    end
  end

  down do
    drop_table :task_tag_rule_tags
    drop_table :task_tag_rules

    run <<~SQL
      DROP DOMAIN repo_pattern;
    SQL
  end
end
