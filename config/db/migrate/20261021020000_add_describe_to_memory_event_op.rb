# frozen_string_literal: true

ROM::SQL.migration do
  described, undescribed = [true, false].map do |describe|
    {
      memory_events_op_check: <<~SQL,
        CASE op::text
          WHEN 'create' THEN num_nonnulls(memory_fact_id, text, was_text, reverted_event_id) = 0
          WHEN 'scope' THEN num_nonnulls(memory_fact_id, text, was_text, reverted_event_id) = 0
          #{"WHEN 'describe' THEN memory_fact_id IS NULL AND num_nonnulls(text, was_text) = 2 AND reverted_event_id IS NULL" if describe}
          WHEN 'add' THEN memory_fact_id IS NOT NULL AND text IS NOT NULL AND num_nonnulls(was_text, reverted_event_id) = 0
          WHEN 'edit' THEN num_nonnulls(memory_fact_id, text, was_text) = 3 AND reverted_event_id IS NULL
          WHEN 'remove' THEN memory_fact_id IS NOT NULL AND was_text IS NOT NULL AND num_nonnulls(text, reverted_event_id) = 0
          WHEN 'revert' THEN #{describe ? 'reverted_event_id IS NOT NULL' : 'num_nonnulls(memory_fact_id, reverted_event_id) = 2'} AND num_nonnulls(text, was_text) > 0
          ELSE false
        END
      SQL
      memory_events_state_check: <<~SQL,
        #{'memory_fact_id IS NULL OR ' if describe}((type IS NULL) = (text IS NULL) AND (was_type IS NULL) = (was_text IS NULL))
      SQL
    }
  end

  up do
    add_enum_value :memory_event_op, "describe", if_not_exists: true
    alter_table(:memory_events) do
      described.each do |name, check|
        drop_constraint name
        add_constraint name, Sequel.lit(check)
      end
    end
  end

  down do
    from(:memory_events).where(op: "describe").delete
    from(:memory_events).where(memory_fact_id: nil, op: "revert").delete
    alter_table(:memory_events) do
      undescribed.each do |name, check|
        drop_constraint name
        add_constraint name, Sequel.lit(check)
      end
    end
  end
end
