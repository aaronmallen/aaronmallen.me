# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:analytics_rollup_paths) do
      add_column :read_throughs, :integer

      add_constraint(
        :analytics_rollup_paths_read_throughs_check,
        Sequel.lit("read_throughs >= 0 AND read_throughs <= visitors"),
      )
    end
  end

  down do
    alter_table(:analytics_rollup_paths) { drop_column :read_throughs }
  end
end
