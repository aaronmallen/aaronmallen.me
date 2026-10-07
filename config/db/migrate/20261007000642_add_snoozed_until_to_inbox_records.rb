# frozen_string_literal: true

ROM::SQL.migration do
  change do
    %i[task_sources messages webmentions].each do |table|
      alter_table(table) { add_column :snoozed_until, :timestamptz }
    end
  end
end
