# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :task_link_type, "parent"
  end

  down do
    run <<~SQL
      DELETE FROM task_links WHERE type::text = 'parent';
      ALTER TYPE task_link_type RENAME TO task_link_type_with_parent;
      CREATE TYPE task_link_type AS ENUM ('blocks', 'relates', 'duplicates');
      ALTER TABLE task_links ALTER COLUMN type TYPE task_link_type USING type::text::task_link_type;
      DROP TYPE task_link_type_with_parent;
    SQL
  end
end
