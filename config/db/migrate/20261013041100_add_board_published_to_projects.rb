# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:projects) { add_column :board_published, :boolean, null: false, default: false }
  end
end
