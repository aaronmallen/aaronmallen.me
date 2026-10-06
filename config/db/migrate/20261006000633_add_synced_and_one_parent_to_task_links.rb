# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:task_links) do
      add_column :synced, :boolean, null: false, default: false

      add_index :to_task_id, unique: true, where: Sequel.lit("type = 'parent'"), name: :task_links_one_parent_key
    end
  end
end
