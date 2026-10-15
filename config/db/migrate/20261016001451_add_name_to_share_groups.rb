# frozen_string_literal: true

ROM::SQL.migration do
  change do
    add_column :share_groups, :name, :non_blank_text
  end
end
