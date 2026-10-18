# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table :sign_ins do
      add_column :visitor_hash, :visitor_hash
      add_index %i[visitor_hash created_at]
    end
  end
end
