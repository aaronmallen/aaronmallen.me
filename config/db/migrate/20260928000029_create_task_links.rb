# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :task_link_type, %w[blocks relates duplicates]

    create_table :task_links do
      primary_key :id
      foreign_key :from_task_id, :tasks, null: false, on_delete: :cascade
      foreign_key :to_task_id, :tasks, null: false, on_delete: :cascade
      column :type, :task_link_type, null: false

      constraint :task_links_distinct_check, Sequel.lit("from_task_id <> to_task_id")

      index %i[least greatest].map { Sequel.function(it, :from_task_id, :to_task_id) },
            unique: true, name: :task_links_pair_key
      index :from_task_id
      index :to_task_id
    end
  end

  down do
    drop_table :task_links

    drop_enum :task_link_type
  end
end
