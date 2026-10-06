# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:task_tag_rules) do
      add_column :provider, :task_source_provider, null: false, default: "github"
      set_column_default :provider, nil
      drop_index :pattern
      add_index %i[provider pattern], unique: true
    end
  end

  down do
    from(:task_tag_rules).where(provider: "linear").delete

    alter_table(:task_tag_rules) do
      drop_index %i[provider pattern]
      drop_column :provider
      add_index :pattern, unique: true
    end
  end
end
