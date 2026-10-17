# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:tasks) { drop_constraint :tasks_position_check }
  end

  down do
    lowest = from(:tasks).min(:position)
    from(:tasks).update(position: Sequel[:position] - lowest + 1) if lowest&.<(1)
    alter_table(:tasks) { add_constraint :tasks_position_check, Sequel[:position] > 0 }
  end
end
