# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :contributor_kind, %w[owner agent]

    run <<~SQL
      CREATE DOMAIN contributor_slug AS text
        CHECK (VALUE ~ '^[a-z0-9]+([.-][a-z0-9]+)*$' AND length(VALUE) <= 64);
    SQL

    create_table :task_contributors do
      primary_key :id
      foreign_key :task_id, :tasks, null: false, on_delete: :cascade
      column :kind, :contributor_kind, null: false
      column :agent, :contributor_slug
      column :model, :contributor_slug
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :task_contributors_kind_check, Sequel.lit(<<~SQL)
        num_nonnulls(agent, model) = CASE kind WHEN 'owner' THEN 0 ELSE 2 END
      SQL

      index %i[task_id agent model], unique: true, nulls_distinct: false
    end
  end

  down do
    drop_table :task_contributors

    run <<~SQL
      DROP DOMAIN contributor_slug;
    SQL

    drop_enum :contributor_kind
  end
end
