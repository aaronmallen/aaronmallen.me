# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:performance_requests) { add_index %i[route verb occurred_at] }
  end
end
