# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:memory_facts) { drop_constraint :memory_facts_text_length_check }
  end

  down do
    alter_table(:memory_facts) do
      add_constraint :memory_facts_text_length_check, Sequel.lit("char_length(text) <= 1000")
    end
  end
end
