# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table :commits do
      add_index :message, type: :gin, opclass: :gin_trgm_ops, name: :commits_message_trigram_index
      add_index :repo, type: :gin, opclass: :gin_trgm_ops, name: :commits_repo_trigram_index
    end
  end
end
