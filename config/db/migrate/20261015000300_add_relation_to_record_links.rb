# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :record_link_relation, %w[related sourced_from]

    alter_table :record_links do
      add_column :relation, :record_link_relation, null: false, default: "related"
      add_constraint :record_links_sourced_from_check, Sequel.lit(<<~SQL)
        relation <> 'sourced_from' OR (left_kind = 'task' AND right_kind = 'decision')
      SQL
      sourced = { relation: "sourced_from" }
      add_index %i[right_kind right_id], name: :record_links_one_source_key, unique: true, where: sourced
    end
  end

  down do
    alter_table :record_links do
      drop_index %i[right_kind right_id], name: :record_links_one_source_key
      drop_constraint :record_links_sourced_from_check
      drop_column :relation
    end

    drop_enum :record_link_relation
  end
end
